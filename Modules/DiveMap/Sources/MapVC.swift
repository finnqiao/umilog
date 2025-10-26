import UIKit
import MapLibre
import CoreLocation
import os

public struct DiveMapAnnotation: Identifiable {
    public enum Kind: String {
        case site
        case wreck
    }

    public enum Status: String {
        case logged = "Logged"
        case saved = "Saved"
        case planned = "Planned"
        case baseline = "Default"
    }

    public enum Difficulty: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
        case other = "Other"
    }

    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let kind: Kind
    public let status: Status
    public let difficulty: Difficulty
    public let visited: Bool
    public let wishlist: Bool
    public let isSelected: Bool

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        kind: Kind,
        status: Status,
        difficulty: Difficulty,
        visited: Bool,
        wishlist: Bool,
        isSelected: Bool
    ) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        self.status = status
        self.difficulty = difficulty
        self.visited = visited
        self.wishlist = wishlist
        self.isSelected = isSelected
    }
}

extension DiveMapAnnotation: Equatable {
    public static func == (lhs: DiveMapAnnotation, rhs: DiveMapAnnotation) -> Bool {
        lhs.id == rhs.id &&
        lhs.kind == rhs.kind &&
        lhs.status == rhs.status &&
        lhs.difficulty == rhs.difficulty &&
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
    private var didFallbackToOfflineStyle = false
    private lazy var primaryStyleURL: URL? = Bundle.main.url(forResource: "umilog_underwater", withExtension: "json")
    private lazy var offlineStyleURL: URL? = Bundle.main.url(forResource: "dive_offline", withExtension: "json")
    private var hasAttemptedPrimarySwitch = false
    private let vectorTileTemplates = ["https://demotiles.maplibre.org/tiles/tiles/{z}/{x}/{y}.pbf"]

    // Runtime callbacks
    public var onSelectAnnotation: ((String) -> Void)?
    public var onRegionChange: ((DiveMapViewport) -> Void)?
    private var lastSetCamera: DiveMapCamera?
    public var initialCamera: DiveMapCamera? {
        didSet {
            guard let camera = initialCamera, map != nil else { return }
            // Only update if significantly different to avoid loops
            if let last = lastSetCamera, abs(last.center.latitude - camera.center.latitude) < 0.01 && abs(last.zoomLevel - camera.zoomLevel) < 0.5 {
                return
            }
            lastSetCamera = camera
            setCamera(camera, animated: true)
        }
    }

    // Data model
    public var annotations: [DiveMapAnnotation] = [] {
        didSet {
            // Defer update to avoid state mutation during view updates
            DispatchQueue.main.async { [weak self] in
                self?.updateAnnotationsIfReady()
            }
        }
    }

    private var styleIsReady = false
    private var siteSource: MLNShapeSource?
    private var pendingStyleWork: DispatchWorkItem?

    public override func viewDidLoad() {
        super.viewDidLoad()
        logger.log("mapvc_viewdidload")
        
        // Placeholder background while style loads
        fallbackBackground.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 0.96, alpha: 1.0)
        view.addSubview(fallbackBackground)
        let w = view.bounds.size.width
        let h = view.bounds.size.height
        logger.log("mapvc_bounds width=\(w, privacy: .public) height=\(h, privacy: .public)")

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
        
        // Enable gestures for zoom/pan
        map.allowsZooming = true
        map.allowsScrolling = true
        map.allowsRotating = false  // Disable rotation for simplicity
        map.allowsTilting = false
        
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
        attemptSwitchToPrimaryStyleIfNeeded()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fallbackBackground.frame = view.bounds
        map?.frame = view.bounds
    }

    public func setCamera(_ camera: DiveMapCamera, animated: Bool) {
        map.setCenter(camera.center, zoomLevel: camera.zoomLevel, animated: animated)
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

    private var lastEmittedViewport: DiveMapViewport?
    
    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        // Debounce viewport changes to avoid update loops
        let bounds = map.visibleCoordinateBounds
        let viewport = DiveMapViewport(
            minLatitude: bounds.sw.latitude,
            maxLatitude: bounds.ne.latitude,
            minLongitude: bounds.sw.longitude,
            maxLongitude: bounds.ne.longitude
        )
        
        // Only emit if significantly different from last
        if let last = lastEmittedViewport,
           abs(last.minLatitude - viewport.minLatitude) < 0.1,
           abs(last.maxLatitude - viewport.maxLatitude) < 0.1 {
            return
        }
        
        lastEmittedViewport = viewport
        emitViewportChange()
    }

