import Flutter
import HealthKit
import WatchConnectivity

/// A transient WatchConnectivity bridge. No health samples are persisted,
/// queued with transferUserInfo, added to applicationContext, or uploaded.
final class LiveHeartRateBridge: NSObject, FlutterStreamHandler, WCSessionDelegate {
    private let healthStore = HKHealthStore()
    private var eventSink: FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var watchSession: WCSession?
    private var running = false
    private var state = "checking"
    private var sessionID: String?
    private var lastSample: [String: Any]?
    private var endedSessions = Set<String>()
    private var startGeneration = 0

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        methodChannel = FlutterMethodChannel(name: "com.pifit.app/live-heart-rate/methods", binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: "com.pifit.app/live-heart-rate/events", binaryMessenger: messenger)
        eventChannel?.setStreamHandler(self)
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "initialize":
                self.activate()
                result(self.payload())
            case "start":
                self.startWatchWorkout(result: result)
            case "stop":
                self.stopWatchWorkout(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func activate() {
        guard WCSession.isSupported() else {
            state = "error"
            publish(message: "WatchConnectivity is unavailable on this iPhone.")
            return
        }
        if watchSession == nil {
            watchSession = WCSession.default
            watchSession?.delegate = self
        }
        watchSession?.activate()
    }

    private func payload(kind: String = "status") -> [String: Any] {
        let activated = watchSession?.activationState == .activated
        var result: [String: Any] = [
            "kind": kind,
            "state": state,
            "paired": activated && watchSession?.isPaired == true,
            "installed": activated && watchSession?.isWatchAppInstalled == true,
            "reachable": activated && watchSession?.isReachable == true,
            "running": running
        ]
        if let sessionID { result["sessionId"] = sessionID }
        return result
    }

    private func publish(message: String? = nil) {
        var event = payload()
        if let message { event["message"] = message }
        eventSink?(event)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        publish()
        if let lastSample, running { events(lastSample) }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func startWatchWorkout(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: "HEALTH_UNAVAILABLE", message: "HealthKit is unavailable on this iPhone.", details: nil))
            return
        }
        guard let watchSession, watchSession.activationState == .activated,
              watchSession.isPaired, watchSession.isWatchAppInstalled else {
            result(FlutterError(code: "WATCH_NOT_READY", message: "Pair an Apple Watch and install the Pi Fit watch app first.", details: nil))
            return
        }
        startGeneration += 1
        let generation = startGeneration
        state = "starting"
        lastSample = nil
        publish(message: "Open Pi Fit on Apple Watch and allow workout and heart-rate access.")
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        healthStore.startWatchApp(with: configuration) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.startGeneration == generation else { result(nil); return }
                if let error {
                    self.state = "error"
                    self.publish(message: error.localizedDescription)
                    result(FlutterError(code: "WATCH_START_FAILED", message: error.localizedDescription, details: nil))
                } else if !success {
                    self.state = "error"
                    self.publish(message: "Open Pi Fit on Apple Watch and tap Start.")
                    result(FlutterError(code: "WATCH_START_FAILED", message: "Open Pi Fit on Apple Watch and tap Start.", details: nil))
                } else {
                    // Launch success is not evidence of a running sensor stream.
                    result(nil)
                }
            }
        }
    }

    private func stopWatchWorkout(result: @escaping FlutterResult) {
        startGeneration += 1
        guard let watchSession, watchSession.isReachable else {
            result(FlutterError(code: "WATCH_UNREACHABLE", message: "The watch is unreachable. Stop the session in Pi Fit on Apple Watch.", details: nil))
            return
        }
        var command: [String: Any] = ["command": "stop"]
        if let sessionID { command["sessionId"] = sessionID }
        watchSession.sendMessage(command, replyHandler: { reply in
            DispatchQueue.main.async {
                if reply["accepted"] as? Bool == true {
                    result(nil)
                } else {
                    result(FlutterError(code: "SESSION_CHANGED", message: "The earlier watch session has already changed; the current session was not stopped.", details: nil))
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                result(FlutterError(code: "WATCH_STOP_FAILED", message: "The stop command was not delivered. Stop on Apple Watch. \(error.localizedDescription)", details: nil))
            }
        })
    }

    private func receive(_ message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let identifier = message["sessionId"] as? String else { return }
            let incomingState = message["state"] as? String
            if self.endedSessions.contains(identifier) { return }
            if let currentID = self.sessionID, currentID != identifier,
               ["stopped", "paused", "error", "ready"].contains(incomingState ?? ""),
               (self.running || self.state == "starting" || self.state == "paused") {
                if incomingState == "stopped" { self.endedSessions.insert(identifier) }
                return
            }
            if incomingState == "stopped" {
                self.endedSessions.insert(identifier)
                self.running = false
                self.state = "stopped"
                self.sessionID = identifier
                self.lastSample = nil
                self.publish(message: "The Apple Watch session has ended.")
                return
            }
            if incomingState == "ready" {
                self.running = false
                self.state = "ready"
                self.lastSample = nil
                self.publish()
                return
            }
            if incomingState == "starting" {
                if let previousID = self.sessionID, previousID != identifier {
                    self.endedSessions.insert(previousID)
                }
                self.sessionID = identifier
                self.running = false
                self.lastSample = nil
                self.state = "starting"
                self.publish(message: message["message"] as? String)
                return
            }
            if incomingState == "paused" {
                self.running = false
                self.state = "paused"
                self.publish(message: "The Apple Watch workout is paused.")
                return
            }
            if incomingState == "error" {
                self.running = false
                self.state = "error"
                self.publish(message: message["message"] as? String ?? "The watch workout failed.")
                return
            }
            if incomingState == "running" {
                self.sessionID = identifier
                self.running = true
                self.state = "running"
            }
            if message["kind"] as? String == "sample",
               let bpm = message["bpm"] as? NSNumber,
               let timestamp = message["timestamp"] as? NSNumber,
               bpm.doubleValue.isFinite, bpm.doubleValue > 0, bpm.doubleValue <= 350,
               timestamp.doubleValue.isFinite,
               timestamp.doubleValue <= Date().timeIntervalSince1970 + 5,
               self.running {
                var event = self.payload(kind: "sample")
                event["bpm"] = bpm.doubleValue
                event["timestamp"] = timestamp.doubleValue
                event["source"] = "Apple Watch · Pi Fit workout"
                // A delivered live packet proves the Watch→iPhone path is
                // reachable, even if the reverse command path is temporarily
                // unavailable while the watch workout runs in background.
                event["reachable"] = true
                self.lastSample = event
                self.eventSink?(event)
            } else {
                self.publish(message: message["message"] as? String)
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.state = error == nil ? (self.running ? "running" : "ready") : "error"
            self.publish(message: error?.localizedDescription)
        }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { self.state = "disconnected"; self.publish() }
    }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.publish() }
    }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.publish() }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { receive(message) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        receive(message)
        replyHandler(["received": true])
    }
}
