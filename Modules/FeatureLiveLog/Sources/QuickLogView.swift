import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiLocationKit

/// Quick log view for one-tap dive logging with smart defaults

enum QuickLogField: Hashable {
    case depth, bottomTime, notes
}

public struct QuickLogView: View {
    @StateObject private var viewModel = QuickLogViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: QuickLogField?
    
    // Optional pre-filled site from geofencing
    private let suggestedSite: DiveSite?
    
    public init(suggestedSite: DiveSite? = nil) {
        self.suggestedSite = suggestedSite
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Quick actions
                    QuickActionsSection(viewModel: viewModel)
                    
                    // Site selection
                    SiteSelectionSection(viewModel: viewModel)
                    
                    // Essential fields
                    EssentialFieldsSection(viewModel: viewModel, focusedField: $focusedField)
                    
                    // Optional fields (collapsed by default)
                    OptionalFieldsSection(viewModel: viewModel)
                    
                    // Save button
                    SaveButton(viewModel: viewModel) {
                        Task {
                            await saveDive()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to save dive")
            }
        }
        .task {
            await viewModel.initialize(with: suggestedSite)
        }
    }
    
    private func saveDive() async {
        let success = await viewModel.saveDive()
        if success {
            dismiss()
        }
    }
}

// MARK: - Components

struct QuickActionsSection: View {
    @ObservedObject var viewModel: QuickLogViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(SwiftUI.Font.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                // Same as last dive
                Button(action: { viewModel.fillFromLastDive() }) {
                    Label("Same as Last", systemImage: "arrow.clockwise")
                        .font(SwiftUI.Font.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.hasLastDive)
                
                // Use current location
                Button(action: { 
                    Task { await viewModel.useCurrentLocation() }
                }) {
                    Label("Current Location", systemImage: "location.fill")
                        .font(SwiftUI.Font.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct SiteSelectionSection: View {
    @ObservedObject var viewModel: QuickLogViewModel
    @State private var showingSitePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dive Site")
                .font(SwiftUI.Font.caption)
                .foregroundStyle(.secondary)
            
            Button(action: { showingSitePicker = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let site = viewModel.selectedSite {
                            Text(site.name)
                                .font(SwiftUI.Font.headline)
                                .foregroundStyle(.primary)
                            Text(site.location)
                                .font(SwiftUI.Font.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Select dive site")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(SwiftUI.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingSitePicker) {
            SitePickerView(selectedSite: $viewModel.selectedSite)
        }
    }
}

struct EssentialFieldsSection: View {
    @ObservedObject var viewModel: QuickLogViewModel
    @FocusState.Binding var focusedField: QuickLogField?
    
    var body: some View {
        VStack(spacing: 16) {
            // Date and Time
            DatePicker(
                "Date & Time",
                selection: $viewModel.diveDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            
            HStack(spacing: 16) {
                // Max Depth
                VStack(alignment: .leading, spacing: 4) {
                        Text("Max Depth")
                            .font(SwiftUI.Font.caption)
                            .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("0", value: $viewModel.maxDepth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .depth)
                        
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Bottom Time
                VStack(alignment: .leading, spacing: 4) {
                        Text("Bottom Time")
                            .font(SwiftUI.Font.caption)
                            .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("0", value: $viewModel.bottomTime, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .bottomTime)
                        
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Quick depth buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([18, 25, 30, 35, 40], id: \.self) { depth in
                        Button("\(depth)m") {
                            viewModel.maxDepth = Double(depth)
                            focusedField = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // Quick time buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([30, 40, 45, 50, 60], id: \.self) { time in
                        Button("\(time)min") {
                            viewModel.bottomTime = time
                            focusedField = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

struct OptionalFieldsSection: View {
    @ObservedObject var viewModel: QuickLogViewModel
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 16) {
                // Water temperature
                HStack {
                    Label("Water Temp", systemImage: "thermometer.medium")
                        .font(SwiftUI.Font.subheadline)
                    
                    Spacer()
                    
                    HStack {
                        TextField("--", value: $viewModel.waterTemp, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        
                        Text("°C")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Visibility
                HStack {
                    Label("Visibility", systemImage: "eye")
                        .font(SwiftUI.Font.subheadline)
                    
                    Spacer()
                    
                    HStack {
                        TextField("--", value: $viewModel.visibility, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Buddy
                HStack {
                    Label("Buddy", systemImage: "person.2")
                        .font(SwiftUI.Font.subheadline)
                    
                    Spacer()
                    
                    TextField("Dive buddy", text: $viewModel.buddy)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 150)
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text")
                        .font(SwiftUI.Font.subheadline)
                    
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("More Details", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(SwiftUI.Font.subheadline)
                .foregroundStyle(Color.oceanBlue)
        }
    }
}

struct SaveButton: View {
    @ObservedObject var viewModel: QuickLogViewModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if viewModel.isSaving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(viewModel.saveButtonTitle)
                        .font(SwiftUI.Font.headline)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isSaving || !viewModel.canSave)
    }
}

// MARK: - Site Picker

struct SitePickerView: View {
    @Binding var selectedSite: DiveSite?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sites: [DiveSite] = []
    
    var filteredSites: [DiveSite] {
        if searchText.isEmpty {
            return sites
        } else {
            return sites.filter { site in
                site.name.localizedCaseInsensitiveContains(searchText) ||
                site.location.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSites) { site in
                    Button(action: {
                        selectedSite = site
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(site.name)
                                    .font(SwiftUI.Font.headline)
                                    .foregroundStyle(.primary)
                                
                                Text(site.location)
                                    .font(SwiftUI.Font.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if site.id == selectedSite?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.oceanBlue)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dive sites")
            .navigationTitle("Select Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadSites()
            }
        }
    }
    
    private func loadSites() async {
        do {
            let repository = SiteRepository(database: AppDatabase.shared)
            sites = try repository.getAllSites()
        } catch {
            print("Failed to load sites: \(error)")
        }
    }
}

#Preview {
    QuickLogView()
}