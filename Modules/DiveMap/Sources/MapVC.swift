import UIKit
import MapLibre
import CoreLocation
import os

public struct DiveMapAnnotation: Identifiable {
    public enum Kind: String {
        case site
        case wreck
    }

    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let kind: Kind
    public let visited: Bool
    public let wishlist: Bool
    public let isSelected: Bool

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        kind: Kind,
        visited: Bool,
        wishlist: Bool,
        isSelected: Bool
    ) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        self.visited = visited
        self.wishlist = wishlist
        self.isSelected = isSelected
    }
}

extension DiveMapAnnotation: Equatable {
    public static func == (lhs: DiveMapAnnotation, rhs: DiveMapAnnotation) -> Bool {
        lhs.id == rhs.id &&
        lhs.kind == rhs.kind &&
        lhs.visited == rhs.visited &&
        lhs.wishlist == rhs.wishlist &&
        lhs.isSelected == rhs.isSelected &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

public struct DiveMapViewport: Equatable {
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }
}

public struct DiveMapCamera {
    public let center: CLLocationCoordinate2D
    public let zoomLevel: Double

    public init(center: CLLocationCoordinate2D, zoomLevel: Double) {
        self.center = center
        self.zoomLevel = zoomLevel
    }
}

extension DiveMapCamera: Equatable {
    public static func == (lhs: DiveMapCamera, rhs: DiveMapCamera) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.zoomLevel == rhs.zoomLevel
    }
}

