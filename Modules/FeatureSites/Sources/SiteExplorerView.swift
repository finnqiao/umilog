import SwiftUI

public struct SiteExplorerView: View {
    public init() {}
    
    public var body: some View {
        List {
            Text("No dive sites loaded")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Dive Sites")
        .searchable(text: .constant(""))
    }
}

#Preview {
    NavigationStack {
        SiteExplorerView()
    }
}
