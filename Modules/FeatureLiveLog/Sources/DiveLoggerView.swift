import SwiftUI
import UmiDB
import UmiDesignSystem

public struct DiveLoggerView: View {
    @StateObject private var viewModel = DiveLoggerViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        Form {
            // Site Selection
            Section("Dive Site") {
                if let site = viewModel.selectedSite {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(site.name)
                            .font(SwiftUI.Font.headline)
                        Text(site.location)
                            .font(SwiftUI.Font.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker("Select Site", selection: $viewModel.selectedSite) {
                        ForEach(viewModel.availableSites) { site in
                            Text(site.name).tag(Optional(site))
                        }
                    }
                } else {
                    Text("No sites available")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Date & Time
            Section("Date & Time") {
                DatePicker("Dive Date", selection: $viewModel.diveDate, displayedComponents: [.date])
                DatePicker("Start Time", selection: $viewModel.startTime, displayedComponents: [.hourAndMinute])
            }
            
            // Dive Details (Required)
            Section {
                HStack {
                    Label("Max Depth", systemImage: "arrow.down")
                    Spacer()
                    TextField("0", text: $viewModel.maxDepth)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("Bottom Time", systemImage: "clock")
                    Spacer()
                    TextField("0", text: $viewModel.bottomTime)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Dive Details")
            } footer: {
                Text("Required fields")
            }
            
            // Pressures
            Section("Tank Pressure") {
                HStack {
                    Label("Start", systemImage: "gauge.high")
                    Spacer()
                    TextField("200", text: $viewModel.startPressure)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("bar")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("End", systemImage: "gauge.low")
                    Spacer()
                    TextField("50", text: $viewModel.endPressure)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("bar")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Environment
            Section("Environment") {
                HStack {
                    Label("Temperature", systemImage: "thermometer")
                    Spacer()
                    TextField("27", text: $viewModel.temperature)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("°C")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("Visibility", systemImage: "eye")
                    Spacer()
                    TextField("30", text: $viewModel.visibility)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m")
                        .foregroundStyle(.secondary)
                }
                
                Picker("Current", selection: $viewModel.current) {
                    ForEach([DiveLog.Current.none, .light, .moderate, .strong], id: \.self) { current in
                        Text(current.rawValue).tag(current)
                    }
                }
                
                Picker("Conditions", selection: $viewModel.conditions) {
                    ForEach([DiveLog.Conditions.excellent, .good, .fair, .poor], id: \.self) { condition in
                        Text(condition.rawValue).tag(condition)
                    }
                }
            }
            
            // Notes
            Section("Notes") {
                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 100)
            }
            
            // Instructor Sign-off
            Section("Instructor Sign-off (Optional)") {
                TextField("Instructor Name", text: $viewModel.instructorName)
                TextField("Instructor Number", text: $viewModel.instructorNumber)
                Toggle("Signed", isOn: $viewModel.signed)
            }
            
            // Save Button
            Section {
                Button {
                    Task {
                        if await viewModel.saveDive() {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Dive")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isLoading)
                .buttonStyle(.borderedProminent)
                .tint(Color.oceanBlue)
            }
        }
        .navigationTitle("Log Dive")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DiveLoggerView()
    }
}
