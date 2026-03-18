import SwiftUI
import UmiDB
import UmiDesignSystem

/// Content view for Plan mode in the unified bottom surface.
/// Shows planned sites list and allows adding/removing sites from trip.
struct PlanContent: View {
    // MARK: - Properties

    let context: PlanContext
    let allSites: [DiveSite]
    let detent: SurfaceDetent

    var onAddSite: () -> Void
    var onRemoveSite: (String) -> Void
    var onClose: () -> Void
    var onSaveTrip: ((Trip) -> Void)?

    // MARK: - State

    @State private var showingNameInput = false
    @State private var tripName = ""
    @State private var isSaving = false

    // Optional dive planning fields per site
    @State private var divePlans: [String: DivePlanFields] = [:]
    @State private var expandedPlanId: String?

    private let tripRepository = TripRepository(database: AppDatabase.shared)

    // MARK: - Computed

    private var plannedSites: [DiveSite] {
        context.plannedSiteIds.compactMap { id in
            allSites.first { $0.id == id }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            if plannedSites.isEmpty {
                emptyState
            } else {
                sitesList
            }

            Spacer(minLength: 0)

            footer
        }
        .alert("Name Your Trip", isPresented: $showingNameInput) {
            TextField("Trip name", text: $tripName)
            Button("Cancel", role: .cancel) {
                tripName = ""
            }
            Button("Save") {
                saveTrip()
            }
            .disabled(tripName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a name for your trip with \(plannedSites.count) dive site\(plannedSites.count == 1 ? "" : "s")")
        }
    }

    // MARK: - Actions

    private func saveTrip() {
        let name = tripName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isSaving = true
        let siteIds = context.plannedSiteIds

        Task {
            do {
                let trip = try tripRepository.createFromSites(name: name, siteIds: siteIds)
                await MainActor.run {
                    isSaving = false
                    tripName = ""
                    onSaveTrip?(trip)
                    onClose()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Show error - for now just close
                    onClose()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trip Plan")
                    .font(.headline)
                    .foregroundStyle(Color.foam)

                Text("\(plannedSites.count) site\(plannedSites.count == 1 ? "" : "s") planned")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.mist)
            }
            .accessibilityLabel("Close trip plan")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("Start Planning Your Trip")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Add dive sites to create your trip itinerary")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .multilineTextAlignment(.center)

            Button(action: onAddSite) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Site")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.foam)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.lagoon)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Sites List

    private var sitesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(plannedSites.enumerated()), id: \.element.id) { index, site in
                    plannedSiteRow(site: site, index: index + 1)
                }

                addSiteButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func plannedSiteRow(site: DiveSite, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Order number
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.foam)
                    .frame(width: 24, height: 24)
                    .background(Color.lagoon)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(site.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text(site.location)
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                // Dive plan toggle
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if expandedPlanId == site.id {
                            expandedPlanId = nil
                        } else {
                            expandedPlanId = site.id
                            if divePlans[site.id] == nil {
                                divePlans[site.id] = DivePlanFields()
                            }
                        }
                    }
                } label: {
                    Image(systemName: expandedPlanId == site.id ? "chevron.up" : "gauge.medium")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lagoon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dive plan details")

                Button {
                    onRemoveSite(site.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(site.name) from plan")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)

            // Dive planning fields (optional)
            if expandedPlanId == site.id {
                divePlanFields(for: site.id)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.trench)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }

    private func divePlanFields(for siteId: String) -> some View {
        let binding = Binding(
            get: { divePlans[siteId] ?? DivePlanFields() },
            set: { divePlans[siteId] = $0 }
        )

        return VStack(spacing: 10) {
            Divider().overlay(Color.ocean.opacity(0.3))

            HStack(spacing: 12) {
                planField(label: "Depth", value: binding.targetDepth, unit: "m")
                planField(label: "Time", value: binding.plannedBottomTime, unit: "min")
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gas Mix")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                    Picker("", selection: binding.gasMix) {
                        Text("Air").tag(DivePlanFields.GasMix.air)
                        Text("EAN32").tag(DivePlanFields.GasMix.ean32)
                        Text("EAN36").tag(DivePlanFields.GasMix.ean36)
                    }
                    .pickerStyle(.segmented)
                }

                planField(label: "SI", value: binding.surfaceInterval, unit: "min")
            }
        }
    }

    private func planField(label: String, value: Binding<Double?>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.mist)
            HStack(spacing: 4) {
                TextField("--", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 60)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }
        }
    }

    private var addSiteButton: some View {
        Button(action: onAddSite) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("Add another site")
                    .font(.subheadline)
            }
            .foregroundStyle(Color.lagoon)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.lagoon.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.ocean.opacity(0.3))

            HStack(spacing: 12) {
                Button(action: onClose) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.mist)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.trench)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    showingNameInput = true
                } label: {
                    Text("Save Trip")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(plannedSites.isEmpty ? Color.mist.opacity(0.3) : Color.lagoon)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(plannedSites.isEmpty || isSaving)
            }
            .padding(16)
        }
    }
}

#if DEBUG
struct PlanContent_Previews: PreviewProvider {
    static var previews: some View {
        PlanContent(
            context: PlanContext(
                plannedSiteIds: [],
                returnContext: ExploreContext()
            ),
            allSites: [],
            detent: .expanded,
            onAddSite: {},
            onRemoveSite: { _ in },
            onClose: {},
            onSaveTrip: { _ in }
        )
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
