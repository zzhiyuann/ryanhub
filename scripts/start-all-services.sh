#!/usr/bin/env bash
#
# start-all-services.sh — Master service manager for Ryan Hub iOS app.
#
# Starts/stops/checks all backend services that the app depends on:
#   1. Dispatcher (WebSocket on port 8765) — Chat backend
#   2. Bridge Server (HTTP on port 18790) — RyanHub bridge server
#   3. Calendar Sync Server (HTTP on port 18791) — Google Calendar bridge
#   4. Book Factory Server (HTTPS on port 3443 / HTTP on port 3000) — Book platform
#
# Usage:
#   ./start-all-services.sh start    # Start all services (default)
#   ./start-all-services.sh stop     # Stop all managed services
#   ./start-all-services.sh status   # Check which services are running
#   ./start-all-services.sh restart  # Stop then start all services
#
# Logs are written to /tmp/ryanhub-services.log (master) and individual
# service logs under /tmp/.

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

MASTER_LOG="/tmp/ryanhub-services.log"
PID_DIR="/tmp/ryanhub-pids"

# Service definitions: name, port, start command, working directory, log file
# Dispatcher
DISPATCHER_NAME="dispatcher"
DISPATCHER_PORT=8765
DISPATCHER_BIN="$REPO_ROOT/services/dispatcher/.venv/bin/dispatcher"
DISPATCHER_LOG="/tmp/ryanhub-dispatcher.log"

# Bridge Server
FOOD_NAME="food-analysis"
FOOD_PORT=18790
FOOD_SCRIPT="$REPO_ROOT/scripts/bridge-server.py"
FOOD_LOG="/tmp/ryanhub-food-analysis.log"

# Calendar Sync Server
CALENDAR_NAME="calendar-sync"
CALENDAR_PORT=18791
CALENDAR_SCRIPT="$REPO_ROOT/scripts/calendar-sync-server.py"
CALENDAR_PYTHON="/Users/zwang/Documents/gcal-mcp-server/.venv/bin/python3"
CALENDAR_LOG="/tmp/ryanhub-calendar-sync.log"

# Book Factory Server
BOOKFACTORY_NAME="bookfactory"
BOOKFACTORY_PORT=3443
BOOKFACTORY_HTTP_PORT=3000
BOOKFACTORY_DIR="$REPO_ROOT/services/bookfactory"
BOOKFACTORY_LOG="/tmp/ryanhub-bookfactory.log"

# Data directories (external to repo)
export BOOKFACTORY_DATA_DIR="/Users/zwang/projects/bookfactory/data"
export BOOK_SOURCE_DIR="/Users/zwang/bookfactory"
export BACKLOG_PATH="/Users/zwang/bookfactory/topic_backlog.md"

# PATH setup — ensure we have access to homebrew, node, python, lsof, etc.
export PATH="/usr/sbin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/Users/zwang/.local/bin:/Users/zwang/.npm-global/bin:$REPO_ROOT/services/dispatcher/.venv/bin:$PATH"
export HOME="/Users/zwang"

# Remove Claude Code env vars to prevent nesting issues with food analysis server
unset CLAUDE_CODE 2>/dev/null || true
unset CLAUDECODE 2>/dev/null || true

# =============================================================================
# Helpers
# =============================================================================

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    echo "[$(timestamp)] $*" | tee -a "$MASTER_LOG"
}

log_warn() {
    echo "[$(timestamp)] WARNING: $*" | tee -a "$MASTER_LOG" >&2
}

log_error() {
    echo "[$(timestamp)] ERROR: $*" | tee -a "$MASTER_LOG" >&2
}

# Check if a port is in use. Returns 0 if port is in use, 1 otherwise.
port_in_use() {
    local port=$1
    lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1
}

# Get the PID of the process listening on a port.
get_pid_on_port() {
    local port=$1
    lsof -ti :"$port" -sTCP:LISTEN 2>/dev/null | head -1
}

# Save PID to a file for tracking.
save_pid() {
    local name=$1
    local pid=$2
    mkdir -p "$PID_DIR"
    echo "$pid" > "$PID_DIR/$name.pid"
}

# Read saved PID.
read_pid() {
    local name=$1
    local pidfile="$PID_DIR/$name.pid"
    if [[ -f "$pidfile" ]]; then
        cat "$pidfile"
    fi
}

