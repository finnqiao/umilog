import SwiftUI
import UmiDB
import UmiLocationKit

/// Coordinates the 4-step logging wizard. For P1 we wire Step 1 & 2.
public struct LiveLogWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LogDraft
    @State private var step: Int = 1 // 1..4
    @State private var showSuccessBanner: Bool = false
    
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
                    case 3:
                        StepWildlifeNotes(draft: $draft)
                    case 4:
                        StepReviewSave(draft: $draft, saveSuccess: $showSuccessBanner, onSaved: { dismiss() })
                    default:
                        StepSiteTiming(draft: $draft)
                    }
                }
                .animation(.default, value: step)
                
                Spacer(minLength: 8)
                
                HStack {
                    Button("Back") { step = max(1, step - 1) }
                        .buttonStyle(.bordered)
                        .disabled(step == 1)
                    Spacer()
                    Button(step < 4 ? "Continue" : "Save") {
                        if step < 4 { step += 1 } else { Task { await saveAndClose() } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed(for: step))
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
    
    private func canProceed(for step: Int) -> Bool {
        switch step {
        case 1:
            return draft.site != nil
        case 2:
            return (draft.maxDepthM ?? 0) > 0 && (draft.bottomTimeMin ?? 0) > 0
        case 3:
            return true
        default:
            return true
        }
    }
    
    private func saveAndClose() async {
        let ok = await WizardSaver.save(draft: draft)
        if ok {
            await MainActor.run {
                showSuccessBanner = true
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // half sec to show banner
            dismiss()
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

// MARK: - Step 3: Wildlife & Notes

import UmiCoreKit

struct StepWildlifeNotes: View {
    @Binding var draft: LogDraft
    @State private var search: String = ""
    @State private var results: [WildlifeSpecies] = []
    private let speciesRepo = SpeciesRepository(database: AppDatabase.shared)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wildlife & Notes").font(.headline)
            TextField("Search species…", text: $search)
                .textFieldStyle(.roundedBorder)
                .onChange(of: search) { _ in Task { await loadResults() } }
            
            ScrollView { // chips grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(results) { sp in
                        SelectableChip(title: sp.name, selected: draft.selectedSpecies.contains(sp.id)) {
                            if draft.selectedSpecies.contains(sp.id) {
                                draft.selectedSpecies.remove(sp.id)
                            } else {
                                draft.selectedSpecies.insert(sp.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Text("Notes").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draft.notes)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
        .task { await loadResults() }
    }
    
    private func loadResults() async {
        do {
            results = try speciesRepo.search(search)
        } catch {
            results = []
        }
    }
}

struct SelectableChip: View {
    let title: String
    var selected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(selected ? .white : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.oceanBlue : Color.gray.opacity(0.15))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Review & Save

struct StepReviewSave: View {
    @Binding var draft: LogDraft
    @Binding var saveSuccess: Bool
    let onSaved: () -> Void
    @State private var speciesNames: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 16) {
            if saveSuccess {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        Text("Dive Logged Successfully!")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button {
                        onSaved()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View in History")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.oceanBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                }
            } else {
                Text("Review & Save").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Site:").foregroundStyle(.secondary); Spacer(); Text(draft.site?.name ?? "—") }
                    HStack { Text("Date:").foregroundStyle(.secondary); Spacer(); Text(draft.date, style: .date) }
                    HStack { Text("Max Depth:").foregroundStyle(.secondary); Spacer(); Text("\(Int(draft.maxDepthM ?? 0)) m") }
                    HStack { Text("Bottom Time:").foregroundStyle(.secondary); Spacer(); Text("\(draft.bottomTimeMin ?? 0) min") }
                    HStack { Text("Temperature:").foregroundStyle(.secondary); Spacer(); Text(valueString(draft.temperatureC, suffix: "°C")) }
                    HStack { Text("Visibility:").foregroundStyle(.secondary); Spacer(); Text(valueString(draft.visibilityM, suffix: "m")) }
                }
                .padding()
                .background(Color.gray.opacity(0.06))
                .cornerRadius(12)
                
                if !draft.selectedSpecies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wildlife Spotted").font(.subheadline)
                        WrapList(items: Array(draft.selectedSpecies)) { id in
                            Text(speciesNames[id] ?? id)
                                .font(.caption)
                                .padding(6)
                                .background(Color.purple.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !draft.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").font(.subheadline)
                        Text(draft.notes).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .task {
            await loadSpeciesNames()
        }
    }
    
    private func loadSpeciesNames() async {
        do {
            let ids = Array(draft.selectedSpecies)
            guard !ids.isEmpty else { return }
            let species = try AppDatabase.shared.read { db in
                try WildlifeSpecies.fetchAll(db, keys: ids)
            }
            speciesNames = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0.name) })
        } catch {
            print("Failed to load species names: \(error)")
        }
    }
    
    private func valueString(_ v: Double?, suffix: String) -> String { v != nil ? "\(Int(v!)) \(suffix)" : "—" }
}

struct WrapList<ItemView: View>: View {
    let items: [String]
    let builder: (String) -> ItemView
    
    var body: some View {
        VStack(alignment: .leading) {
            var width: CGFloat = 0
            var height: CGFloat = 0
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(items, id: \.self) { item in
                        builder(item)
                            .padding(4)
                            .alignmentGuide(.leading, computeValue: { d in
                                if (abs(width - d.width) > geo.size.width) {
                                    width = 0
                                    height -= d.height
                                }
                                let res = width
                                if item == items.last { width = 0 } else { width -= d.width }
                                return res
                            })
                            .alignmentGuide(.top, computeValue: { d in
                                let res = height
                                if item == items.last { height = 0 } else {}
                                return res
                            })
                    }
                }
            }.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Save logic helper

enum WizardSaver {
    static func save(draft: LogDraft) async -> Bool {
        guard let site = draft.site,
              let maxDepth = draft.maxDepthM,
              let bottomTime = draft.bottomTimeMin else { return false }
        let database = AppDatabase.shared
        let diveRepo = DiveRepository(database: database)
        do {
            let end = draft.startTime.addingTimeInterval(Double(bottomTime) * 60)
            let dive = DiveLog(
                siteId: site.id,
                date: draft.date,
                startTime: draft.startTime,
                endTime: end,
                maxDepth: maxDepth,
                averageDepth: maxDepth * 0.7,
                bottomTime: bottomTime,
                startPressure: draft.startPressureBar ?? 200,
                endPressure: draft.endPressureBar ?? 50,
                temperature: draft.temperatureC ?? 26,
                visibility: draft.visibilityM ?? 15,
                notes: draft.notes
            )
            try diveRepo.create(dive)
            
            // Save sightings
            try database.write { db in
                for speciesId in draft.selectedSpecies {
                    let s = WildlifeSighting(diveId: dive.id, speciesId: speciesId)
                    try s.insert(db)
                }
                // Update site visited count + wishlist
                if var existing = try DiveSite.fetchOne(db, key: site.id) {
                    let updated = DiveSite(
                        id: existing.id,
                        name: existing.name,
                        location: existing.location,
                        latitude: existing.latitude,
                        longitude: existing.longitude,
                        region: existing.region,
                        averageDepth: existing.averageDepth,
                        maxDepth: existing.maxDepth,
                        averageTemp: existing.averageTemp,
                        averageVisibility: existing.averageVisibility,
                        difficulty: existing.difficulty,
                        type: existing.type,
                        description: existing.description,
                        wishlist: false,
                        visitedCount: existing.visitedCount + 1,
                        createdAt: existing.createdAt
                    )
                    try updated.update(db)
                }
            }
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
            return true
        } catch {
            print("Wizard save failed: \(error)")
            return false
        }
    }
}

#Preview {
    LiveLogWizardView()
}
