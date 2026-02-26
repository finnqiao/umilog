import SwiftUI
import UmiDB
import UmiCoreKit

public struct GearListView: View {
    @State private var items: [GearItem] = []
    @State private var showingAdd = false
    @State private var editingItem: GearItem?
    @State private var alertMessage: String?

    private let repository = GearRepository(database: AppDatabase.shared)

    public init() {}

    public var body: some View {
        List {
            if activeItems.isEmpty && retiredItems.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Gear Yet",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add your first gear item to track usage and service reminders.")
                    )
                }
            }

            if !activeItems.isEmpty {
                Section("Active") {
                    ForEach(activeItems) { item in
                        GearItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                            }
                    }
                    .onDelete { offsets in
                        delete(items: offsets.map { activeItems[$0] })
                    }
                }
            }

            if !retiredItems.isEmpty {
                Section("Retired") {
                    ForEach(retiredItems) { item in
                        GearItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                            }
                    }
                    .onDelete { offsets in
                        delete(items: offsets.map { retiredItems[$0] })
                    }
                }
            }
        }
        .navigationTitle("My Gear")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add gear")
            }
        }
        .task {
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .diveLogUpdated)) { _ in
            reload()
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                GearFormView {
                    reload()
                }
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                GearFormView(existingItem: item) {
                    reload()
                }
            }
        }
        .alert("Gear", isPresented: Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented { alertMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var activeItems: [GearItem] {
        items.filter(\.isActive)
    }

    private var retiredItems: [GearItem] {
        items.filter { !$0.isActive }
    }

    private func reload() {
        do {
            items = try repository.fetchAll(includeRetired: true)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func delete(items: [GearItem]) {
        do {
            for item in items {
                try repository.delete(id: item.id)
            }
            reload()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct GearItemRow: View {
    let item: GearItem

    private var serviceText: String {
        guard let nextServiceDate = item.nextServiceDate else { return "No service schedule" }
        if nextServiceDate < Date() {
            return "Service overdue"
        }
        return "Service due \(nextServiceDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var serviceColor: Color {
        guard let nextServiceDate = item.nextServiceDate else { return .secondary }
        return nextServiceDate < Date() ? .red : .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.systemImage)
                .frame(width: 24)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(item.totalDiveCount) dives")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(serviceText)
                    .font(.caption2)
                    .foregroundStyle(serviceColor)
            }

            Spacer()

            if !item.isActive {
                Text("Retired")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