    // MARK: - Gesture Handling

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: map)
        let identifiers: Set<String> = ["site-layer", "site-cluster"]
        let features = map.visibleFeatures(at: point, styleLayerIdentifiers: identifiers)

        guard let feature = features.first else { return }

        if let isCluster = feature.attribute(forKey: "cluster") as? NSNumber, isCluster.boolValue {
            if let count = feature.attribute(forKey: "point_count") as? NSNumber {
                logger.log("cluster_tapped count=\(count.intValue, privacy: .public)")
                UIAccessibility.post(notification: .announcement, argument: "\(count) sites in this cluster")
            }
            zoomIntoCluster(at: point)
            return
        }

        if let id = feature.attribute(forKey: "id") as? String {
            logger.log("feature_selected id=\(id, privacy: .public)")
            
            // Announce selection for VoiceOver accessibility
            let announcement = "Dive site selected"
            UIAccessibility.post(notification: .announcement, argument: announcement)
            
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
        if siteSource == nil, let existingSites = style.source(withIdentifier: "sites") as? MLNShapeSource {
            siteSource = existingSites
        }

        if siteSource == nil {
            let empty = MLNShapeCollectionFeature(shapes: [])
            let sites = MLNShapeSource(identifier: "sites", shape: empty, options: [
                .clustered: true as NSNumber,
                .clusterRadius: 48 as NSNumber,
                .maximumZoomLevelForClustering: 10 as NSNumber
            ])
            style.addSource(sites)
            siteSource = sites
            logger.log("source_added: sites")
        }
    }

    private func ensureOverlayLayers(in style: MLNStyle) {
        guard let siteSource else { return }

        let lagoon = UIColor(brandHex: "#2D7FBF") ?? UIColor(red: 0.18, green: 0.5, blue: 0.75, alpha: 1.0)
        let saved = UIColor(brandHex: "#60A5FA") ?? UIColor(red: 0.38, green: 0.65, blue: 0.98, alpha: 1.0)
        let planned = UIColor(brandHex: "#F59E0B") ?? UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
        let reef = UIColor(brandHex: "#5EEAD4") ?? UIColor(red: 0.37, green: 0.92, blue: 0.83, alpha: 1.0)
        let abyss = UIColor(brandHex: "#0A0F1F") ?? UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0)

        if style.layer(withIdentifier: "site-cluster") == nil {
            let cluster = MLNCircleStyleLayer(identifier: "site-cluster", source: siteSource)
            cluster.predicate = NSPredicate(format: "cluster == YES")
            cluster.circleColor = NSExpression(forConstantValue: lagoon.withAlphaComponent(0.22))
            cluster.circleStrokeColor = NSExpression(forConstantValue: lagoon.withAlphaComponent(0.75))
            cluster.circleStrokeWidth = NSExpression(forConstantValue: 2.0)
            cluster.circleRadius = NSExpression(forConstantValue: 28)
            cluster.isVisible = true
            style.addLayer(cluster)
        }

        if style.layer(withIdentifier: "site-cluster-count") == nil {
            let count = MLNSymbolStyleLayer(identifier: "site-cluster-count", source: siteSource)
            count.predicate = NSPredicate(format: "cluster == YES")
            count.text = NSExpression(format: "CAST(point_count, 'NSString')")
            count.textColor = NSExpression(forConstantValue: UIColor(brandHex: "#E6ECF4") ?? UIColor.white)
            count.textFontSize = NSExpression(forConstantValue: 12)
            count.textFontNames = NSExpression(forConstantValue: ["HelveticaNeue-Bold"])
            count.textAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(count)
        }

        // Status glows
        let glowSpecs: [(String, NSPredicate, UIColor)] = [
            ("site-glow-logged", NSPredicate(format: "cluster != YES AND status == %@", DiveMapAnnotation.Status.logged.rawValue), lagoon.withAlphaComponent(0.28)),
            ("site-glow-saved", NSPredicate(format: "cluster != YES AND status == %@", DiveMapAnnotation.Status.saved.rawValue), saved.withAlphaComponent(0.26)),
            ("site-glow-planned", NSPredicate(format: "cluster != YES AND status == %@", DiveMapAnnotation.Status.planned.rawValue), planned.withAlphaComponent(0.28)),
            ("site-glow-default", NSPredicate(format: "cluster != YES AND (status == %@ OR status == NULL)", DiveMapAnnotation.Status.baseline.rawValue), lagoon.withAlphaComponent(0.22))
        ]

        var insertionReference: MLNStyleLayer? = style.layer(withIdentifier: "site-cluster-count")
        for spec in glowSpecs {
            if style.layer(withIdentifier: spec.0) == nil {
                let glow = MLNCircleStyleLayer(identifier: spec.0, source: siteSource)
                glow.predicate = spec.1
                glow.circleColor = NSExpression(forConstantValue: spec.2)
                glow.circleRadius = NSExpression(forConstantValue: 32)
                glow.circleBlur = NSExpression(forConstantValue: 12)
                glow.circleOpacity = NSExpression(forConstantValue: 1.0)
                if let ref = insertionReference {
                    style.insertLayer(glow, above: ref)
                } else {
                    style.addLayer(glow)
                }
                insertionReference = glow
            }
        }

        // Difficulty fills
        let difficultySpecs: [(String, NSPredicate, UIColor)] = [
            ("site-layer-beginner", NSPredicate(format: "cluster != YES AND difficulty == %@", DiveMapAnnotation.Difficulty.beginner.rawValue), UIColor(brandHex: "#3DDC97") ?? UIColor(red: 0.24, green: 0.86, blue: 0.59, alpha: 1.0)),
            ("site-layer-intermediate", NSPredicate(format: "cluster != YES AND difficulty == %@", DiveMapAnnotation.Difficulty.intermediate.rawValue), saved),
            ("site-layer-advanced", NSPredicate(format: "cluster != YES AND difficulty == %@", DiveMapAnnotation.Difficulty.advanced.rawValue), UIColor(brandHex: "#FBBF24") ?? UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1.0)),
            ("site-layer-expert", NSPredicate(format: "cluster != YES AND difficulty == %@", DiveMapAnnotation.Difficulty.expert.rawValue), UIColor(brandHex: "#EF4444") ?? UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)),
            ("site-layer-default", NSPredicate(format: "cluster != YES AND (difficulty == %@ OR difficulty == NULL)", DiveMapAnnotation.Difficulty.other.rawValue), lagoon)
        ]

        var lastLayer: MLNStyleLayer? = insertionReference
        for spec in difficultySpecs {
            if style.layer(withIdentifier: spec.0) == nil {
                let circle = MLNCircleStyleLayer(identifier: spec.0, source: siteSource)
                circle.predicate = spec.1
                circle.circleColor = NSExpression(forConstantValue: spec.2)
                circle.circleRadius = NSExpression(forConstantValue: 9)
                circle.circleOpacity = NSExpression(forConstantValue: 0.96)
                circle.circleStrokeColor = NSExpression(forConstantValue: abyss)
                circle.circleStrokeWidth = NSExpression(forConstantValue: 1.8)
                if let ref = lastLayer {
                    style.insertLayer(circle, above: ref)
                } else {
                    style.addLayer(circle)
                }
                lastLayer = circle
            }
        }

        if style.layer(withIdentifier: "site-selected") == nil {
            let selected = MLNCircleStyleLayer(identifier: "site-selected", source: siteSource)
            selected.predicate = NSPredicate(format: "selected == 1 && cluster != YES")
            selected.circleColor = NSExpression(forConstantValue: reef.withAlphaComponent(0.85))
            selected.circleRadius = NSExpression(forConstantValue: 14)
            selected.circleOpacity = NSExpression(forConstantValue: 0.9)
            selected.circleStrokeColor = NSExpression(forConstantValue: lagoon)
            selected.circleStrokeWidth = NSExpression(forConstantValue: 2.0)
            if let ref = lastLayer {
                style.insertLayer(selected, above: ref)
            } else {
                style.addLayer(selected)
            }
        }
    }

    private func zoomIntoCluster(at point: CGPoint) {
        let coordinate = map.convert(point, toCoordinateFrom: map)
        let targetZoom = min(map.zoomLevel + 1.5, map.maximumZoomLevel)
        map.setCenter(coordinate, zoomLevel: targetZoom, animated: true)
    }

    private func updateAnnotationsIfReady() {
        guard styleIsReady, let siteSource else {
            logger.log("updateAnnotationsIfReady: NOT READY styleReady=\(self.styleIsReady, privacy: .public) hasSource=\(self.siteSource != nil, privacy: .public)")
            logger.log("  → style layers: \(self.map?.style?.layers.count ?? 0, privacy: .public), sources: \(self.map?.style?.sources.count ?? 0, privacy: .public)")
            return
        }

        logger.log("updateAnnotationsIfReady: updating \(self.annotations.count, privacy: .public) annotations")
        pendingStyleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let features = self.annotations.enumerated().map { index, annotation -> MLNPointFeature in
                let feature = MLNPointFeature()
                feature.coordinate = annotation.coordinate
                feature.attributes = [
                    "id": annotation.id,
                    "kind": annotation.kind.rawValue,
                    "status": annotation.status.rawValue,
                    "difficulty": annotation.difficulty.rawValue,
                    "visited": annotation.visited ? 1 : 0,
                    "wishlist": annotation.wishlist ? 1 : 0,
                    "selected": annotation.isSelected ? 1 : 0,
                    "n": index + 1
                ]
                return feature
            }
            let collection = MLNShapeCollectionFeature(shapes: features)
            siteSource.shape = collection
            logger.log("source_updated: \(features.count, privacy: .public) features in collection")

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
        // The style JSON already has raster tiles configured
        // Just ensure our background is below them
        if style.layer(withIdentifier: "umi-bg") == nil {
            let background = MLNBackgroundStyleLayer(identifier: "umi-bg")
            background.backgroundColor = NSExpression(forConstantValue: UIColor(brandHex: "#0A0F1F") ?? UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0))
            // Insert below all other layers as base
            if let firstLayer = style.layers.first {
                style.insertLayer(background, below: firstLayer)
            } else {
                style.addLayer(background)
            }
            logger.log("layer_added: umi-bg as base layer")
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
