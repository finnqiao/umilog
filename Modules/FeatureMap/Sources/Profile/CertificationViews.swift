import SwiftUI
import PhotosUI
import UmiDB
import UmiCoreKit
import UmiDesignSystem

struct CertificationsSectionView: View {
    let certifications: [Certification]
    var onAdd: () -> Void
    var onEdit: (Certification) -> Void
    var onDelete: (Certification) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Certifications")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color.lagoon)
            }
            .padding(.horizontal, 16)

            if certifications.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No certification cards added")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.foam)
                    Text("Store your C-Card details and photos for quick access at dive check-in.")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.trench)
                .cornerRadius(16)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(certifications) { certification in
                        CertificationCardView(
                            certification: certification,
                            onEdit: { onEdit(certification) },
                            onDelete: { onDelete(certification) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct CertificationCardView: View {
    let certification: Certification
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var previewImage: UIImage?
    @State private var showingImagePreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(certification.agency.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mist)
                    Text(certification.level)
                        .font(.headline)
                        .foregroundStyle(Color.foam)
                }

                Spacer()

                if certification.isPrimary {
                    Text("Primary")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.abyss)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.reef)
                        .clipShape(Capsule())
                }
            }

            if let certNumber = certification.certNumber, !certNumber.isEmpty {
                Text("Cert #: \(certNumber)")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }
            if let certDate = certification.certDate {
                Text("Since \(certDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }
            if let instructor = certification.instructorName, !instructor.isEmpty {
                Text("Instructor: \(instructor)")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }

            HStack(spacing: 8) {
                CertificationStoredImageButton(
                    title: "Front",
                    relativePath: certification.cardImageFront
                ) { image in
                    previewImage = image
                    showingImagePreview = true
                }

                CertificationStoredImageButton(
                    title: "Back",
                    relativePath: certification.cardImageBack
                ) { image in
                    previewImage = image
                    showingImagePreview = true
                }

                Spacer()
            }

            HStack {
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Color.lagoon)

                Button("Delete", role: .destructive, action: onDelete)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.oceanBlue.opacity(0.35), Color.trench],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .fullScreenCover(isPresented: $showingImagePreview) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
                Button {
                    showingImagePreview = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .padding()
                }
            }
        }
    }
}

private struct CertificationStoredImageButton: View {
    let title: String
    let relativePath: String?
    var onTap: (UIImage) -> Void

