#!/usr/bin/env swift
//
// calendar-helper.swift — Apple EventKit CLI bridge for calendar-sync-server
//
// Usage:
//   swift calendar-helper.swift list-calendars
//   swift calendar-helper.swift list-events <startISO> <endISO>
//   swift calendar-helper.swift create-event '<json>'
//   swift calendar-helper.swift update-event <id> '<json>'
//   swift calendar-helper.swift delete-event <id>
//
// Output: JSON to stdout, errors to stderr

import EventKit
import Foundation

let store = EKEventStore()

// MARK: - Helpers

func requestAccess() -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    var granted = false
    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { g, error in
            granted = g
            if let error = error {
                fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
            }
            semaphore.signal()
        }
    } else {
        store.requestAccess(to: .event) { g, error in
            granted = g
            if let error = error {
                fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
            }
            semaphore.signal()
        }
    }
    semaphore.wait()
    return granted
}

func colorToHex(_ color: CGColor?) -> String {
    guard let color = color,
          let components = color.components,
          components.count >= 3 else {
        return "#4285f4"
    }
    let r = Int(components[0] * 255)
    let g = Int(components[1] * 255)
    let b = Int(components[2] * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
}

func parseISO(_ str: String) -> Date? {
    let formatters: [DateFormatter] = {
        let f1 = DateFormatter()
        f1.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        f1.locale = Locale(identifier: "en_US_POSIX")

        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f2.locale = Locale(identifier: "en_US_POSIX")
        f2.timeZone = TimeZone(identifier: "America/New_York")

        let f3 = DateFormatter()
        f3.dateFormat = "yyyy-MM-dd"
        f3.locale = Locale(identifier: "en_US_POSIX")
        f3.timeZone = TimeZone(identifier: "America/New_York")

        return [f1, f2, f3]
    }()

    // Try ISO8601DateFormatter first (handles Z and +00:00)
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: str) { return d }
    iso.formatOptions = [.withInternetDateTime]
    if let d = iso.date(from: str) { return d }

    for f in formatters {
        if let d = f.date(from: str) { return d }
    }
    return nil
}

func isoString(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    f.timeZone = TimeZone(identifier: "America/New_York")
    return f.string(from: date)
}

func dateOnlyString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "America/New_York")
    return f.string(from: date)
}

func outputJSON(_ obj: Any) {
    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    }
}

func exitError(_ msg: String) -> Never {
    let err: [String: Any] = ["error": msg]
    outputJSON(err)
    exit(1)
}

// MARK: - Commands

func listCalendars() {
    let calendars = store.calendars(for: .event)
    var result: [[String: Any]] = []
    for cal in calendars {
        result.append([
            "id": cal.calendarIdentifier,
            "summary": cal.title,
            "backgroundColor": colorToHex(cal.cgColor),
            "primary": cal.calendarIdentifier == store.defaultCalendarForNewEvents?.calendarIdentifier,
            "accessRole": cal.allowsContentModifications ? "owner" : "reader",
            "source": cal.source?.title ?? "Unknown",
        ])
    }
    outputJSON(result)
}

func listEvents(startStr: String, endStr: String) {
    guard let startDate = parseISO(startStr) else {
        exitError("Invalid start date: \(startStr)")
    }
    guard let endDate = parseISO(endStr) else {
        exitError("Invalid end date: \(endStr)")
    }

    let calendars = store.calendars(for: .event)
    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    let events = store.events(matching: predicate)

    var result: [[String: Any]] = []
    for event in events {
        var dict: [String: Any] = [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "(No title)",
            "calendarId": event.calendar.calendarIdentifier,
            "calendarName": event.calendar.title,
            "calendarColor": colorToHex(event.calendar.cgColor),
            "isAllDay": event.isAllDay,
            "status": event.status == .confirmed ? "confirmed" : (event.status == .tentative ? "tentative" : "cancelled"),
        ]

        if event.isAllDay {
            dict["startTime"] = dateOnlyString(event.startDate)
            dict["endTime"] = dateOnlyString(event.endDate)
        } else {
            dict["startTime"] = isoString(event.startDate)
            dict["endTime"] = isoString(event.endDate)
        }

        if let location = event.location, !location.isEmpty {
            dict["location"] = location
        }
        if let notes = event.notes, !notes.isEmpty {
            dict["notes"] = notes
        }
        if let url = event.url {
            dict["htmlLink"] = url.absoluteString
        }

        var attendees: [[String: Any]] = []
        for a in event.attendees ?? [] {
            var aDict: [String: Any] = [
                "responseStatus": {
                    switch a.participantStatus {
                    case .accepted: return "accepted"
                    case .declined: return "declined"
                    case .tentative: return "tentative"
                    default: return "needsAction"
                    }
                }() as String
            ]
            if let name = a.name { aDict["displayName"] = name }
            let email = a.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            aDict["email"] = email
            attendees.append(aDict)
        }
        dict["attendees"] = attendees

        result.append(dict)
    }

    // Sort by startTime
    result.sort { (a, b) in
        let aTime = (a["startTime"] as? String) ?? ""
        let bTime = (b["startTime"] as? String) ?? ""
        return aTime < bTime
    }

    outputJSON(result)
}