# Check if a process is alive.
is_alive() {
    local pid=$1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Wait for a port to become available (with timeout).
wait_for_port() {
    local port=$1
    local timeout=${2:-15}
    local elapsed=0

    while ! port_in_use "$port"; do
        if (( elapsed >= timeout )); then
            return 1
        fi
        sleep 1
        (( elapsed++ ))
    done
    return 0
}

# =============================================================================
# Service: Dispatcher
# =============================================================================

start_dispatcher() {
    if port_in_use "$DISPATCHER_PORT"; then
        local existing_pid
        existing_pid=$(get_pid_on_port "$DISPATCHER_PORT")
        log "$DISPATCHER_NAME: Already running on port $DISPATCHER_PORT (PID $existing_pid)"
        save_pid "$DISPATCHER_NAME" "$existing_pid"
        return 0
    fi

    if [[ ! -x "$DISPATCHER_BIN" ]]; then
        log_warn "$DISPATCHER_NAME: Binary not found at $DISPATCHER_BIN — skipping"
        return 0
    fi

    # NOTE: Dispatcher has its own LaunchAgent (com.dispatcher.agent.plist)
    # with KeepAlive=true. We start it here as a fallback in case that agent
    # is not loaded, but normally it will already be running.
    log "$DISPATCHER_NAME: Starting on port $DISPATCHER_PORT..."
    nohup "$DISPATCHER_BIN" start >> "$DISPATCHER_LOG" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    save_pid "$DISPATCHER_NAME" "$pid"

    if wait_for_port "$DISPATCHER_PORT" 20; then
        log "$DISPATCHER_NAME: Started successfully (PID $pid)"
    else
        log_error "$DISPATCHER_NAME: Failed to start within timeout"
        return 1
    fi
}

stop_dispatcher() {
    local pid
    pid=$(read_pid "$DISPATCHER_NAME")
    if [[ -z "$pid" ]]; then
        pid=$(get_pid_on_port "$DISPATCHER_PORT")
    fi

    if [[ -n "$pid" ]] && is_alive "$pid"; then
        log "$DISPATCHER_NAME: Stopping (PID $pid)..."
        kill "$pid" 2>/dev/null
        # Wait for graceful shutdown
        local wait=0
        while is_alive "$pid" && (( wait < 10 )); do
            sleep 1
            (( wait++ ))
        done
        if is_alive "$pid"; then
            log_warn "$DISPATCHER_NAME: Force killing (PID $pid)"
            kill -9 "$pid" 2>/dev/null
        fi
        log "$DISPATCHER_NAME: Stopped"
    else
        log "$DISPATCHER_NAME: Not running"
    fi
    rm -f "$PID_DIR/$DISPATCHER_NAME.pid"
}

status_dispatcher() {
    if port_in_use "$DISPATCHER_PORT"; then
        local pid
        pid=$(get_pid_on_port "$DISPATCHER_PORT")
        echo "  $DISPATCHER_NAME: RUNNING on port $DISPATCHER_PORT (PID $pid)"
    else
        echo "  $DISPATCHER_NAME: STOPPED (port $DISPATCHER_PORT)"
    fi
}

# =============================================================================
# Service: Bridge Server
# =============================================================================

start_food() {
    if port_in_use "$FOOD_PORT"; then
        local existing_pid
        existing_pid=$(get_pid_on_port "$FOOD_PORT")
        log "$FOOD_NAME: Already running on port $FOOD_PORT (PID $existing_pid)"
        save_pid "$FOOD_NAME" "$existing_pid"
        return 0
    fi

    if [[ ! -f "$FOOD_SCRIPT" ]]; then
        log_warn "$FOOD_NAME: Script not found at $FOOD_SCRIPT — skipping"
        return 0
    fi

    log "$FOOD_NAME: Starting on port $FOOD_PORT..."
    nohup /usr/bin/python3 "$FOOD_SCRIPT" >> "$FOOD_LOG" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    save_pid "$FOOD_NAME" "$pid"

    if wait_for_port "$FOOD_PORT" 10; then
        log "$FOOD_NAME: Started successfully (PID $pid)"
    else
        log_error "$FOOD_NAME: Failed to start within timeout"
        return 1
    fi
}

stop_food() {
    local pid
    pid=$(read_pid "$FOOD_NAME")
    if [[ -z "$pid" ]]; then
        pid=$(get_pid_on_port "$FOOD_PORT")
    fi

    if [[ -n "$pid" ]] && is_alive "$pid"; then
        log "$FOOD_NAME: Stopping (PID $pid)..."
        kill "$pid" 2>/dev/null
        local wait=0
        while is_alive "$pid" && (( wait < 5 )); do
            sleep 1
            (( wait++ ))
        done
        if is_alive "$pid"; then
            kill -9 "$pid" 2>/dev/null
        fi
        log "$FOOD_NAME: Stopped"
    else
        log "$FOOD_NAME: Not running"
    fi
    rm -f "$PID_DIR/$FOOD_NAME.pid"
}

status_food() {
    if port_in_use "$FOOD_PORT"; then
        local pid
        pid=$(get_pid_on_port "$FOOD_PORT")
        echo "  $FOOD_NAME: RUNNING on port $FOOD_PORT (PID $pid)"
    else
        echo "  $FOOD_NAME: STOPPED (port $FOOD_PORT)"
    fi
}

# =============================================================================
# Service: Calendar Sync Server
# =============================================================================

start_calendar() {
    if port_in_use "$CALENDAR_PORT"; then
        local existing_pid
        existing_pid=$(get_pid_on_port "$CALENDAR_PORT")
        log "$CALENDAR_NAME: Already running on port $CALENDAR_PORT (PID $existing_pid)"
        save_pid "$CALENDAR_NAME" "$existing_pid"
        return 0
    fi

    if [[ ! -f "$CALENDAR_SCRIPT" ]]; then
        log_warn "$CALENDAR_NAME: Script not found at $CALENDAR_SCRIPT — skipping"
        return 0
    fi

    if [[ ! -x "$CALENDAR_PYTHON" ]]; then
        log_warn "$CALENDAR_NAME: Python not found at $CALENDAR_PYTHON — skipping"
        return 0
    fi

    log "$CALENDAR_NAME: Starting on port $CALENDAR_PORT..."
    nohup "$CALENDAR_PYTHON" "$CALENDAR_SCRIPT" >> "$CALENDAR_LOG" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    save_pid "$CALENDAR_NAME" "$pid"

    if wait_for_port "$CALENDAR_PORT" 10; then
        log "$CALENDAR_NAME: Started successfully (PID $pid)"
    else
        log_error "$CALENDAR_NAME: Failed to start within timeout"
        return 1
    fi
}

stop_calendar() {
    local pid
    pid=$(read_pid "$CALENDAR_NAME")
    if [[ -z "$pid" ]]; then
        pid=$(get_pid_on_port "$CALENDAR_PORT")
    fi

    if [[ -n "$pid" ]] && is_alive "$pid"; then
        log "$CALENDAR_NAME: Stopping (PID $pid)..."
        kill "$pid" 2>/dev/null
        local wait=0
        while is_alive "$pid" && (( wait < 5 )); do
            sleep 1
            (( wait++ ))
        done
        if is_alive "$pid"; then
            kill -9 "$pid" 2>/dev/null
        fi
        log "$CALENDAR_NAME: Stopped"
    else
        log "$CALENDAR_NAME: Not running"
    fi
    rm -f "$PID_DIR/$CALENDAR_NAME.pid"
}

status_calendar() {
    if port_in_use "$CALENDAR_PORT"; then
        local pid
        pid=$(get_pid_on_port "$CALENDAR_PORT")
        echo "  $CALENDAR_NAME: RUNNING on port $CALENDAR_PORT (PID $pid)"
    else
        echo "  $CALENDAR_NAME: STOPPED (port $CALENDAR_PORT)"
    fi
}

# =============================================================================
# Service: Book Factory Server
# =============================================================================

start_bookfactory() {
    if port_in_use "$BOOKFACTORY_PORT"; then
        local existing_pid
        existing_pid=$(get_pid_on_port "$BOOKFACTORY_PORT")
        log "$BOOKFACTORY_NAME: Already running on port $BOOKFACTORY_PORT (PID $existing_pid)"
        save_pid "$BOOKFACTORY_NAME" "$existing_pid"
        return 0
    fi

    if [[ ! -d "$BOOKFACTORY_DIR" ]]; then
        log_warn "$BOOKFACTORY_NAME: Directory not found at $BOOKFACTORY_DIR — skipping"
        return 0
    fi

    if [[ ! -f "$BOOKFACTORY_DIR/server.mjs" ]]; then
        log_warn "$BOOKFACTORY_NAME: server.mjs not found — skipping"
        return 0
    fi

    # Ensure node_modules exist
    if [[ ! -d "$BOOKFACTORY_DIR/node_modules" ]]; then
        log "$BOOKFACTORY_NAME: Installing dependencies..."
        (cd "$BOOKFACTORY_DIR" && npm install >> "$BOOKFACTORY_LOG" 2>&1)
    fi

    # Ensure Next.js is built
    if [[ ! -d "$BOOKFACTORY_DIR/.next" ]]; then
        log "$BOOKFACTORY_NAME: Building Next.js..."
        (cd "$BOOKFACTORY_DIR" && npm run build >> "$BOOKFACTORY_LOG" 2>&1)
    fi

    log "$BOOKFACTORY_NAME: Starting on ports $BOOKFACTORY_PORT (HTTPS) / $BOOKFACTORY_HTTP_PORT (HTTP)..."
    (cd "$BOOKFACTORY_DIR" && exec nohup node server.mjs >> "$BOOKFACTORY_LOG" 2>&1) &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    save_pid "$BOOKFACTORY_NAME" "$pid"

    if wait_for_port "$BOOKFACTORY_PORT" 30; then
        log "$BOOKFACTORY_NAME: Started successfully (PID $pid)"
    else
        log_error "$BOOKFACTORY_NAME: Failed to start within timeout"
        return 1
    fi
}

stop_bookfactory() {
    local pid
    pid=$(read_pid "$BOOKFACTORY_NAME")
    if [[ -z "$pid" ]]; then
        pid=$(get_pid_on_port "$BOOKFACTORY_PORT")
    fi

    if [[ -n "$pid" ]] && is_alive "$pid"; then
        log "$BOOKFACTORY_NAME: Stopping (PID $pid)..."
        kill "$pid" 2>/dev/null
        local wait=0
        while is_alive "$pid" && (( wait < 10 )); do
            sleep 1
            (( wait++ ))
        done
        if is_alive "$pid"; then
            kill -9 "$pid" 2>/dev/null
        fi
        log "$BOOKFACTORY_NAME: Stopped"
    else
        log "$BOOKFACTORY_NAME: Not running"
    fi
    rm -f "$PID_DIR/$BOOKFACTORY_NAME.pid"
}

status_bookfactory() {
    if port_in_use "$BOOKFACTORY_PORT"; then
        local pid
        pid=$(get_pid_on_port "$BOOKFACTORY_PORT")
        echo "  $BOOKFACTORY_NAME: RUNNING on port $BOOKFACTORY_PORT (PID $pid)"
    else
        echo "  $BOOKFACTORY_NAME: STOPPED (port $BOOKFACTORY_PORT)"
    fi
}

# =============================================================================
# Main Commands
# =============================================================================

do_start() {
    log "=========================================="
    log "Ryan Hub Services — Starting all"
    log "=========================================="

    local failures=0

    start_dispatcher  || (( failures++ )) || true
    start_food        || (( failures++ )) || true
    start_calendar    || (( failures++ )) || true
    start_bookfactory || (( failures++ )) || true

    echo ""
    log "=========================================="
    if (( failures > 0 )); then
        log "Startup complete with $failures failure(s)"
    else
        log "All services started successfully"
    fi
    log "=========================================="

    do_status
}

do_stop() {
    log "=========================================="
    log "Ryan Hub Services — Stopping all"
    log "=========================================="

    stop_bookfactory
    stop_calendar
    stop_food
    stop_dispatcher

    log "All services stopped"
    rm -rf "$PID_DIR"
}

do_status() {
    echo ""
    echo "Ryan Hub Services Status:"
    echo "--------------------------"
    status_dispatcher
    status_food
    status_calendar
    status_bookfactory
    echo ""
}

do_restart() {
    do_stop
    sleep 2
    do_start
}

# =============================================================================
# Entry Point
# =============================================================================

ACTION="${1:-start}"

case "$ACTION" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    status)
        do_status
        ;;
    restart)
        do_restart
        ;;
    start-food)
        start_food
        ;;
    stop-food)
        stop_food
        ;;
    start-calendar)
        start_calendar
        ;;
    stop-calendar)
        stop_calendar
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|start-food|stop-food|start-calendar|stop-calendar}"
        exit 1
        ;;
esac
