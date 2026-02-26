import SwiftUI
import PhotosUI
import UIKit
import UmiDB
import UmiLocationKit
import UmiCoreKit
import os

private struct AISuggestion: Identifiable, Hashable, Codable {
    let id: String
    let speciesId: String
    let commonName: String
    let scientificName: String
    let confidence: Double
    let siteBoosted: Bool

    init(
        speciesId: String,
        commonName: String,
        scientificName: String,
        confidence: Double,
        siteBoosted: Bool
    ) {
        self.id = speciesId
        self.speciesId = speciesId
        self.commonName = commonName
        self.scientificName = scientificName
        self.confidence = confidence
        self.siteBoosted = siteBoosted
    }
}

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
                        .accessibilityLabel("Back")
                        .accessibilityHint("Go to previous step")
                    Spacer()
                    Button(step < 4 ? "Continue" : "Save") {
                        if step < 4 { step += 1 } else { Task { await saveAndClose() } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed(for: step))
                    .accessibilityLabel(step < 4 ? "Continue" : "Save dive")
                    .accessibilityHint(step < 4 ? "Proceed to next step" : "Save your dive log")
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Log New Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) { Image(systemName: "chevron.backward") }
                        .accessibilityLabel("Close")
                        .accessibilityHint("Dismiss dive logging wizard")
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

            // Post notification to navigate to History tab
            await MainActor.run {
                NotificationCenter.default.post(name: .diveLogSavedSuccessfully, object: nil)
            }
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

struct StepWildlifeNotes: View {
    @Binding var draft: LogDraft
    @State private var search: String = ""
    @State private var results: [WildlifeSpecies] = []
    @State private var speciesNames: [String: String] = [:]
    @State private var availableGear: [GearItem] = []
    @State private var showingPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var targetSpeciesForImport: String?
    @State private var showingCamera = false
    @State private var targetSpeciesForCamera: String?
    @State private var isAnalyzingPhoto = false
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var aiMessage: String?
    private let speciesRepo = SpeciesRepository(database: AppDatabase.shared)
    private let gearRepo = GearRepository(database: AppDatabase.shared)
    private let classifier = SpeciesClassifier()

