import SwiftUI

public struct DiveLoggerView: View {
    public init() {}
    
    @State private var selectedSite = ""
    @State private var date = Date()
    @State private var maxDepth = ""
    @State private var bottomTime = ""
    
    public var body: some View {
        Form {
            Section("Dive Site") {
                TextField("Search or select site", text: $selectedSite)
            }
            
            Section("Date & Time") {
                DatePicker("Dive Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            
            Section("Dive Details") {
                HStack {
                    Text("Max Depth")
                    Spacer()
                    TextField("0", text: $maxDepth)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("m")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Bottom Time")
                    Spacer()
                    TextField("0", text: $bottomTime)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    Text("min")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button("Save Dive") {
                    // TODO: Save dive
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .tint(.oceanBlue)
            }
        }
        .navigationTitle("Log Dive")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DiveLoggerView()
    }
}