func createEvent(jsonStr: String) {
    guard let data = jsonStr.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        exitError("Invalid JSON")
    }

    guard let title = dict["title"] as? String else {
        exitError("Missing required field: title")
    }
    guard let startStr = dict["startTime"] as? String, let startDate = parseISO(startStr) else {
        exitError("Missing or invalid startTime")
    }
    guard let endStr = dict["endTime"] as? String, let endDate = parseISO(endStr) else {
        exitError("Missing or invalid endTime")
    }

    let event = EKEvent(eventStore: store)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate

    if let calId = dict["calendarId"] as? String,
       let cal = store.calendars(for: .event).first(where: { $0.calendarIdentifier == calId }) {
        event.calendar = cal
    } else {
        event.calendar = store.defaultCalendarForNewEvents
    }

    if let location = dict["location"] as? String {
        event.location = location
    }
    if let notes = dict["notes"] as? String {
        event.notes = notes
    }
    if let isAllDay = dict["isAllDay"] as? Bool {
        event.isAllDay = isAllDay
    }

    do {
        try store.save(event, span: .thisEvent)
        outputJSON([
            "id": event.eventIdentifier ?? "",
            "status": "created",
        ] as [String: Any])
    } catch {
        exitError("Failed to create event: \(error.localizedDescription)")
    }
}

func updateEvent(eventId: String, jsonStr: String) {
    guard let data = jsonStr.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        exitError("Invalid JSON")
    }

    guard let event = store.event(withIdentifier: eventId) else {
        exitError("Event not found: \(eventId)")
    }

    if let title = dict["title"] as? String {
        event.title = title
    }
    if let startStr = dict["startTime"] as? String, let d = parseISO(startStr) {
        event.startDate = d
    }
    if let endStr = dict["endTime"] as? String, let d = parseISO(endStr) {
        event.endDate = d
    }
    if let location = dict["location"] as? String {
        event.location = location
    }
    if let notes = dict["notes"] as? String {
        event.notes = notes
    }

    do {
        try store.save(event, span: .thisEvent)
        outputJSON([
            "id": event.eventIdentifier ?? "",
            "status": "updated",
        ] as [String: Any])
    } catch {
        exitError("Failed to update event: \(error.localizedDescription)")
    }
}

func deleteEvent(eventId: String) {
    guard let event = store.event(withIdentifier: eventId) else {
        exitError("Event not found: \(eventId)")
    }

    do {
        try store.remove(event, span: .thisEvent)
        outputJSON([
            "eventId": eventId,
            "status": "deleted",
        ])
    } catch {
        exitError("Failed to delete event: \(error.localizedDescription)")
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: calendar-helper <command> [args...]\n", stderr)
    fputs("Commands: list-calendars, list-events, create-event, update-event, delete-event\n", stderr)
    exit(1)
}

guard requestAccess() else {
    exitError("Calendar access denied. Grant access in System Settings > Privacy & Security > Calendars.")
}

let command = args[1]

switch command {
case "list-calendars":
    listCalendars()

case "list-events":
    guard args.count >= 4 else {
        exitError("Usage: list-events <startISO> <endISO>")
    }
    listEvents(startStr: args[2], endStr: args[3])

case "create-event":
    guard args.count >= 3 else {
        exitError("Usage: create-event '<json>'")
    }
    createEvent(jsonStr: args[2])

case "update-event":
    guard args.count >= 4 else {
        exitError("Usage: update-event <eventId> '<json>'")
    }
    updateEvent(eventId: args[2], jsonStr: args[3])

case "delete-event":
    guard args.count >= 3 else {
        exitError("Usage: delete-event <eventId>")
    }
    deleteEvent(eventId: args[2])

default:
    exitError("Unknown command: \(command)")
}
