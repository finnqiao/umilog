import Foundation
import MapLibre
import UIKit

public struct DiveMapHeatmapPoint: Hashable {
    public let latitude: Double
    public let longitude: Double
    public let diveCount: Int

    public init(latitude: Double, longitude: Double, diveCount: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.diveCount = diveCount
    }
}

final class HeatmapLayerManager {
    private let sourceId = "dive-heatmap-source"
    private let layerId = "dive-heatmap-layer"

    func update(points: [DiveMapHeatmapPoint], on mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        remove(from: mapView)
        guard !points.isEmpty else { return }

        let features = points.map { point -> MLNPointFeature in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            feature.attributes = [
                "diveCount": point.diveCount
            ]
            return feature
        }

        let source = MLNShapeSource(identifier: sourceId, features: features, options: nil)
        style.addSource(source)

        let layer = MLNHeatmapStyleLayer(identifier: layerId, source: source)

        let weightStops: [Double: Double] = [
            1: 0.3,
            5: 0.6,
            20: 1.0
        ]
        layer.heatmapWeight = NSExpression(
            format: "mgl_interpolate:withCurveType:parameters:stops:(diveCount, 'linear', nil, %@)",
            weightStops as NSDictionary
        )

        let colorStops: [Double: UIColor] = [
            0.0: UIColor.clear,
            0.2: UIColor(red: 0.04, green: 0.09, blue: 0.16, alpha: 1.0),
            0.4: UIColor(red: 0.05, green: 0.23, blue: 0.40, alpha: 1.0),
            0.6: UIColor(red: 0.11, green: 0.60, blue: 0.55, alpha: 1.0),
            0.8: UIColor(red: 0.18, green: 0.77, blue: 0.71, alpha: 1.0),
            1.0: UIColor(red: 0.80, green: 0.95, blue: 0.94, alpha: 1.0)
        ]
        layer.heatmapColor = NSExpression(
            format: "mgl_interpolate:withCurveType:parameters:stops:($heatmapDensity, 'linear', nil, %@)",
            colorStops as NSDictionary
        )

        let radiusStops: [Double: Double] = [
            3: 20,
            8: 40,
            12: 60
        ]
        layer.heatmapRadius = NSExpression(
            format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
            radiusStops as NSDictionary
        )
        layer.heatmapOpacity = NSExpression(forConstantValue: 0.72)

        style.addLayer(layer)
    }

    func remove(from mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        if let layer = style.layer(withIdentifier: layerId) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceId) {
            style.removeSource(source)
        }
    }
}
