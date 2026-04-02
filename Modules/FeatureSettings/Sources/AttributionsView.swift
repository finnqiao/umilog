import SwiftUI

/// View displaying open source licenses and data attributions
public struct AttributionsView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                AttributionRow(
                    name: "OpenDiveSites",
                    description: "Community-contributed dive site database",
                    license: "CC BY-SA 4.0"
                )
                AttributionRow(
                    name: "Wikidata",
                    description: "Structured knowledge base for dive site locations",
                    license: "CC0 1.0"
                )
                AttributionRow(
                    name: "OpenStreetMap",
                    description: "Geographic data and coastlines",
                    license: "ODbL 1.0"
                )
            } header: {
                Text("Data Sources")
            }

            Section {
                AttributionRow(
                    name: "MapLibre",
                    description: "Open-source map rendering",
                    license: "BSD 3-Clause"
                )
                AttributionRow(
                    name: "ESRI Ocean Basemap",
                    description: "Ocean floor imagery",
                    license: "Esri Master License"
                )
                AttributionRow(
                    name: "CARTO",
                    description: "Cartographic base layers",
                    license: "CC BY 3.0"
                )
            } header: {
                Text("Map Tiles")
            }

            Section {
                AttributionRow(
                    name: "GRDB.swift",
                    description: "SQLite database toolkit",
                    license: "MIT"
                )
                AttributionRow(
                    name: "MapLibre Native",
                    description: "Map rendering engine",
                    license: "BSD 3-Clause"
                )
            } header: {
                Text("Open Source Libraries")
            }

            Section {
                Text("UmiLog uses open data and open source software to provide a privacy-focused dive logging experience. All processing happens on your device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AttributionRow: View {
    let name: String
    let description: String
    let license: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(license)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AttributionsView()
    }
}
