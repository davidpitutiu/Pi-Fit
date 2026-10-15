import Combine
import Foundation
import HealthKit
import WatchConnectivity

final class WatchWorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    static let shared = WatchWorkoutManager()
    @Published private(set) var heartRate: Double?
    @Published private(set) var measuredAt: Date?
    @Published private(set) var isRunning = false
    @Published private(set) var isActive = false
    @Published private(set) var message = "Start to allow workout and heart-rate access."
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var sessionID = UUID().uuidString
    private var authorizing = false
    private var startGeneration = 0
    private var lastState = "ready"
    private var watchConnectivity: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            watchConnectivity = WCSession.default
            watchConnectivity?.delegate = self
            watchConnectivity?.activate()
        }
    }

    func start(configuration: HKWorkoutConfiguration? = nil) {
        guard !isRunning, !authorizing, workoutSession == nil else { return }
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            message = "HealthKit is unavailable on this watch."
            return
        }
        startGeneration += 1
        let generation = startGeneration
        sessionID = UUID().uuidString
        authorizing = true
        message = "Allow heart-rate reading and workout sessions."
        sendState("starting", message: message)
        // Workout authorization is required for a genuine background-capable
        // HKWorkoutSession. We discard its builder instead of saving a duplicate.
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRateType]) { success, error in
            DispatchQueue.main.async {
                guard self.startGeneration == generation else { return }
                self.authorizing = false
                guard success, error == nil,
                      self.healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                    self.message = "Workout access was not granted. Review Health permissions on your watch."
                    self.sendState("error", message: self.message)
                    return
                }
                let selected = configuration ?? HKWorkoutConfiguration()
                if configuration == nil {
                    selected.activityType = .traditionalStrengthTraining
                    selected.locationType = .indoor
                }
                do {
                    let session = try HKWorkoutSession(healthStore: self.healthStore, configuration: selected)
                    let builder = session.associatedWorkoutBuilder()
                    builder.dataSource = HKLiveWorkoutDataSource(healthStore: self.healthStore, workoutConfiguration: selected)
                    builder.delegate = self
                    session.delegate = self
                    self.workoutSession = session
                    self.isActive = true
                    self.builder = builder
                    self.heartRate = nil
                    self.measuredAt = nil
                    let start = Date()
                    session.startActivity(with: start)
                    builder.beginCollection(withStart: start) { success, error in
                        if !success || error != nil {
                            DispatchQueue.main.async {
                                guard self.workoutSession === session else { return }
                                self.message = error?.localizedDescription ?? "Live collection could not start."
                                self.sendState("error", message: self.message)
                                session.end()
                            }
                        }
                    }
                } catch {
                    self.message = error.localizedDescription
                    self.sendState("error", message: self.message)
                }
            }
        }
    }

    func stop() {
        startGeneration += 1
        authorizing = false
        if let session = workoutSession {
            session.end()
        } else {
            isRunning = false
            isActive = false
            heartRate = nil
            measuredAt = nil
            message = "Workout stopped. Session discarded."
            sendState("stopped")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            guard self.workoutSession === workoutSession else { return }
            if toState == .running {
                self.isRunning = true
                self.message = "Waiting for a sensor measurement…"
                self.sendState("running")
            } else if toState == .ended {
                self.isRunning = false
                self.isActive = false
                self.message = "Workout stopped. Session discarded."
                self.heartRate = nil
                self.measuredAt = nil
                self.sendState("stopped")
                let activeBuilder = self.builder
                activeBuilder?.endCollection(withEnd: date) { _, _ in
                    activeBuilder?.discardWorkout()
                }
                self.workoutSession = nil
                self.builder = nil
            } else if toState == .paused {
                self.isRunning = false
                self.message = "The watch workout is paused."
                self.sendState("paused", message: self.message)
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            guard self.workoutSession === workoutSession else { return }
            self.isRunning = false
            self.isActive = false
            self.message = error.localizedDescription
            self.sendState("error", message: self.message)
            self.builder?.discardWorkout()
            self.builder = nil
            self.workoutSession = nil
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate), collectedTypes.contains(type),
              let statistics = workoutBuilder.statistics(for: type),
              let quantity = statistics.mostRecentQuantity(),
              let interval = statistics.mostRecentQuantityDateInterval() else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let timestamp = interval.end
        guard bpm.isFinite, bpm > 0, bpm <= 350 else { return }
        DispatchQueue.main.async {
            guard self.isRunning, self.builder === workoutBuilder else { return }
            self.heartRate = bpm
            self.measuredAt = timestamp
            self.message = self.watchConnectivity?.isReachable == true ? "Streaming to iPhone" : "iPhone unreachable. Keep Pi Fit open on your phone."
            self.sendSample(bpm: bpm, timestamp: timestamp)
        }
    }

    private func sendState(_ state: String, message: String? = nil) {
        lastState = state
        guard let connection = watchConnectivity, connection.activationState == .activated, connection.isReachable else { return }
        var payload: [String: Any] = ["kind": "status", "state": state, "sessionId": sessionID]
        if let message { payload["message"] = message }
        connection.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    private func sendSample(bpm: Double, timestamp: Date) {
        guard let connection = watchConnectivity, connection.activationState == .activated, connection.isReachable else { return }
        connection.sendMessage([
            "kind": "sample", "state": "running", "running": true,
            "sessionId": sessionID, "bpm": bpm,
            "timestamp": timestamp.timeIntervalSince1970
        ], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error { self.message = error.localizedDescription }
            self.sendState(self.lastState)
        }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.sendState(self.lastState)
            if self.isRunning, let bpm = self.heartRate, let timestamp = self.measuredAt {
                // An old sample retains its original timestamp; the iPhone
                // labels it stale rather than inventing a new measurement.
                self.sendSample(bpm: bpm, timestamp: timestamp)
            }
        }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if message["command"] as? String == "stop" {
                if let requestedSession = message["sessionId"] as? String,
                   requestedSession != self.sessionID {
                    replyHandler(["accepted": false])
                    return
                }
                self.stop()
                replyHandler(["accepted": true])
            } else {
                replyHandler(["accepted": false])
            }
        }
    }
}
