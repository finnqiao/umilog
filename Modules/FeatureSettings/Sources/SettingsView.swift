import SwiftUI

public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        List {
            Section("Account") {
                NavigationLink("Privacy Settings") {
                    Text("Privacy settings")
                }
                NavigationLink("Sync") {
                    Text("iCloud sync")
                }
            }
            
            Section("Data") {
                Button("Export Data") {}
                Button("Import Data") {}
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0")
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Attributions") {
                    Text("Open source licenses")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
