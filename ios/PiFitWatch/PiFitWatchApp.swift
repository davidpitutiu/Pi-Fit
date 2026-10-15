import SwiftUI
import WatchKit
import HealthKit

@main
struct PiFitWatchApp: App {
    @WKApplicationDelegateAdaptor(WorkoutApplicationDelegate.self) var applicationDelegate
    @StateObject private var workout = WatchWorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(spacing: 12) {
                    Text("PI FIT").font(.headline).foregroundStyle(Color(red: 0.78, green: 1, blue: 0.24))
                    Image(systemName: "heart.fill").foregroundStyle(.red).font(.title2)
                    if let bpm = workout.heartRate {
                        Text("\(Int(bpm.rounded()))").font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("BPM").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.largeTitle)
                    }
                    if let timestamp = workout.measuredAt {
                        Text(timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(workout.message).font(.caption).multilineTextAlignment(.center)
                    if workout.isActive {
                        Button("Stop workout", role: .destructive) { workout.stop() }
                    } else {
                        Button("Start live heart rate") { workout.start() }
                            .tint(Color(red: 0.78, green: 1, blue: 0.24))
                    }
                    Text("Live sensor readings are sent to your reachable iPhone. This watch session is discarded when stopped.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 8)
            }
        }
    }
}

final class WorkoutApplicationDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        DispatchQueue.main.async { WatchWorkoutManager.shared.start(configuration: workoutConfiguration) }
    }
}
