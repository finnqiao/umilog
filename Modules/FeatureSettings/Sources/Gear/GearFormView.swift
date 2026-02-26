import SwiftUI
import UmiDB

struct GearFormView: View {
    @Environment(\.dismiss) private var dismiss

    let existingItem: GearItem?
    var onSaved: (() -> Void)?

    @State private var name: String = ""
    @State private var category: GearCategory = .regulator
    @State private var brand: String = ""
    @State private var model: String = ""
    @State private var serialNumber: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var hasPurchaseDate = false
    @State private var lastServiceDate: Date = Date()
    @State private var hasLastServiceDate = false
    @State private var nextServiceDate: Date = Date()
    @State private var hasNextServiceDate = false
    @State private var serviceIntervalMonths: Int = 12
    @State private var notes: String = ""
    @State private var isActive = true
    @State private var showingError = false
    @State private var errorMessage = ""

    private let repository = GearRepository(database: AppDatabase.shared)

    init(existingItem: GearItem? = nil, onSaved: (() -> Void)? = nil) {
        self.existingItem = existingItem
        self.onSaved = onSaved
        _name = State(initialValue: existingItem?.name ?? "")
        _category = State(initialValue: existingItem?.category ?? .regulator)
        _brand = State(initialValue: existingItem?.brand ?? "")
        _model = State(initialValue: existingItem?.model ?? "")
        _serialNumber = State(initialValue: existingItem?.serialNumber ?? "")
        _purchaseDate = State(initialValue: existingItem?.purchaseDate ?? Date())
        _hasPurchaseDate = State(initialValue: existingItem?.purchaseDate != nil)
        _lastServiceDate = State(initialValue: existingItem?.lastServiceDate ?? Date())
        _hasLastServiceDate = State(initialValue: existingItem?.lastServiceDate != nil)
        _nextServiceDate = State(initialValue: existingItem?.nextServiceDate ?? Date())
        _hasNextServiceDate = State(initialValue: existingItem?.nextServiceDate != nil)
        _serviceIntervalMonths = State(initialValue: existingItem?.serviceIntervalMonths ?? existingItem?.category.defaultServiceIntervalMonths ?? 12)
        _notes = State(initialValue: existingItem?.notes ?? "")
        _isActive = State(initialValue: existingItem?.isActive ?? true)
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(GearCategory.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                TextField("Brand", text: $brand)
                TextField("Model", text: $model)
                TextField("Serial Number", text: $serialNumber)
            }

            Section("Service") {
                Toggle("Purchase Date", isOn: $hasPurchaseDate)
                if hasPurchaseDate {
                    DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date)
                }

                Toggle("Last Service Date", isOn: $hasLastServiceDate)
                if hasLastServiceDate {
                    DatePicker("Last Service", selection: $lastServiceDate, displayedComponents: .date)
                }

                Toggle("Next Service Date", isOn: $hasNextServiceDate)
                if hasNextServiceDate {
                    DatePicker("Next Service", selection: $nextServiceDate, displayedComponents: .date)
                }

                Stepper("Service Interval: \(serviceIntervalMonths) months", value: $serviceIntervalMonths, in: 1...60)
            }

            Section("Status") {
                Toggle("Active", isOn: $isActive)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(existingItem == nil ? "Add Gear" : "Edit Gear")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Couldn’t Save Gear", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        let now = Date()
        let item = GearItem(
            id: existingItem?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            brand: brand.emptyToNil,
            model: model.emptyToNil,
            serialNumber: serialNumber.emptyToNil,
            purchaseDate: hasPurchaseDate ? purchaseDate : nil,
            lastServiceDate: hasLastServiceDate ? lastServiceDate : nil,
            nextServiceDate: hasNextServiceDate ? nextServiceDate : nil,
            serviceIntervalMonths: serviceIntervalMonths,
            notes: notes.emptyToNil,
            isActive: isActive,
            totalDiveCount: existingItem?.totalDiveCount ?? 0,
            createdAt: existingItem?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try repository.upsert(item)
            let all = try repository.fetchAll(includeRetired: true)
            Task { await GearReminderService.shared.scheduleReminders(for: all) }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

private extension String {
    var emptyToNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
