import SwiftUI
import PhotosUI
import UIKit
import UmiDB
import UmiLocationKit
import UmiCoreKit
import os

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
    @State private var showingPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var targetSpeciesForImport: String?
    @State private var showingCamera = false
    @State private var targetSpeciesForCamera: String?
    private let speciesRepo = SpeciesRepository(database: AppDatabase.shared)

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
        }
        .onChange(of: draft.selectedSpecies) { _, newValue in
            let allowed = Set(newValue)
            draft.speciesPhotos = draft.speciesPhotos.filter { allowed.contains($0.key) }
            Task { await loadSpeciesNames(for: Array(newValue)) }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let speciesId = targetSpeciesForImport else { return }
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                addLibraryPhoto(data: data, to: speciesId)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(
                sourceType: .camera,
                onImagePicked: { image in
                    guard let speciesId = targetSpeciesForCamera else { return }
                    addCameraPhoto(image: image, to: speciesId)
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
            Log.wildlife.debug("Failed to load species names: \(error.localizedDescription)")
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
                    let sighting = WildlifeSighting(diveId: dive.id, speciesId: speciesId)
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
