# RB Meta Module — Comprehensive Reference

A complete technical reference for the RB Meta module in RyanHub, covering VisionClaw architecture, the Meta Wearables DAT SDK, and the RyanHub integration layer.

---

## 1. Acknowledgements

The RB Meta module was inspired by and adapted from **VisionClaw**, an open-source project by [@sseanliu](https://github.com/sseanliu) that demonstrates real-time AI interaction with Meta Ray-Ban smart glasses using Google's Gemini Live API.

**Source repositories:**

- **VisionClaw**: [https://github.com/sseanliu/VisionClaw](https://github.com/sseanliu/VisionClaw) — The original open-source project providing the Gemini Live + glasses streaming + tool calling architecture that RB Meta builds upon.
- **Meta Wearables DAT SDK**: [https://github.com/facebook/meta-wearables-dat-ios](https://github.com/facebook/meta-wearables-dat-ios) — Meta's official Developer Access Token SDK for iOS, providing camera streaming and photo capture from Meta smart glasses.

We gratefully acknowledge the VisionClaw project for pioneering this integration pattern and making it openly available.

---

## 2. VisionClaw Architecture & Capabilities

VisionClaw (42 Swift source files) is an iOS application that connects Meta Ray-Ban smart glasses to Google's Gemini multimodal AI, enabling real-time voice + vision conversations with tool-calling capabilities.

### 2.1 Gemini Live API (WebSocket Protocol)

VisionClaw communicates with Gemini via a persistent WebSocket connection using the Bidirectional Generate Content API.

**WebSocket endpoint:**

```
wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=<API_KEY>
```

**Model:** `gemini-2.5-flash-native-audio-preview-12-2025`

**Setup message structure:**

The first message sent after the WebSocket opens is a `setup` message that configures the session:

```json
{
  "setup": {
    "model": "models/gemini-2.5-flash-native-audio-preview-12-2025",
    "generationConfig": {
      "responseModalities": ["AUDIO"],
      "thinkingConfig": { "thinkingBudget": 0 }
    },
    "systemInstruction": {
      "parts": [{ "text": "..." }]
    },
    "tools": [{
      "functionDeclarations": [...]
    }],
    "realtimeInputConfig": {
      "automaticActivityDetection": {
        "disabled": false,
        "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
        "endOfSpeechSensitivity": "END_SENSITIVITY_LOW",
        "silenceDurationMs": 500,
        "prefixPaddingMs": 40
      },
      "activityHandling": "START_OF_ACTIVITY_INTERRUPTS",
      "turnCoverage": "TURN_INCLUDES_ALL_INPUT"
    },
    "inputAudioTranscription": {},
    "outputAudioTranscription": {}
  }
}
```

**Supported server events:**

| Event | Description |
|-------|-------------|
| `setupComplete` | Session successfully configured; ready for real-time input |
| `serverContent.modelTurn.parts[].inlineData` | Audio response chunks (base64 PCM) |
| `serverContent.turnComplete` | Model finished speaking |
| `serverContent.interrupted` | User interrupted model speech |
| `serverContent.inputTranscription.text` | Real-time user speech transcription |
| `serverContent.outputTranscription.text` | Real-time model speech transcription |
| `toolCall.functionCalls[]` | Model requests tool execution |
| `toolCallCancellation.ids[]` | Model cancels in-flight tool calls |
| `goAway` | Server is shutting down the connection (includes `timeLeft`) |

**Client messages:**

| Message Type | Structure |
|--------------|-----------|
| Audio input | `{ "realtimeInput": { "audio": { "mimeType": "audio/pcm;rate=16000", "data": "<base64>" } } }` |
| Video input | `{ "realtimeInput": { "video": { "mimeType": "image/jpeg", "data": "<base64>" } } }` |
| Tool response | `{ "toolResponse": { "functionResponses": [{ "id": "...", "name": "...", "response": { "result": "..." } }] } }` |

### 2.2 Audio Pipeline

VisionClaw implements a full-duplex audio pipeline using `AVAudioEngine`.

**Capture (input):**
- Sample rate: **16 kHz** mono
- Format: PCM Int16, single channel
- Chunk size: **3,200 bytes** (100ms at 16kHz mono 16-bit)
- An `AVAudioConverter` resamples from the device's native sample rate to 16kHz if needed
- Audio is accumulated in a buffer and sent only when the minimum chunk size is reached
- Float32 samples from the mic tap are converted to Int16 before transmission

**Playback (output):**
- Sample rate: **24 kHz** mono
- Format: PCM Int16 from Gemini, converted to Float32 for `AVAudioPlayerNode`
- `AVAudioPlayerNode` schedules buffers for low-latency playback
- Player auto-restarts if not currently playing when new audio arrives

**Audio session configuration:**
- Category: `.playAndRecord`
- Mode: `.voiceChat` (iPhone camera mode) or `.videoChat` (glasses mode)
- Options: `.defaultToSpeaker`, `.allowBluetooth`
- Preferred IO buffer duration: 64ms
- Built-in echo cancellation via AVAudioSession modes

**VAD (Voice Activity Detection):**
- Handled server-side by Gemini's `automaticActivityDetection`
- High sensitivity for speech start, low sensitivity for speech end
- 500ms silence duration before end-of-speech triggers
- Activity interruption: user speech interrupts model output

### 2.3 Video Pipeline

VisionClaw supports two video sources: Meta glasses and iPhone camera.

**Glasses streaming:**
- DAT SDK provides raw video frames at **24 fps**
- Resolution: configurable (Low: 360x640, Medium: 504x896, High: 720x1280)
- Codec: raw (only option in DAT SDK)
- Frames arrive via the `videoFramePublisher.listen()` announcer pattern
- Each frame is converted to `UIImage` via `videoFrame.makeUIImage()`

**iPhone camera:**
- Uses `AVCaptureSession` with `.medium` preset
- Back-facing wide-angle camera
- Output: 32BGRA pixel format, converted through `CIContext` to `UIImage`
- Video rotation angle set to 90 degrees for portrait orientation
- Full device frame rate (typically 30fps)

**Throttling for Gemini:**
- Video frames are throttled to **1 fps** before sending to Gemini (configurable via `videoFrameInterval`)
- Each frame is JPEG-compressed at **50% quality** to reduce bandwidth
- The base64-encoded JPEG is sent as `realtimeInput.video`
- Throttle check: frames are only sent if at least 1 second has elapsed since the last sent frame

**WebRTC live streaming** (VisionClaw feature, not in RyanHub):
- Custom signaling server for peer connection setup
- STUN servers: Google public STUN (`stun.l.google.com`)
- TURN servers: fetched from HTTP endpoint for NAT traversal
- Codecs: H.264/H.265
- Max bitrate: 2.5 Mbps
- PiP (Picture-in-Picture) mode support
- Automatic reconnection on connection loss
- Full frame rate streaming (not throttled like Gemini)

### 2.4 Tool Calling System

VisionClaw uses a single-function tool calling design that routes all actions through an "execute" function to an external agent system.

**Function declaration:**

```json
{
  "name": "execute",
  "description": "Your only way to take action. Use this for everything: sending messages, searching the web, managing lists, setting reminders, creating notes, research, drafts, smart home control, app interactions, or any request beyond answering a question.",
  "parameters": {
    "type": "object",
    "properties": {
      "task": {
        "type": "string",
        "description": "Clear, detailed description of what to do. Include all relevant context."
      }
    },
    "required": ["task"]
  },
  "behavior": "BLOCKING"
}
```

**Key design decisions:**
- **Single function**: Rather than declaring dozens of individual tools, VisionClaw uses one `execute` function that accepts a natural-language task description. This keeps the Gemini setup simple while leveraging the downstream agent's full capability set.
- **BLOCKING behavior**: Gemini waits for the tool response before continuing. This prevents the model from speaking over itself or moving on before the action is complete.
- **Cancellation support**: Gemini can send `toolCallCancellation` messages with IDs of calls to abort, which maps to Swift `Task.cancel()`.

**OpenClaw bridge:**
- All tool calls are delegated to OpenClaw, a personal agent system, via HTTP REST
- Endpoint: `POST /v1/chat/completions`
- Authentication: Bearer token in `Authorization` header
- Request timeout: **120 seconds** (agent tasks can take a while)
- Session key: ISO8601-timestamped session identifier sent via `x-openclaw-session-key` header
- Conversation history: Maintains up to **10 turns** (20 messages) for context
- The bridge tracks connection state (notConfigured / checking / connected / unreachable)
- OpenClaw supports **56+ skills** in the VisionClaw context (messaging, web search, smart home, etc.)

**Tool call flow:**
1. Gemini sends `toolCall.functionCalls[]` with an `id`, `name`, and `args`
2. `RBToolCallRouter` receives the call and spawns an async `Task`
3. The task extracts the `task` parameter and sends it to `RBOpenClawBridge.delegateTask()`
4. OpenClaw processes the request and returns a response
5. The response is formatted as a `toolResponse` message and sent back to Gemini
6. If Gemini sends a `toolCallCancellation`, the in-flight `Task` is cancelled

### 2.5 Settings & Configuration

VisionClaw exposes the following configurable settings (persisted in `UserDefaults`):

| Setting | Default | Description |
|---------|---------|-------------|
| Gemini API Key | (hardcoded fallback) | Google AI API key for Gemini Live access |
| System Prompt | See section 2.4 | Instructions for the AI assistant persona |
| OpenClaw Host | `http://Zhiyuans-iMac.local` | Hostname of the OpenClaw agent gateway |
| OpenClaw Port | `18789` | Port for the OpenClaw HTTP API |
| OpenClaw Token | (hardcoded fallback) | Bearer token for gateway authentication |
| Video Frame Interval | `1.0` seconds | How often to send video frames to Gemini |
| JPEG Quality | `0.5` (50%) | Compression quality for video frames sent to Gemini |

---

## 3. Meta Wearables DAT SDK (v0.4.0)

The Meta Wearables Developer Access Token (DAT) SDK is Meta's official iOS framework for building third-party applications that interact with Meta smart glasses.

### 3.1 Three Modules

The SDK ships as three XCFrameworks via Swift Package Manager:

| Module | Size | Purpose |
|--------|------|---------|
| **MWDATCore** | ~15 MB | Core device management, registration, permissions, announcer/listener pattern |
| **MWDATCamera** | ~3.4 MB | Video streaming (`StreamSession`), photo capture, frame rendering |
| **MWDATMockDevice** | ~3.6 MB | Simulated device for testing without physical glasses |

**Minimum deployment target:** iOS 15.2+

**SPM dependency:**

```swift
// Package.swift or project.yml
.package(url: "https://github.com/facebook/meta-wearables-dat-ios", from: "0.4.0")
```

### 3.2 WearablesInterface API

The `WearablesInterface` is the central entry point for device management.

**Initialization:**

```swift
// Call once at app launch (idempotent — safe to call again)
try Wearables.configure()
let wearables = Wearables.shared
```

**Registration (device pairing):**

The registration flow uses a deep-link dance with the Meta AI companion app:

1. App calls `wearables.startRegistration()` — this opens the Meta AI app via deep link
2. User authorizes in the Meta AI app
3. Meta AI app redirects back via `ryanhub://` URL scheme
4. App calls `Wearables.shared.handleUrl(url)` in the `onOpenURL` handler
5. Registration state transitions: `.unregistered` → `.registering` → `.registered`

**URL callback detection:**

```swift
.onOpenURL { url in
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
    else { return }
    Task { _ = try await Wearables.shared.handleUrl(url) }
}
```

**Unregistration:**

```swift
try await wearables.startUnregistration()
```

**Permissions:**

Only one permission exists in the current SDK:

```swift
let status = try await wearables.checkPermissionStatus(.camera)
let result = try await wearables.requestPermission(.camera)  // .granted / .denied
```

### 3.3 StreamSession (Video Streaming)

`StreamSession` manages video streaming from connected glasses.

**Configuration:**

```swift
let config = StreamSessionConfig(
    videoCodec: .raw,           // Only option — no H.264/H.265 in SDK
    resolution: .low,            // .low (360x640) / .medium (504x896) / .high (720x1280)
    frameRate: 24                // Practical max is 24fps
)
let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
```

**Lifecycle:**

```swift
await session.start()   // Begin streaming
await session.stop()    // End streaming
```

**Stream states:** `stopped`, `waitingForDevice`, `starting`, `streaming`, `stopping`, `paused`

**Receiving video frames:**

```swift
let token = session.videoFramePublisher.listen { videoFrame in
    if let image = videoFrame.makeUIImage() {
        // Process the UIImage
    }
}
```

### 3.4 Photo Capture

The SDK supports on-demand photo capture from the glasses camera, separate from the video stream.

```swift
// Trigger capture
session.capturePhoto(format: .jpeg)  // .jpeg or .heic

// Receive photo data
let token = session.photoDataPublisher.listen { photoData in
    let image = UIImage(data: photoData.data)
    // Process high-res photo
}
```

### 3.5 Device Types

The SDK defines the following device types:

| Enum Case | Device |
|-----------|--------|
| `.rayBanMeta` | Ray-Ban Meta smart glasses |
| `.oakleyMetaHSTN` | Oakley Meta HSTN smart glasses |
| `.oakleyMetaVanguard` | Oakley Meta Vanguard smart glasses |
| `.metaRayBanDisplay` | Meta Ray-Ban Display (upcoming) |

### 3.6 Registration & Auth Flow (Deep Link Dance)

The full registration sequence:

```
┌─────────────┐    startRegistration()    ┌─────────────────┐
│  Your App   │ ──────────────────────────▶ │   Meta AI App   │
│             │                            │                 │
│             │ ◀────── Deep Link ─────── │  User approves  │
│             │  ryanhub://?metaWearables  │                 │
│  handleUrl()│  Action=...               │                 │
└─────────────┘                            └─────────────────┘
```

**Info.plist requirements:**

```xml
<key>MWDAT</key>
<dict>
    <key>AppLinkURLScheme</key>
    <string>ryanhub://</string>
    <key>MetaAppID</key>
    <string></string>
    <key>ClientToken</key>
    <string></string>
</dict>
```

### 3.7 Announcer/Listener Pattern

The DAT SDK uses its own announcer/listener pattern — **not** Combine publishers. Every publisher returns an `AnyListenerToken` that must be retained for the listener to remain active.

```swift
// Announcer pattern (NOT Combine)
let token: AnyListenerToken = publisher.listen { value in
    // Handle value
}
// Token must be stored — releasing it unsubscribes the listener

// AsyncStream alternative (also available)
for await device in selector.activeDeviceStream() {
    // Handle device changes
}

for await state in wearables.registrationStateStream() {
    // Handle registration state changes
}
```

**Important:** The `listen` closures are NOT guaranteed to run on the main actor. Always dispatch to `@MainActor` when updating UI state:

```swift
let token = session.videoFramePublisher.listen { videoFrame in
    Task { @MainActor in
        // Update UI here
    }
}
```

### 3.8 DeviceSelector

Two device selector strategies are available:

| Type | Behavior |
|------|----------|
| `AutoDeviceSelector` | Automatically selects the first available connected device |
| Specific device | Select a particular device by ID (for multi-device scenarios) |

```swift
let selector = AutoDeviceSelector(wearables: wearables)

// Monitor active device
for await device in selector.activeDeviceStream() {
    let hasDevice = device != nil
}
```

### 3.9 StreamSessionConfig Options

| Parameter | Type | Options | Notes |
|-----------|------|---------|-------|
| `videoCodec` | `VideoCodec` | `.raw` | Only raw is supported — no H.264/H.265 |
| `resolution` | `StreamingResolution` | `.low` (360x640), `.medium` (504x896), `.high` (720x1280) | Higher resolution = more bandwidth |
| `frameRate` | `Int` | Up to 24 | 24fps is the practical maximum |

### 3.10 Limitations & Constraints

- **No audio from glasses microphone**: The SDK does not provide access to the glasses' built-in microphones. Audio must come from the iPhone mic.
- **Raw codec only**: No H.264 or H.265 encoding in the SDK. All video frames are raw pixel data, which means higher bandwidth and CPU usage for processing.
- **Background streaming**: The SDK supports background streaming, but video frame decoding stops when the app enters the background. The stream connection remains alive.
- **No Combine**: The publisher pattern looks similar to Combine but is a custom implementation. Do not attempt to use Combine operators on it.
- **Sendable**: All types in v0.4.0 conform to `Sendable`, enabling safe usage in Swift concurrency contexts.
- **`hingesClosed` error**: Starting in v0.4.0, the SDK reports when the glasses' hinges are folded closed. Streaming cannot proceed while hinges are closed.
- **Meta AI app dependency**: Registration requires the Meta AI companion app to be installed on the same device.

### 3.11 Version History

| Version | Key Changes |
|---------|-------------|
| **0.1.0** | Initial release with basic device management and streaming |
| **0.2.0** | Added photo capture, improved stream stability |
| **0.3.0** | AsyncStream alternatives, more device types |
| **0.4.0** | `hingesClosed` error, all types `Sendable`, `metaRayBanDisplay` device type, stability improvements |

---

## 4. RyanHub RB Meta Module Integration

### 4.1 Adaptation from VisionClaw

The RB Meta module adapts VisionClaw's core architecture into RyanHub's toolkit plugin system. Key adaptations:

- **Removed WebRTC**: The live streaming/PiP features were not needed; the module focuses on Gemini Live + tool calling.
- **Integrated with RyanHub design system**: All UI uses `HubCard`, `HubButton`, `AdaptiveColors`, and the standard typography scale.
- **Added BOBO timeline integration**: Automatic snapshots from the glasses/camera are saved to the BOBO sensing timeline and uploaded to the iMac bridge server.
- **Plugged into toolkit navigation**: RB Meta is a toolkit plugin, rendered in-place below the menu bar like all other tools.
- **UserDefaults configuration**: Settings are stored in `UserDefaults` with sensible defaults, no separate settings UI required.

### 4.2 Architecture

The module follows RyanHub's standard MVVM pattern with service separation:

```
RBMeta/
├── RBMetaViewModel.swift              # Main ViewModel — orchestrates all services
├── Views/
│   └── RBMetaView.swift               # SwiftUI view (idle + active session states)
└── Services/
    ├── RBMetaConfig.swift             # Static configuration (URLs, audio params, UserDefaults)
    ├── RBMetaGeminiService.swift      # WebSocket connection to Gemini Live API
    ├── RBMetaAudioManager.swift       # AVAudioEngine capture + playback
    ├── RBMetaCameraManager.swift      # AVCaptureSession for iPhone back camera
    ├── RBMetaOpenClawBridge.swift     # HTTP client for OpenClaw agent delegation
    ├── RBMetaToolCallRouter.swift     # Routes Gemini tool calls to OpenClaw bridge
    └── RBMetaToolCallModels.swift     # Data models, enums, tool declarations
```

**`RBMetaViewModel`** (`@Observable`, `@MainActor`):
- Owns all service instances and public state
- Manages DAT SDK lifecycle (registration, stream session, device monitoring)
- Coordinates Gemini session start/stop (audio setup → WebSocket connect → mic capture)
- Wires callbacks between services (audio captured → Gemini, audio received → playback, tool call → router → bridge → response)
- Throttles video frames to 1fps for Gemini
- Manages BOBO timeline auto-snapshots

**`RBGeminiService`** (`@MainActor`):
- Manages URLSessionWebSocketTask lifecycle
- Sends setup message, audio, video, and tool responses
- Parses all server events (audio, transcriptions, tool calls, cancellations, goAway)
- Tracks connection state and model speaking state
- Uses a dedicated `DispatchQueue` for serialized JSON sending
- 15-second connection timeout

**`RBMetaAudioManager`**:
- AVAudioEngine with input tap for microphone capture
- AVAudioPlayerNode for Gemini audio playback
- Automatic sample rate conversion (device native → 16kHz)
- Float32 → Int16 conversion for transmission
- Int16 → Float32 conversion for playback
- Accumulation buffer ensures minimum 3,200-byte chunks (100ms)

**`RBMetaCameraManager`** (`NSObject`, `AVCaptureVideoDataOutputSampleBufferDelegate`):
- AVCaptureSession with `.medium` preset
- Back-facing wide-angle camera
- BGRA pixel buffer → CIImage → CGImage → UIImage pipeline
- Frame callback to ViewModel

**`RBMetaOpenClawBridge`** (`@MainActor`):
- HTTP POST to OpenClaw `/v1/chat/completions` endpoint
- Bearer token authentication
- 120-second request timeout (5-second for ping/health check)
- Maintains conversation history (up to 10 turns)
- Session key with ISO8601 timestamp prefix
- Connection state tracking with health check

**`RBToolCallRouter`** (`@MainActor`):
- Maps Gemini function calls to OpenClaw bridge invocations
- Tracks in-flight tasks by call ID for cancellation support
- Builds properly formatted `toolResponse` messages for Gemini
- `cancelAll()` for session teardown

### 4.3 BOBO Timeline Integration

The RB Meta module integrates with RyanHub's BOBO sensing timeline to create a visual log of what the user sees through their glasses.

**Auto-snapshots:**
- During active streaming (glasses or iPhone), a snapshot is saved every **30 seconds**
- Each snapshot is saved as a JPEG (70% quality) to the BOBO photos directory
- A `SensingEvent` with `.photo` modality is recorded in the sensing engine
- The photo is uploaded to the iMac bridge server (`/bobo/photos/upload`) via multipart form upload

**Photo capture:**
- In glasses mode, the user can trigger an on-demand photo capture via `captureGlassesPhoto()`
- This calls `streamSession.capturePhoto(format: .jpeg)` on the DAT SDK
- The resulting photo data arrives via `photoDataPublisher` and is saved to the BOBO timeline with source tag `rb_meta_glasses_capture`

**Source tags:**
- `rb_meta_glasses` — auto-snapshot from glasses stream
- `rb_meta_iphone` — auto-snapshot from iPhone camera
- `rb_meta_glasses_capture` — manual photo capture from glasses

**iMac sync:**
- Photos are uploaded to the bridge server at port `18790` in the background
- Upload uses `Task.detached(priority: .utility)` to avoid blocking the main actor
- Multipart form data includes `event_id`, `source`, and the JPEG file

### 4.4 Design System Compliance

The RB Meta view follows RyanHub's design system:

- **Background**: `AdaptiveColors.background(for: colorScheme)` for light/dark mode
- **Cards**: `HubCard` for status cards and info sections
- **Buttons**: `HubButton` (primary) and `HubSecondaryButton` (outlined) for actions
- **Colors**: `Color.hubPrimary` (indigo), `.hubAccentGreen`, `.hubAccentRed`, `.hubAccentYellow`
- **Typography**: `.hubTitle`, `.hubHeading`, `.hubBody`, `.hubCaption`
- **Layout**: `HubLayout.sectionSpacing`, `.standardPadding`, `.itemSpacing`
- **Active session**: Full-screen camera feed with translucent overlay controls, status pills, and transcript bubbles

---

## 5. Quick Reference

### 5.1 Key API Methods

| Class | Method | Description |
|-------|--------|-------------|
| `Wearables` | `.configure()` | Initialize the DAT SDK (call once) |
| `Wearables` | `.shared` | Singleton access to `WearablesInterface` |
| `WearablesInterface` | `.startRegistration()` | Begin OAuth deep-link flow with Meta AI app |
| `WearablesInterface` | `.startUnregistration()` | Disconnect and unregister device |
| `WearablesInterface` | `.handleUrl(_:)` | Process callback URL from Meta AI app |
| `WearablesInterface` | `.checkPermissionStatus(_:)` | Check if camera permission is granted |
| `WearablesInterface` | `.requestPermission(_:)` | Request camera permission |
| `WearablesInterface` | `.registrationStateStream()` | AsyncStream of registration state changes |
| `StreamSession` | `.start()` | Begin video streaming from glasses |
| `StreamSession` | `.stop()` | End video streaming |
| `StreamSession` | `.capturePhoto(format:)` | Capture a single photo (`.jpeg` / `.heic`) |
| `StreamSession` | `.videoFramePublisher` | Announcer for incoming video frames |
| `StreamSession` | `.photoDataPublisher` | Announcer for captured photo data |
| `StreamSession` | `.statePublisher` | Announcer for stream state changes |
| `StreamSession` | `.errorPublisher` | Announcer for streaming errors |
| `AutoDeviceSelector` | `.activeDeviceStream()` | AsyncStream of active device changes |
| `RBMetaViewModel` | `.setupDAT(wearables:)` | Initialize DAT with wearables instance |
| `RBMetaViewModel` | `.startGeminiSession()` | Connect to Gemini, start audio |
| `RBMetaViewModel` | `.stopGeminiSession()` | Disconnect Gemini, stop audio |
| `RBMetaViewModel` | `.startGlassesStreaming()` | Begin glasses video stream |
| `RBMetaViewModel` | `.startIPhoneCamera()` | Begin iPhone camera capture |
| `RBMetaViewModel` | `.stopStreaming()` | Stop active video source |
| `RBMetaViewModel` | `.captureGlassesPhoto()` | Trigger glasses photo capture |
| `RBGeminiService` | `.connect()` | Open WebSocket, send setup, await `setupComplete` |
| `RBGeminiService` | `.disconnect()` | Close WebSocket, clean up |
| `RBGeminiService` | `.sendAudio(data:)` | Send PCM audio chunk to Gemini |
| `RBGeminiService` | `.sendVideoFrame(image:)` | Send JPEG-compressed frame to Gemini |
| `RBGeminiService` | `.sendToolResponse(_:)` | Return tool call result to Gemini |
| `RBOpenClawBridge` | `.delegateTask(task:toolName:)` | Send task to OpenClaw agent |
| `RBOpenClawBridge` | `.checkConnection()` | Ping OpenClaw endpoint |
| `RBOpenClawBridge` | `.resetSession()` | Clear conversation history, generate new session key |

### 5.2 Supported Resolutions & Frame Rates

| Resolution | Dimensions | Notes |
|------------|-----------|-------|
| `.low` | 360 x 640 | Default. Lowest bandwidth, suitable for AI vision |
| `.medium` | 504 x 896 | Balanced quality/performance |
| `.high` | 720 x 1280 | HD quality, highest bandwidth |

| Frame Rate | Context |
|------------|---------|
| 24 fps | DAT SDK streaming (practical max) |
| ~30 fps | iPhone camera (device native) |
| 1 fps | Gemini video input (throttled) |

### 5.3 Error Types and Handling

**StreamSessionError (DAT SDK):**

| Error | Description | Handling |
|-------|-------------|----------|
| `.internalError` | SDK internal failure | Retry |
| `.deviceNotFound` | No glasses detected | Check Bluetooth pairing |
| `.deviceNotConnected` | Glasses paired but not connected | Reconnect device |
| `.timeout` | Operation timed out | Retry |
| `.videoStreamingError` | Video stream failure | Restart stream |
| `.audioStreamingError` | Audio stream failure | Restart stream |
| `.permissionDenied` | Camera permission not granted | Request permission |
| `.hingesClosed` | Glasses hinges are folded shut (v0.4.0+) | Prompt user to open |

**RBGeminiConnectionState:**

| State | Description |
|-------|-------------|
| `.disconnected` | Not connected |
| `.connecting` | WebSocket opening |
| `.settingUp` | WebSocket open, setup message sent, awaiting `setupComplete` |
| `.ready` | Fully connected and ready for audio/video |
| `.error(String)` | Connection failed with error message |

**RBOpenClawConnectionState:**

| State | Description |
|-------|-------------|
| `.notConfigured` | No host/token configured |
| `.checking` | Health check in progress |
| `.connected` | Endpoint reachable |
| `.unreachable(String)` | Endpoint not reachable with reason |

**RBToolCallStatus:**

| Status | Description |
|--------|-------------|
| `.idle` | No active tool call |
| `.executing(String)` | Tool call in progress (shows tool name) |
| `.completed(String)` | Tool call succeeded |
| `.failed(String, String)` | Tool call failed (tool name + error) |
| `.cancelled(String)` | Tool call was cancelled by Gemini |

### 5.4 Required Info.plist Keys

```xml
<!-- DAT SDK Configuration -->
<key>MWDAT</key>
<dict>
    <key>AppLinkURLScheme</key>
    <string>ryanhub://</string>
    <key>MetaAppID</key>
    <string></string>         <!-- From Meta Developer Portal -->
    <key>ClientToken</key>
    <string></string>         <!-- From Meta Developer Portal -->
</dict>

<!-- External Accessory Protocol -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
    <string>com.meta.ar.wearable</string>
</array>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-peripheral</string>
    <string>external-accessory</string>
</array>

<!-- Privacy Descriptions -->
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for AR features and photo capture.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice conversations.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is needed to connect to your smart glasses.</string>
```

### 5.5 Required Entitlements and Permissions

| Requirement | Type | Purpose |
|-------------|------|---------|
| `com.meta.ar.wearable` | External Accessory Protocol | Communication with Meta glasses |
| `bluetooth-peripheral` | Background Mode | Maintain glasses connection in background |
| `external-accessory` | Background Mode | External accessory communication in background |
| Camera permission | Runtime permission | iPhone camera and glasses camera access |
| Microphone permission | Runtime permission | Voice input for Gemini conversations |
| Bluetooth permission | Runtime permission | Device discovery and pairing |

---

## 6. Future Development Ideas

The RB Meta module's combination of real-time vision, voice interaction, and tool calling opens up many possibilities:

### 6.1 Real-Time Object Detection & Recognition
- Continuously identify objects, text, or people in the camera feed
- Provide spoken descriptions on demand ("What am I looking at?")
- Build a personal visual memory — recognize objects you have seen before

### 6.2 Contextual Reminders Based on What You See
- "Remind me to buy milk when I'm at the grocery store" — trigger when store signage is detected
- Location-aware reminders enhanced by visual context (not just GPS geofence)
- Shopping list check-off by recognizing items as they are placed in the cart

### 6.3 Hands-Free Task Execution
- Full smart home control: "Turn off the lights" while your hands are occupied
- Compose and send messages on any platform without touching your phone
- Take notes, add calendar events, or set timers entirely through voice while wearing glasses

### 6.4 Live Translation of Text in View
- Read foreign-language signs, menus, or documents through the glasses camera
- Gemini translates and speaks the result in the user's language
- Could overlay translations in future AR display models

### 6.5 Social Interaction Analysis
- Real-time facial expression and body language analysis during conversations
- Post-meeting summaries of key points and action items
- Coaching for presentations or interviews (speaking pace, eye contact hints)

### 6.6 Navigation & Spatial Awareness
- Walking directions with voice guidance based on what the glasses see
- Indoor navigation by recognizing landmarks, signs, and room numbers
- Accessibility assistance for visually impaired users

### 6.7 Personal Knowledge Graph
- Automatically tag and categorize everything you see throughout the day
- Build a searchable visual history: "Show me that whiteboard from Tuesday's meeting"
- Connect visual observations to notes, contacts, and calendar events

### 6.8 Cooking & Recipe Assistant
- Follow recipes hands-free with step-by-step voice guidance
- Identify ingredients on the counter and suggest recipes
- Timer management and cooking technique tips based on what you are doing

### 6.9 Fitness & Activity Recognition
- Identify exercises and count reps by watching your movements
- Real-time form correction during workouts
- Track activities throughout the day from visual context

### 6.10 Multi-Modal Meeting Notes
- Capture whiteboard content and slides automatically during meetings
- Combine audio transcription with visual captures for rich meeting summaries
- Auto-generate action items and follow-up tasks via tool calling

---

*Document generated for the RyanHub project. Last updated: 2026-03-05.*
