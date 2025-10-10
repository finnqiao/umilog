import SwiftUI
import UmiDB
import UmiLocationKit

/// Coordinates the 4-step logging wizard. For P1 we wire Step 1 & 2.
public struct LiveLogWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LogDraft
    @State private var step: Int = 1 // 1..4
    
    public init(initialSite: DiveSite? = nil) {
        _draft = State(initialValue: LogDraft(site: initialSite))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                StepperBar(step: step)
                
                Group {
                    switch step {
                    case 1:
                        StepSiteTiming(draft: $draft)
                    case 2:
                        StepMetrics(draft: $draft)
                    default:
                        PlaceholderStep(title: "Coming soon")
                    }
                }
                .animation(.default, value: step)
                
                Spacer(minLength: 8)
                
                HStack {
                    Button("Back") { step = max(1, step - 1) }
                        .buttonStyle(.bordered)
                        .disabled(step == 1)
                    Spacer()
                    Button(step < 2 ? "Continue" : "Done") {
                        if step < 2 { step += 1 } else { dismiss() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Log New Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) { Image(systemName: "chevron.backward") }
                }
            }
        }
    }
}

// MARK: - Stepper Bar

struct StepperBar: View {
    let step: Int
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
            Capsule().fill(Color.oceanBlue).frame(width: CGFloat(step) / 4.0 * UIScreen.main.bounds.width * 0.9, height: 6)
        }.accessibilityLabel("Step \(step) of 4")
    }
}

// MARK: - Step 1: Site & Timing

struct StepSiteTiming: View {
    @Binding var draft: LogDraft
    @State private var showingSitePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dive Site & Timing", systemImage: "mappin.and.ellipse").font(.headline)
            Button(action: { showingSitePicker = true }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(draft.site?.name ?? "Select site").font(.headline)
                        Text(draft.site?.location ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            HStack(spacing: 12) {
                DatePicker("Date", selection: $draft.date, displayedComponents: [.date])
                DatePicker("Start", selection: $draft.startTime, displayedComponents: [.hourAndMinute])
            }
        }
        .sheet(isPresented: $showingSitePicker) {
            SitePickerView(selectedSite: Binding(get: { draft.site }, set: { draft.site = $0 }))
        }
    }
}

// MARK: - Step 2: Metrics

struct StepMetrics: View {
    @Binding var draft: LogDraft
    @FocusState private var focused: Field?
    enum Field { case depth, time }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Dive Metrics", systemImage: "gauge.medium").font(.headline)
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Max Depth (m)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("18", value: $draft.maxDepthM, format: .number).textFieldStyle(.roundedBorder).keyboardType(.decimalPad).focused($focused, equals: .depth)
                        Text("m").foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Bottom Time (min)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("45", value: $draft.bottomTimeMin, format: .number).textFieldStyle(.roundedBorder).keyboardType(.numberPad).focused($focused, equals: .time)
                        Text("min").foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 16) {
                LabeledIntTextField(title: "Start Pressure", suffix: "bar", value: $draft.startPressureBar)
                LabeledIntTextField(title: "End Pressure", suffix: "bar", value: $draft.endPressureBar)
            }
            HStack(spacing: 16) {
                LabeledDoubleTextField(title: "Temperature", suffix: "°C", value: $draft.temperatureC)
                LabeledDoubleTextField(title: "Visibility", suffix: "m", value: $draft.visibilityM)
            }
        }
    }
}

struct LabeledDoubleTextField: View {
    let title: String
    let suffix: String
    @Binding var value: Double?
    
    private var stringBinding: Binding<String> {
        Binding<String>(
            get: { value.flatMap { String(format: "%.0f", $0) } ?? "" },
            set: { input in
                if let v = Double(input) { value = v } else if input.isEmpty { value = nil }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("--", text: stringBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }
}

struct LabeledIntTextField: View {
    let title: String
    let suffix: String
    @Binding var value: Int?
    
    private var stringBinding: Binding<String> {
        Binding<String>(
            get: { value.map(String.init) ?? "" },
            set: { input in
                if let v = Int(input) { value = v } else if input.isEmpty { value = nil }
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("--", text: stringBinding)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Placeholder for steps 3/4 while scaffolding

struct PlaceholderStep: View {
    let title: String
    var body: some View {
        VStack { Spacer(); Text(title).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
    }
}

#Preview {
    LiveLogWizardView()
}