    var body: some View {
        let image = storedImage
        Button {
            if let image {
                onTap(image)
            }
        } label: {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.kelp.opacity(0.7)
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.mist)
                    }
                }
            }
            .frame(width: 72, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(image == nil)
    }

    private var storedImage: UIImage? {
        guard let relativePath,
              let url = CertificationCardStorageService.shared.imageURL(forRelativePath: relativePath) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

struct CertificationFormView: View {
    private let existing: Certification?
    private let defaultPrimary: Bool
    private let onSave: (Certification) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var agency: CertAgency
    @State private var agencyOther: String
    @State private var level: String
    @State private var certNumber: String
    @State private var certDate: Date
    @State private var hasCertDate: Bool
    @State private var expiryDate: Date
    @State private var hasExpiryDate: Bool
    @State private var instructorName: String
    @State private var instructorNumber: String
    @State private var notes: String
    @State private var isPrimary: Bool

    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var frontPickerItem: PhotosPickerItem?
    @State private var backPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var cameraSide: CertificationCardSide = .front

    @State private var errorMessage: String?

    init(
        existing: Certification? = nil,
        defaultPrimary: Bool = false,
        onSave: @escaping (Certification) -> Void
    ) {
        self.existing = existing
        self.defaultPrimary = defaultPrimary
        self.onSave = onSave

        _agency = State(initialValue: existing?.agency ?? .padi)
        _agencyOther = State(initialValue: existing?.agencyOther ?? "")
        _level = State(initialValue: existing?.level ?? "")
        _certNumber = State(initialValue: existing?.certNumber ?? "")
        _certDate = State(initialValue: existing?.certDate ?? Date())
        _hasCertDate = State(initialValue: existing?.certDate != nil)
        _expiryDate = State(initialValue: existing?.expiryDate ?? Date())
        _hasExpiryDate = State(initialValue: existing?.expiryDate != nil)
        _instructorName = State(initialValue: existing?.instructorName ?? "")
        _instructorNumber = State(initialValue: existing?.instructorNumber ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _isPrimary = State(initialValue: existing?.isPrimary ?? defaultPrimary)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Certification") {
                    Picker("Agency", selection: $agency) {
                        ForEach(CertAgency.allCases, id: \.self) { agency in
                            Text(agency.displayName).tag(agency)
                        }
                    }

                    if agency == .other {
                        TextField("Agency name", text: $agencyOther)
                    }

                    if !agency.commonLevels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(agency.commonLevels, id: \.self) { option in
                                    Button(option) {
                                        level = option
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(level == option ? Color.lagoon : Color.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    TextField("Level", text: $level)
                    TextField("Certification number", text: $certNumber)
                }

                Section("Dates") {
                    Toggle("Include certification date", isOn: $hasCertDate)
                    if hasCertDate {
                        DatePicker("Certified on", selection: $certDate, displayedComponents: .date)
                    }

                    Toggle("Include expiry date", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("Expires on", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Instructor") {
                    TextField("Instructor name", text: $instructorName)
                    TextField("Instructor number", text: $instructorNumber)
                }

                Section("Card photos") {
                    CertificationPhotoSlot(
                        title: "Front",
                        image: frontImage,
                        storedPath: existing?.cardImageFront,
                        onCameraTap: { openCamera(for: .front) },
                        pickerItem: $frontPickerItem
                    )

                    CertificationPhotoSlot(
                        title: "Back",
                        image: backImage,
                        storedPath: existing?.cardImageBack,
                        onCameraTap: { openCamera(for: .back) },
                        pickerItem: $backPickerItem
                    )
                }

                Section("Options") {
                    Toggle("Mark as primary certification", isOn: $isPrimary)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(existing == nil ? "Add Certification" : "Edit Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveCertification() }
                        .disabled(level.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraImagePicker(
                    sourceType: .camera,
                    onImagePicked: { image in
                        if cameraSide == .front {
                            frontImage = image
                        } else {
                            backImage = image
                        }
                    }
                )
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: frontPickerItem) { _, newItem in
                Task {
                    if let image = await loadUIImage(from: newItem) {
                        frontImage = image
                    }
                }
            }
            .onChange(of: backPickerItem) { _, newItem in
                Task {
                    if let image = await loadUIImage(from: newItem) {
                        backImage = image
                    }
                }
            }
        }
    }

    private func openCamera(for side: CertificationCardSide) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        cameraSide = side
        showingCamera = true
    }

    private func loadUIImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveCertification() {
        let id = existing?.id ?? UUID().uuidString
        let createdAt = existing?.createdAt ?? Date()
        var frontPath = existing?.cardImageFront
        var backPath = existing?.cardImageBack

        do {
            if let frontImage {
                frontPath = try CertificationCardStorageService.shared.saveCardImage(
                    frontImage,
                    certificationId: id,
                    side: .front
                )
            }
            if let backImage {
                backPath = try CertificationCardStorageService.shared.saveCardImage(
                    backImage,
                    certificationId: id,
                    side: .back
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let certification = Certification(
            id: id,
            agency: agency,
            agencyOther: agency == .other ? agencyOther.nilIfEmpty : nil,
            level: level.trimmingCharacters(in: .whitespacesAndNewlines),
            certNumber: certNumber.nilIfEmpty,
            certDate: hasCertDate ? certDate : nil,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            instructorName: instructorName.nilIfEmpty,
            instructorNumber: instructorNumber.nilIfEmpty,
            divesAtCert: existing?.divesAtCert,
            cardImageFront: frontPath,
            cardImageBack: backPath,
            notes: notes.nilIfEmpty,
            isPrimary: isPrimary,
            createdAt: createdAt,
            updatedAt: Date()
        )

        onSave(certification)
        dismiss()
    }
}

private struct CertificationPhotoSlot: View {
    let title: String
    let image: UIImage?
    let storedPath: String?
    var onCameraTap: () -> Void
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let storedImage = storedImage {
                    Image(uiImage: storedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.18))
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 92, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Button {
                        onCameraTap()
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Library", systemImage: "photo")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var storedImage: UIImage? {
        guard let storedPath,
              let url = CertificationCardStorageService.shared.imageURL(forRelativePath: storedPath) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
