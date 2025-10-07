import SwiftUI

public struct DiveHistoryView: View {
    public init() {}
    
    public var body: some View {
        List {
            Text("No dives yet")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Dive History")
        .searchable(text: .constant(""))
    }
}

#Preview {
    NavigationStack {
        DiveHistoryView()
    }
}
