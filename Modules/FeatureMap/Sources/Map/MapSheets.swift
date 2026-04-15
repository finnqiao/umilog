import SwiftUI
import UmiDB
import UmiDesignSystem

// MARK: - Layer Sheet

struct LayerSheet: View {
    @Binding var layerSettings: MapLayerSettings
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Underwater glow", isOn: $layerSettings.showUnderwaterGlow)
                        .onChange(of: layerSettings.showUnderwaterGlow) { Haptics.tap() }
                    Toggle("Cluster rings", isOn: $layerSettings.showClusters)
                        .onChange(of: layerSettings.showClusters) { Haptics.tap() }
                    Toggle("Status glows", isOn: $layerSettings.showStatusGlows)
                        .onChange(of: layerSettings.showStatusGlows) { Haptics.tap() }
                    Toggle("Color by difficulty", isOn: $layerSettings.colorByDifficulty)
                        .onChange(of: layerSettings.colorByDifficulty) { Haptics.tap() }
                } header: {
                    Text("Visuals")
                }
            }
            .navigationTitle("Map Layers")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDismiss(); dismiss() } } }
        }
    }
}
