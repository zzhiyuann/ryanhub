import Foundation

@MainActor
class RBToolCallRouter {
    private let bridge: RBOpenClawBridge
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    init(bridge: RBOpenClawBridge) {
        self.bridge = bridge
    }

    func handleToolCall(
        _ call: RBGeminiFunctionCall,
        sendResponse: @escaping ([String: Any]) -> Void
    ) {
        let callId = call.id
        let callName = call.name

        let task = Task { @MainActor in
            let taskDesc = call.args["task"] as? String ?? String(describing: call.args)
            let result = await bridge.delegateTask(task: taskDesc, toolName: callName)

            guard !Task.isCancelled else { return }

            let response = self.buildToolResponse(callId: callId, name: callName, result: result)
            sendResponse(response)

            self.inFlightTasks.removeValue(forKey: callId)
        }

        inFlightTasks[callId] = task
    }

    func cancelToolCalls(ids: [String]) {
        for id in ids {
            if let task = inFlightTasks[id] {
                task.cancel()
                inFlightTasks.removeValue(forKey: id)
            }
        }
        bridge.lastToolCallStatus = .cancelled(ids.first ?? "unknown")
    }

    func cancelAll() {
        for (_, task) in inFlightTasks {
            task.cancel()
        }
        inFlightTasks.removeAll()
    }

    private func buildToolResponse(
        callId: String,
        name: String,
        result: RBToolResult
    ) -> [String: Any] {
        return [
            "toolResponse": [
                "functionResponses": [
                    [
                        "id": callId,
                        "name": name,
                        "response": result.responseValue
                    ]
                ]
            ]
        ]
    }
}
