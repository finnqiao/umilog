import Foundation
import MapLibre
import CoreLocation
import os

private let logger = Logger(subsystem: "app.umilog", category: "ConditionsLayer")

/// Manages a MapLibre layer that visualizes recent dive conditions at sites.
/// Sites are colored by visibility quality with freshness-based opacity.
public final class ConditionsLayerManager {
    private let sourceId = "conditions-source"
    private let layerId = "conditions-layer"
    private let labelLayerId = "conditions-label-layer"

    /// Data point for a single site's conditions overlay.
    public struct ConditionsPoint {
        public let siteId: String
        public let latitude: Double
        public let longitude: Double
        public let visibility: Double?       // meters
        public let temperature: Double?      // celsius
        public let currentStrength: Int      // 0=none, 1=light, 2=moderate, 3=strong
        public let freshnessHours: Double    // hours since last report
        public let reportCount: Int

        public init(
            siteId: String,
            latitude: Double,
            longitude: Double,
            visibility: Double?,
            temperature: Double?,
            currentStrength: Int,
            freshnessHours: Double,
            reportCount: Int
        ) {
            self.siteId = siteId
            self.latitude = latitude
            self.longitude = longitude
            self.visibility = visibility
            self.temperature = temperature
            self.currentStrength = currentStrength
            self.freshnessHours = freshnessHours
            self.reportCount = reportCount
        }
    }

    /// Add or update the conditions overlay layer.
    public func update(points: [ConditionsPoint], on mapView: MLNMapView) {
        remove(from: mapView)
        guard !points.isEmpty, let style = mapView.style else { return }

        let features = points.map { point -> MLNPointFeature in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            feature.attributes = [
                "siteId": point.siteId,
                "visibility": point.visibility ?? -1,
                "temperature": point.temperature ?? -1,
                "currentStrength": point.currentStrength,
                "freshnessHours": point.freshnessHours,
                "reportCount": point.reportCount
            ]
            return feature
        }

        let source = MLNShapeSource(identifier: sourceId, features: features, options: nil)
        style.addSource(source)

        // Circle layer colored by visibility quality
        let circle = MLNCircleStyleLayer(identifier: layerId, source: source)
        circle.circleRadius = NSExpression(forConstantValue: 12)
        circle.circleOpacity = NSExpression(forConstantValue: 0.7)
        circle.circleStrokeWidth = NSExpression(forConstantValue: 1.5)
        circle.circleStrokeColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.6))

        // Color by visibility: green (>20m) → yellow (10-20m) → red (<10m)
        // Sites without visibility data show as gray
        if #available(iOS 18, *) {
            circle.circleColor = NSExpression(forConstantValue: UIColor(red: 0.12, green: 0.77, blue: 0.71, alpha: 1))
        } else {
            let stops: NSDictionary = [
                -1: NSExpression(forConstantValue: UIColor.gray),
                 0: NSExpression(forConstantValue: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)),
                 5: NSExpression(forConstantValue: UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1)),
                10: NSExpression(forConstantValue: UIColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)),
                20: NSExpression(forConstantValue: UIColor(red: 0.4, green: 0.8, blue: 0.3, alpha: 1)),
                30: NSExpression(forConstantValue: UIColor(red: 0.12, green: 0.77, blue: 0.71, alpha: 1))
            ]
            circle.circleColor = NSExpression(
                format: "mgl_interpolate:withCurveType:parameters:stops:(visibility, 'linear', nil, %@)", stops
            )
        }

        // Insert below site layers so conditions don't obscure pins
        if let siteLayer = style.layer(withIdentifier: "site-glow-default") {
            style.insertLayer(circle, below: siteLayer)
        } else {
            style.addLayer(circle)
        }

        logger.info("conditions_layer_updated: \(points.count, privacy: .public) points")
    }

    /// Remove the conditions overlay.
    public func remove(from mapView: MLNMapView) {
        guard let style = mapView.style else { return }
        if let layer = style.layer(withIdentifier: layerId) {
            style.removeLayer(layer)
        }
        if let layer = style.layer(withIdentifier: labelLayerId) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceId) {
            style.removeSource(source)
        }
    }
}