public final class MapVC: UIViewController, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    private var map: MLNMapView!
    private let fallbackBackground = UIView()
    private let logger = Logger(subsystem: "app.umilog", category: "DiveMap")
    private let accentColor = UIColor(brandHex: "#F26A3D") ?? UIColor(red: 0.95, green: 0.42, blue: 0.24, alpha: 1.0)
    private lazy var stopFillColor = accentColor.withAlphaComponent(0.18)
    private var didFallbackToOfflineStyle = false
    private lazy var primaryStyleURL: URL? = Bundle.main.url(forResource: "umilog_min", withExtension: "json")
    private lazy var offlineStyleURL: URL? = Bundle.main.url(forResource: "dive_offline", withExtension: "json")
    private var hasAttemptedPrimarySwitch = false
    private let vectorTileTemplates = ["https://demotiles.maplibre.org/tiles/{z}/{x}/{y}.pbf"]

    // Runtime callbacks
    public var onSelectAnnotation: ((String) -> Void)?
    public var onRegionChange: ((DiveMapViewport) -> Void)?
    public var initialCamera: DiveMapCamera?

    // Data model
    public var annotations: [DiveMapAnnotation] = [] {
        didSet { updateAnnotationsIfReady() }
    }

    private var styleIsReady = false
    private var stopsSource: MLNShapeSource?
    private var routeSource: MLNShapeSource?
    private var pendingStyleWork: DispatchWorkItem?

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Placeholder background while style loads
        fallbackBackground.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 0.96, alpha: 1.0)
        view.addSubview(fallbackBackground)

        guard let initialURL = primaryStyleURL ?? offlineStyleURL else {
            logger.error("style_missing: no style JSONs bundled")
            return
        }

        didFallbackToOfflineStyle = (initialURL == offlineStyleURL)

        map = MLNMapView(frame: view.bounds, styleURL: initialURL)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.backgroundColor = fallbackBackground.backgroundColor
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.automaticallyAdjustsContentInset = false
        map.delegate = self
        view.addSubview(map)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tap.delegate = self
        map.addGestureRecognizer(tap)

        if #available(iOS 11.0, *) {
            // iOS 11+ manages insets via adjustedContentInset; nothing extra needed.
        } else if responds(to: #selector(setter: UIViewController.automaticallyAdjustsScrollViewInsets)) {
            automaticallyAdjustsScrollViewInsets = false
        }

        // Set initial camera (Red Sea region with seeded data)
        let camera = initialCamera ?? DiveMapCamera(
            center: CLLocationCoordinate2D(latitude: 27.78, longitude: 34.32),
            zoomLevel: 4.8
        )
        map.setCenter(camera.center, zoomLevel: camera.zoomLevel, animated: false)
        logger.log("camera_set lat=\(camera.center.latitude, privacy: .public) lon=\(camera.center.longitude, privacy: .public) zoom=\(camera.zoomLevel, privacy: .public)")

        logger.log("style_initial style=\(initialURL.lastPathComponent, privacy: .public) offline=\(self.didFallbackToOfflineStyle, privacy: .public)")
        // Disabled auto-switching to avoid complexity: attemptSwitchToPrimaryStyleIfNeeded()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fallbackBackground.frame = view.bounds
        map?.frame = view.bounds
    }

    // MARK: - Runtime Updates

    public func update(annotations: [DiveMapAnnotation]) {
        self.annotations = annotations
    }

    // MARK: - MLNMapViewDelegate

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        logger.log("style_loaded")
        configureStyle(style)
        styleIsReady = true
        updateAnnotationsIfReady()
        emitViewportChange()
    }

    public func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
        logger.error("style_failed: \(error.localizedDescription, privacy: .public)")
        guard !didFallbackToOfflineStyle, let offlineURL = offlineStyleURL else { return }
        didFallbackToOfflineStyle = true
        hasAttemptedPrimarySwitch = false
        mapView.styleURL = offlineURL
        logger.log("style_fallback_offline")
        attemptSwitchToPrimaryStyleIfNeeded()
    }

    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        emitViewportChange()
    }

    // MARK: - Gesture Handling

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: map)
        let identifiers: Set<String> = ["stop-num", "stop-circle"]
        let features = map.visibleFeatures(at: point, styleLayerIdentifiers: identifiers)

        guard let feature = features.first else { return }

        if let id = feature.attribute(forKey: "id") as? String {
            logger.log("feature_selected id=\(id, privacy: .public)")
            if let onSelectAnnotation {
                DispatchQueue.main.async {
                    onSelectAnnotation(id)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func configureStyle(_ style: MLNStyle) {
        ensureBaseLayers(in: style)
        ensureDataSources(in: style)
        ensureOverlayLayers(in: style)
    }

    private func ensureDataSources(in style: MLNStyle) {
        if stopsSource == nil, let existingStops = style.source(withIdentifier: "stops") as? MLNShapeSource {
            stopsSource = existingStops
        }
        if routeSource == nil, let existingRoute = style.source(withIdentifier: "route") as? MLNShapeSource {
            routeSource = existingRoute
        }

        if stopsSource == nil {
            let empty = MLNShapeCollectionFeature(shapes: [])
            let stops = MLNShapeSource(identifier: "stops", shape: empty, options: nil)
            style.addSource(stops)
            stopsSource = stops
            logger.log("source_added: stops")
        }

        if routeSource == nil {
            let empty = MLNShapeCollectionFeature(shapes: [])
            let route = MLNShapeSource(identifier: "route", shape: empty, options: nil)
            style.addSource(route)
            routeSource = route
            logger.log("source_added: route")
        }
    }

    private func ensureOverlayLayers(in style: MLNStyle) {
        if style.layer(withIdentifier: "route-line") == nil, let routeSource {
            let line = MLNLineStyleLayer(identifier: "route-line", source: routeSource)
            line.lineColor = NSExpression(forConstantValue: accentColor)
            line.lineWidth = NSExpression(forConstantValue: 3.0)
            line.lineJoin = NSExpression(forConstantValue: "round")
            line.lineCap = NSExpression(forConstantValue: "round")
            style.addLayer(line)
        }

        if style.layer(withIdentifier: "stop-circle") == nil, let stopsSource {
            let circle = MLNCircleStyleLayer(identifier: "stop-circle", source: stopsSource)
            circle.circleColor = NSExpression(forConstantValue: stopFillColor)
            circle.circleStrokeColor = NSExpression(forConstantValue: accentColor)
            circle.circleStrokeWidth = NSExpression(forConstantValue: 1.0)
            circle.circleRadius = NSExpression(forConstantValue: 16)
            style.addLayer(circle)
        }

        if style.layer(withIdentifier: "stop-num") == nil, let stopsSource {
            let num = MLNSymbolStyleLayer(identifier: "stop-num", source: stopsSource)
            num.text = NSExpression(format: "CAST(n, 'NSString')")
            num.textColor = NSExpression(forConstantValue: UIColor.white)
            num.textFontSize = NSExpression(forConstantValue: 12)
            num.textHaloColor = NSExpression(forConstantValue: accentColor)
            num.textHaloWidth = NSExpression(forConstantValue: 1.0)
            num.textAllowsOverlap = NSExpression(forConstantValue: true)
            num.textFontNames = NSExpression(forConstantValue: ["HelveticaNeue-Bold"])
            style.addLayer(num)
        }
    }

    private func updateAnnotationsIfReady() {
        guard styleIsReady, let stopsSource else { return }

        pendingStyleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let features = self.annotations.enumerated().map { index, annotation -> MLNPointFeature in
                let feature = MLNPointFeature()
                feature.coordinate = annotation.coordinate
                feature.attributes = [
                    "id": annotation.id,
                    "kind": annotation.kind.rawValue,
                    "visited": annotation.visited ? 1 : 0,
                    "wishlist": annotation.wishlist ? 1 : 0,
                    "selected": annotation.isSelected ? 1 : 0,
                    "n": index + 1
                ]
                return feature
            }
            let collection = MLNShapeCollectionFeature(shapes: features)
            stopsSource.shape = collection

            if let routeSource {
                if self.annotations.count >= 2 {
                    var coordinates = self.annotations.map { $0.coordinate }
                    let polyline = MLNPolylineFeature(coordinates: &coordinates, count: UInt(coordinates.count))
                    routeSource.shape = polyline
                } else {
                    routeSource.shape = nil
                }
            }

            self.logger.log("annotations_applied count=\(self.annotations.count, privacy: .public)")
            if let first = self.annotations.first {
                self.logger.log("annotations_first id=\(first.id, privacy: .public) lat=\(first.coordinate.latitude, privacy: .public) lon=\(first.coordinate.longitude, privacy: .public)")
            }
        }
        pendingStyleWork = work
        DispatchQueue.main.async(execute: work)
    }

    private func emitViewportChange() {
        guard let onRegionChange else { return }
        let bounds = map.visibleCoordinateBounds
        let viewport = DiveMapViewport(
            minLatitude: bounds.sw.latitude,
            maxLatitude: bounds.ne.latitude,
            minLongitude: bounds.sw.longitude,
            maxLongitude: bounds.ne.longitude
        )
        DispatchQueue.main.async {
            onRegionChange(viewport)
        }
    }

    // MARK: - Minimal Base & Overlays

    private func ensureBaseLayers(in style: MLNStyle) {
        // Style JSON already defines all base layers (bg, water, roads, admin, place, poi)
        // Just verify the source exists
        if style.source(withIdentifier: "openmap") != nil {
            logger.log("base_layers_verified: openmap source found")
        } else {
            logger.warning("base_layers_missing: openmap source not found in style")
        }
    }

    private func attemptSwitchToPrimaryStyleIfNeeded() {
        guard didFallbackToOfflineStyle, let primaryURL = primaryStyleURL else { return }
        guard !hasAttemptedPrimarySwitch else { return }
        hasAttemptedPrimarySwitch = true
        guard let template = vectorTileTemplates.first else { return }

        let sampleURLString = template
            .replacingOccurrences(of: "{z}", with: "3")
            .replacingOccurrences(of: "{x}", with: "4")
            .replacingOccurrences(of: "{y}", with: "2")

        guard let sampleURL = URL(string: sampleURLString) else {
            logger.error("style_primary_unreachable: invalid sample URL")
            return
        }

        var request = URLRequest(url: sampleURL)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }

            if let error = error {
                self.logger.error("style_primary_unreachable: \(error.localizedDescription, privacy: .public)")
                self.schedulePrimaryRetry()
                return
            }

            guard let http = response as? HTTPURLResponse else {
                self.logger.error("style_primary_unreachable: missing HTTP response")
                self.schedulePrimaryRetry()
                return
            }

            guard (200..<400).contains(http.statusCode) else {
                self.logger.error("style_primary_unreachable_status=\(http.statusCode, privacy: .public)")
                self.schedulePrimaryRetry()
                return
            }

            DispatchQueue.main.async {
                guard self.didFallbackToOfflineStyle else { return }
                self.didFallbackToOfflineStyle = false
                self.hasAttemptedPrimarySwitch = false
                self.map.styleURL = primaryURL
                self.logger.log("style_switch_primary")
            }
        }.resume()
    }

    private func schedulePrimaryRetry(after delay: TimeInterval = 12) {
        guard didFallbackToOfflineStyle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.didFallbackToOfflineStyle else { return }
            self.hasAttemptedPrimarySwitch = false
            self.attemptSwitchToPrimaryStyleIfNeeded()
        }
    }
}

private extension UIColor {
    convenience init?(brandHex: String) {
        let hex = brandHex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = Int(hex, radix: 16) else {
            return nil
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
