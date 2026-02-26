import SwiftUI
import UmiDB
import UmiDesignSystem

/// Lightweight sheet for submitting dive site conditions without logging a full dive.
public struct QuickReportSheet: View {
    let siteId: String
    let siteName: String
    let onDismiss: () -> Void

    @State private var visibility: Double = 15
    @State private var temperature: Double = 26
    @State private var current: ConditionReport.Current = .none
    @State private var surfaceConditions: ConditionReport.SurfaceConditions = .calm
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var showRateLimitAlert = false

    @Environment(\.dismiss) private var dismiss

    public init(siteId: String, siteName: String, onDismiss: @escaping () -> Void) {
        self.siteId = siteId
        self.siteName = siteName
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Visibility")
                            Spacer()
                            Text("\(Int(visibility))m")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Slider(value: $visibility, in: 0...40, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Water Temp")
                            Spacer()
                            Text("\(Int(temperature))\u{00B0}C")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        Slider(value: $temperature, in: 0...38, step: 1)
                    }
                } header: {
                    Text("Conditions")
                }

                Section {
                    Picker("Current", selection: $current) {
                        ForEach(ConditionReport.Current.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Surface", selection: $surfaceConditions) {
                        ForEach(ConditionReport.SurfaceConditions.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Anything noteworthy?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("e.g., jellyfish spotted, unusually clear, strong surge")
                }
            }
            .navigationTitle("Report at \(siteName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitReport()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Too Soon", isPresented: $showRateLimitAlert) {
                Button("OK") {}
            } message: {
                Text("You already submitted a report for this site recently. Please wait before submitting another.")
            }
        }
    }

    private func submitReport() {
        isSaving = true

        Task {
            do {
                let repo = AppDatabase.shared.conditionReportRepository

                // Rate limit check
                if try repo.hasRecentReport(siteId: siteId, reporterId: "") {
                    await MainActor.run {
                        isSaving = false
                        showRateLimitAlert = true
                    }
                    return
                }

                let report = ConditionReport(
                    siteId: siteId,
                    visibility: visibility,
                    current: current,
                    temperature: temperature,
                    surfaceConditions: surfaceConditions,
                    notes: notes.isEmpty ? nil : notes,
                    source: .quickReport
                )
                try repo.create(report)

                await MainActor.run {
                    onDismiss()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
