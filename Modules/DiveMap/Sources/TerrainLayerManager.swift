import Foundation
import MapLibre
import UIKit

final class TerrainLayerManager {
    private let sourceId = "bathymetry-dem"
    private let hillshadeLayerId = "bathymetry-hillshade"

    // Open Terrarium DEM tiles (global coverage).
    private let demTemplates = [
        "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
    ]

    func update(
        on mapView: MLNMapView,
        enabled: Bool,
        exaggeration: Double
    ) {
        guard let style = mapView.style else { return }
        if enabled {
            enable(on: style, exaggeration: exaggeration)
        } else {
            disable(on: style)
        }
    }

    private func enable(on style: MLNStyle, exaggeration: Double) {
        let source: MLNRasterDEMSource
        if let existing = style.source(withIdentifier: sourceId) as? MLNRasterDEMSource {
            source = existing
        } else {
            let dem = MLNRasterDEMSource(
                identifier: sourceId,
                tileURLTemplates: demTemplates,
                options: [.tileSize: 256]
            )
            style.addSource(dem)
            source = dem
        }

        if let existingLayer = style.layer(withIdentifier: hillshadeLayerId) as? MLNHillshadeStyleLayer {
            existingLayer.hillshadeExaggeration = NSExpression(forConstantValue: exaggeration)
            existingLayer.isVisible = true
            return
        }

        let hillshade = MLNHillshadeStyleLayer(identifier: hillshadeLayerId, source: source)
        hillshade.hillshadeIlluminationDirection = NSExpression(forConstantValue: 315)
        hillshade.hillshadeExaggeration = NSExpression(forConstantValue: exaggeration)
        hillshade.hillshadeShadowColor = NSExpression(forConstantValue: UIColor(red: 0.04, green: 0.10, blue: 0.18, alpha: 0.95))
        hillshade.hillshadeHighlightColor = NSExpression(forConstantValue: UIColor(red: 0.17, green: 0.55, blue: 0.62, alpha: 0.7))
        hillshade.hillshadeAccentColor = NSExpression(forConstantValue: UIColor(red: 0.09, green: 0.24, blue: 0.36, alpha: 0.6))
        style.addLayer(hillshade)
    }

    private func disable(on style: MLNStyle) {
        if let layer = style.layer(withIdentifier: hillshadeLayerId) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceId) {
            style.removeSource(source)
        }
    }
}
