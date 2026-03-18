import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiLocationKit
import UmiCoreKit
import UserNotifications

/// Real-time dive timer flow:
/// 1. Pre-dive: Select site (or GPS) → tap "Start Dive"
/// 2. During dive: Timer runs in background
/// 3. Surface: Notification → open post-dive logging
/// 4. Post-dive: Wizard with pre-filled site + start time + duration
public struct LiveDiveTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // Pre-dive state
    @State private var selectedSite: DiveSite?
    @State private var showingSitePicker = false
    @State private var isUsingGPS = false

    // Timer state
    @State private var diveState: DiveTimerState = .preDive
    @State private var startTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Post-dive
    @State private var showPostDiveWizard = false

    private let initialSite: DiveSite?

    public init(initialSite: DiveSite? = nil) {
        self.initialSite = initialSite
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch diveState {
                case .preDive:
                    preDiveContent
                case .diving:
                    divingContent
                case .surfaced:
                    surfacedContent
                }
            }
            .padding()
            .navigationTitle(diveState.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if diveState == .preDive {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                selectedSite = initialSite
                requestNotificationPermission()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, diveState == .diving {
                    updateElapsedTime()
                }
            }
            .sheet(isPresented: $showPostDiveWizard) {
                if let site = selectedSite {
                    LiveLogWizardView(initialSite: site)
                } else {
                    LiveLogWizardView()
                }
            }
        }
    }

    // MARK: - Pre-Dive

    private var preDiveContent: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Ready to Dive?")
                    .font(.title2.bold())

                Text("Select your dive site and tap Start when you enter the water.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Site selection
            Button {
                showingSitePicker = true
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.blue)
                    if let site = selectedSite {
                        VStack(alignment: .leading) {
                            Text(site.name)
                                .font(.headline)
                            Text(site.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Select dive site")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .sheet(isPresented: $showingSitePicker) {
                SitePickerView(selectedSite: $selectedSite)
            }

            Spacer()

            // Start Dive button
            Button {
                startDive()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                    Text("Start Dive")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .accessibilityLabel("Start dive timer")
        }
    }

    // MARK: - Diving

    private var divingContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Elapsed time display
            VStack(spacing: 8) {
                Text("Dive in Progress")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(formattedElapsedTime)
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .monospacedDigit()

                if let site = selectedSite {
                    Text(site.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Your phone is safe — put it away and enjoy your dive!")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Surface button
            Button {
                endDive()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("I've Surfaced")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("End dive and surface")
        }
    }

    // MARK: - Surfaced

    private var surfacedContent: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Welcome Back!")
                    .font(.title2.bold())

                Text("Dive duration: \(formattedElapsedTime)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text("Ready to log the details of your dive?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showPostDiveWizard = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.line")
                        Text("Log Dive Details")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                Button("Log Later") {
                    scheduleReminderNotification()
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Timer Logic

    private func startDive() {
        startTime = Date()
        diveState = .diving
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateElapsedTime()
        }

        Haptics.success()
    }

    private func endDive() {
        timer?.invalidate()
        timer = nil
        updateElapsedTime()
        diveState = .surfaced
        Haptics.success()
    }

    private func updateElapsedTime() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
    }

    private var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    private func scheduleReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Don't forget to log your dive!"
        content.body = "Tap to finish logging your dive details."
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false) // 30 min
        let request = UNNotificationRequest(identifier: "dive-log-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - State

enum DiveTimerState {
    case preDive
    case diving
    case surfaced

    var title: String {
        switch self {
        case .preDive: return "Start Dive"
        case .diving: return "Diving"
        case .surfaced: return "Surfaced"
        }
    }
}