    private var selectedSpeciesIds: [String] {
        draft.selectedSpecies.sorted { lhs, rhs in
            let leftName = speciesNames[lhs] ?? lhs
            let rightName = speciesNames[rhs] ?? rhs
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wildlife & Notes").font(.headline)

            if !availableGear.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Equipment Used")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Select All") {
                            draft.selectedGearIds = Set(availableGear.map(\.id))
                        }
                        .font(.caption)
                        Button("Clear") {
                            draft.selectedGearIds.removeAll()
                        }
                        .font(.caption)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(availableGear) { item in
                            GearSelectableChip(
                                title: item.name,
                                icon: item.category.systemImage,
                                selected: draft.selectedGearIds.contains(item.id)
                            ) {
                                if draft.selectedGearIds.contains(item.id) {
                                    draft.selectedGearIds.remove(item.id)
                                } else {
                                    draft.selectedGearIds.insert(item.id)
                                }
                            }
                        }
                    }
                }
            }

            TextField("Search species…", text: $search)
                .textFieldStyle(.roundedBorder)
                .onChange(of: search) { Task { await loadResults() } }
            
            ScrollView { // chips grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(results) { sp in
                        SelectableChip(title: sp.name, selected: draft.selectedSpecies.contains(sp.id)) {
                            if draft.selectedSpecies.contains(sp.id) {
                                draft.selectedSpecies.remove(sp.id)
                                draft.speciesPhotos.removeValue(forKey: sp.id)
                                draft.aiMetadataBySpecies.removeValue(forKey: sp.id)
                            } else {
                                draft.selectedSpecies.insert(sp.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !selectedSpeciesIds.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sighting Photos")
                        .font(.subheadline.weight(.semibold))
                    ForEach(selectedSpeciesIds, id: \.self) { speciesId in
                        SpeciesPhotoRow(
                            speciesName: speciesNames[speciesId] ?? speciesId,
                            photos: draft.speciesPhotos[speciesId] ?? [],
                            onAddCamera: {
                                targetSpeciesForCamera = speciesId
                                showingCamera = true
                            },
                            onAddLibrary: {
                                targetSpeciesForImport = speciesId
                                showingPhotoPicker = true
                            },
                            onRemovePhoto: { photoId in
                                var photos = draft.speciesPhotos[speciesId] ?? []
                                photos.removeAll { $0.id == photoId }
                                draft.speciesPhotos[speciesId] = photos
                            }
                        )
                    }
                }
            }

            if isAnalyzingPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing latest photo...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !aiSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Suggestions")
                        .font(.subheadline.weight(.semibold))

                    ForEach(aiSuggestions.prefix(3)) { suggestion in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.commonName)
                                    .font(.subheadline.weight(.semibold))
                                Text(suggestion.scientificName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(suggestion.confidence * 100))% confidence")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if suggestion.siteBoosted {
                                    Text("Likely at this site")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                            Spacer()
                            Button("Select") {
                                applySuggestion(suggestion)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(10)
                    }
                }
            } else if let aiMessage {
                Text(aiMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Notes").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draft.notes)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
        }
        .task {
            await loadResults()
            await loadSpeciesNames(for: Array(draft.selectedSpecies))
            await loadGear()
        }
        .onChange(of: draft.selectedSpecies) { _, newValue in
            let allowed = Set(newValue)
            draft.speciesPhotos = draft.speciesPhotos.filter { allowed.contains($0.key) }
            draft.aiMetadataBySpecies = draft.aiMetadataBySpecies.filter { allowed.contains($0.key) }
            Task { await loadSpeciesNames(for: Array(newValue)) }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let speciesId = targetSpeciesForImport else { return }
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                addLibraryPhoto(data: data, to: speciesId)
                await classifyPhoto(data: data)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(
                sourceType: .camera,
                onImagePicked: { image in
                    guard let speciesId = targetSpeciesForCamera else { return }
                    addCameraPhoto(image: image, to: speciesId)
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        Task { await classifyPhoto(data: data) }
                    }
                }
            )
        }
    }

    private func loadResults() async {
        do {
            results = try speciesRepo.search(search)
        } catch {
            results = []
        }
    }

    private func loadSpeciesNames(for ids: [String]) async {
        guard !ids.isEmpty else { return }
        do {
            let species = try AppDatabase.shared.read { db in
                try WildlifeSpecies.fetchAll(db, keys: ids)
            }
            await MainActor.run {
                for item in species {
                    speciesNames[item.id] = item.name
                }
            }
        } catch {
            Log.wildlife.debug("Failed to load species labels: \(error.localizedDescription)")
        }
    }

    private func loadGear() async {
        do {
            let activeGear = try gearRepo.fetchActive()
            await MainActor.run {
                availableGear = activeGear
                if draft.selectedGearIds.isEmpty {
                    draft.selectedGearIds = Set(activeGear.map(\.id))
                } else {
                    draft.selectedGearIds = draft.selectedGearIds.intersection(Set(activeGear.map(\.id)))
                }
            }
        } catch {
            Log.diveLog.debug("Failed to load gear: \(error.localizedDescription)")
        }
    }

    private func addLibraryPhoto(data: Data, to speciesId: String) {
        var photos = draft.speciesPhotos[speciesId] ?? []
        guard photos.count < 10 else { return }
        let metadata = PhotoMetadataExtractor.extract(from: data)
        photos.append(
            DraftSightingPhotoInput(
                imageData: data,
                capturedAt: metadata.capturedAt,
                latitude: metadata.latitude,
                longitude: metadata.longitude
            )
        )
        draft.speciesPhotos[speciesId] = photos
    }

    private func classifyPhoto(data: Data) async {
        guard let image = UIImage(data: data) else { return }

        await MainActor.run {
            isAnalyzingPhoto = true
            aiMessage = nil
        }

        do {
            let predictions = try await classifier.classify(image: image, maxResults: 8)
            let suggestions = try mapPredictionsToSpecies(predictions)
            await MainActor.run {
                aiSuggestions = Array(suggestions.prefix(3))
                if aiSuggestions.isEmpty {
                    aiMessage = "No confident marine species suggestions. Try manual search."
                }
                isAnalyzingPhoto = false
            }
        } catch {
            await MainActor.run {
                aiSuggestions = []
                aiMessage = "AI identification unavailable right now."
                isAnalyzingPhoto = false
            }
        }
    }

    private func mapPredictionsToSpecies(_ predictions: [SpeciesClassification]) throws -> [AISuggestion] {
        let siteSpeciesIds: Set<String> = {
            guard let siteId = draft.site?.id,
                  let siteSpecies = try? speciesRepo.fetchForSite(siteId) else {
                return []
            }
            return Set(siteSpecies.map(\.id))
        }()

        var seen: Set<String> = []
        var suggestions: [AISuggestion] = []

        for prediction in predictions {
            guard let species = try resolveSpecies(from: prediction) else { continue }
            guard !seen.contains(species.id) else { continue }
            seen.insert(species.id)

            let siteBoosted = siteSpeciesIds.contains(species.id)
            let adjustedConfidence = min(1.0, prediction.confidence * (siteBoosted ? 1.2 : 1.0))
            suggestions.append(
                AISuggestion(
                    speciesId: species.id,
                    commonName: species.name,
                    scientificName: species.scientificName,
                    confidence: adjustedConfidence,
                    siteBoosted: siteBoosted
                )
            )
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    private func resolveSpecies(from prediction: SpeciesClassification) throws -> WildlifeSpecies? {
        let normalized = prediction.normalizedLabel
        let condensed = normalized.replacingOccurrences(of: "  ", with: " ")
        if condensed.isEmpty { return nil }

        if let exact = try AppDatabase.shared.read({ db in
            try WildlifeSpecies
                .filter(sql: "LOWER(scientificName) = ?", arguments: [condensed])
                .fetchOne(db)
        }) {
            return exact
        }

        if let exactCommon = try AppDatabase.shared.read({ db in
            try WildlifeSpecies
                .filter(sql: "LOWER(name) = ?", arguments: [condensed])
                .fetchOne(db)
        }) {
            return exactCommon
        }

        let query = condensed.split(separator: " ").prefix(3).joined(separator: " ")
        let candidates = try speciesRepo.search(query)
        return candidates.first
    }

    private func applySuggestion(_ suggestion: AISuggestion) {
        draft.selectedSpecies.insert(suggestion.speciesId)
        let suggestionsJson = (try? String(data: JSONEncoder().encode(aiSuggestions), encoding: .utf8))
        draft.aiMetadataBySpecies[suggestion.speciesId] = DraftAISightingMetadata(
            confidence: suggestion.confidence,
            suggestionsJson: suggestionsJson
        )
        Task {
            await loadSpeciesNames(for: [suggestion.speciesId])
        }
    }

    private func addCameraPhoto(image: UIImage, to speciesId: String) {
        var photos = draft.speciesPhotos[speciesId] ?? []
        guard photos.count < 10,
              let data = image.jpegData(compressionQuality: 0.9) else { return }
        photos.append(
            DraftSightingPhotoInput(
                imageData: data,
                capturedAt: Date(),
                latitude: nil,
                longitude: nil
            )
        )
        draft.speciesPhotos[speciesId] = photos
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
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(selected ? "deselect" : "select") this species")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct GearSelectableChip: View {
    let title: String
    let icon: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.oceanBlue : .secondary)
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(selected ? Color.oceanBlue.opacity(0.12) : Color.gray.opacity(0.12))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

private struct SpeciesPhotoRow: View {
    let speciesName: String
    let photos: [DraftSightingPhotoInput]
    var onAddCamera: () -> Void
    var onAddLibrary: () -> Void
    var onRemovePhoto: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(speciesName)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(photos.count)/10")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Take Photo", systemImage: "camera", action: onAddCamera)
                        Button("Choose from Library", systemImage: "photo", action: onAddLibrary)
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 74, height: 74)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.headline)
                            }
                    }

                    ForEach(photos) { photo in
                        Group {
                            if let image = UIImage(data: photo.imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.12))
                                    .overlay {
                                        Image(systemName: "photo")
                                    }
                            }
                        }
                        .frame(width: 74, height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contextMenu {
                            Button("Remove", role: .destructive) {
                                onRemovePhoto(photo.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Step 4: Review & Save

struct StepReviewSave: View {
    @Binding var draft: LogDraft
    @Binding var saveSuccess: Bool
    let onSaved: () -> Void
    @State private var speciesNames: [String: String] = [:]
    @State private var gearNames: [String: String] = [:]
    
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
                                .background(Color.diveTeal.opacity(0.15))
                                .cornerRadius(8)
                        }
                        let photoCount = draft.speciesPhotos.values.flatMap { $0 }.count
                        if photoCount > 0 {
                            Text("Photos attached: \(photoCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !draft.selectedGearIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gear Used").font(.subheadline)
                        WrapList(items: Array(draft.selectedGearIds)) { id in
                            Text(gearNames[id] ?? id)
                                .font(.caption)
                                .padding(6)
                                .background(Color.teal.opacity(0.18))
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
            await loadGearNames()
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
            Log.wildlife.debug("Failed to load species names: \(error.localizedDescription)")
        }
    }

    private func loadGearNames() async {
        do {
            let ids = Array(draft.selectedGearIds)
            guard !ids.isEmpty else { return }
            let items = try AppDatabase.shared.read { db in
                try GearItem.fetchAll(db, keys: ids)
            }
            gearNames = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.name) })
        } catch {
            Log.diveLog.debug("Failed to load gear names: \(error.localizedDescription)")
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
        var writtenPhotoPaths: [String] = []
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

            try database.write { db in
                try dive.insert(db)

                for speciesId in draft.selectedSpecies.sorted() {
                    let aiMetadata = draft.aiMetadataBySpecies[speciesId]
                    let sighting = WildlifeSighting(
                        diveId: dive.id,
                        speciesId: speciesId,
                        aiConfidence: aiMetadata?.confidence,
                        aiSuggestionsJson: aiMetadata?.suggestionsJson
                    )
                    try sighting.insert(db)

                    let photoInputs = Array((draft.speciesPhotos[speciesId] ?? []).prefix(10))
                    for (index, photoInput) in photoInputs.enumerated() {
                        guard let image = UIImage(data: photoInput.imageData) else { continue }
                        let saved = try SightingPhotoStorageService.shared.savePhoto(
                            image: image,
                            sightingId: sighting.id
                        )
                        writtenPhotoPaths.append(saved.filename)
                        writtenPhotoPaths.append(saved.thumbnailFilename)

                        let record = SightingPhoto(
                            sightingId: sighting.id,
                            filename: saved.filename,
                            thumbnailFilename: saved.thumbnailFilename,
                            width: saved.width,
                            height: saved.height,
                            capturedAt: photoInput.capturedAt,
                            latitude: photoInput.latitude,
                            longitude: photoInput.longitude,
                            sortOrder: index
                        )
                        try record.insert(db)
                    }
                }

                // Save selected gear links and refresh dive counts per gear item.
                let uniqueGearIds = Array(Set(draft.selectedGearIds))
                for gearId in uniqueGearIds {
                    guard try GearItem.fetchOne(db, key: gearId) != nil else { continue }
                    try DiveGear(diveId: dive.id, gearId: gearId).insert(db)
                }
                for gearId in uniqueGearIds {
                    try db.execute(
                        sql: """
                        UPDATE gear_items
                        SET totalDiveCount = (
                            SELECT COUNT(*) FROM dive_gear WHERE gearId = ?
                        ),
                        updatedAt = ?
                        WHERE id = ?
                        """,
                        arguments: [gearId, Date(), gearId]
                    )
                }

                // Update site visited count + wishlist
                if let existing = try DiveSite.fetchOne(db, key: site.id) {
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
                        isPlanned: existing.isPlanned,
                        visitedCount: existing.visitedCount + 1,
                        tags: existing.tags,
                        createdAt: existing.createdAt,
                        countryId: existing.countryId,
                        regionId: existing.regionId,
                        areaId: existing.areaId,
                        wikidataId: existing.wikidataId,
                        osmId: existing.osmId
                    )
                    try updated.update(db)
                }
            }
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
            return true
        } catch {
            for path in writtenPhotoPaths {
                SightingPhotoStorageService.shared.deleteFile(relativePath: path)
            }
            Log.diveLog.error("Wizard save failed: \(error.localizedDescription)")
            return false
        }
    }
}

#Preview {
    LiveLogWizardView()
}
