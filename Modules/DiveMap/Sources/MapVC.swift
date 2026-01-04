import UIKit
import MapLibre
import CoreLocation
import os
import UmiDesignSystem

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

    public enum SiteType: String {
        case reef = "reef"
        case wreck = "wreck"
        case wall = "wall"
        case cave = "cave"
        case shore = "shore"
        case drift = "drift"
        case generic = "generic"
    }

    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let kind: Kind
    public let status: Status
    public let difficulty: Difficulty
    public let siteType: SiteType
    public let visited: Bool
    public let wishlist: Bool
    public let isSelected: Bool

    public init(
        id: String,
        coordinate: CLLocationCoordinate2D,
        kind: Kind,
        status: Status,
        difficulty: Difficulty,
        siteType: SiteType = .generic,
        visited: Bool,
        wishlist: Bool,
        isSelected: Bool
    ) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        self.status = status
        self.difficulty = difficulty
        self.siteType = siteType
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
        lhs.siteType == rhs.siteType &&
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

/// Map style mode for switching between dark (underwater) and light (daylight) themes.
public enum MapStyleMode: String {
    case underwater  // Dark theme, default
    case daylight    // High-contrast light theme for outdoor visibility
}

public final class MapVC: UIViewController, MLNMapViewDelegate, UIGestureRecognizerDelegate {
    private var map: MLNMapView!
    private let fallbackBackground = UIView()
    private let logger = Logger(subsystem: "app.umilog", category: "DiveMap")
    private var didFallbackToOfflineStyle = false
    // NOTE: MapLibre has rendering issues on iOS 18 simulator. Using MapKit instead.
    // These style URLs are kept for future use when MapLibre is fixed.
    private lazy var primaryStyleURL: URL? = Bundle.main.url(forResource: "umilog_underwater", withExtension: "json")
    private lazy var daylightStyleURL: URL? = Bundle.main.url(forResource: "umilog_daylight", withExtension: "json")
    private lazy var offlineStyleURL: URL? = Bundle.main.url(forResource: "dive_offline", withExtension: "json")
    private var hasAttemptedPrimarySwitch = false
    private let vectorTileTemplates = ["https://demotiles.maplibre.org/tiles/tiles/{z}/{x}/{y}.pbf"]

    /// Current map style mode (underwater or daylight).
    public var styleMode: MapStyleMode = .underwater {
        didSet {
            guard oldValue != styleMode, map != nil else { return }
            switchToStyle(for: styleMode)
        }
    }

    // Runtime callbacks
    public var onSelectAnnotation: ((String) -> Void)?
    public var onRegionChange: ((DiveMapViewport) -> Void)?
    private var lastSetCamera: DiveMapCamera?
    public var initialCamera: DiveMapCamera? {
        didSet {
            guard let camera = initialCamera, map != nil else { return }
            // Reduced threshold for responsive zoom control updates
            if let last = lastSetCamera,
               abs(last.center.latitude - camera.center.latitude) < 0.001 &&
               abs(last.center.longitude - camera.center.longitude) < 0.001 &&
               abs(last.zoomLevel - camera.zoomLevel) < 0.1 {
                return
            }
            lastSetCamera = camera
            setCamera(camera, animated: true)
            logger.log("camera_updated lat=\(camera.center.latitude, privacy: .public) lon=\(camera.center.longitude, privacy: .public) zoom=\(camera.zoomLevel, privacy: .public)")
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
    public var layerSettings: DiveMapLayerSettings = .default {
        didSet {
            guard oldValue != layerSettings else { return }
            applyLayerSettings()
        }
    }

    private var styleIsReady = false
    private var siteSource: MLNShapeSource?
    private var pendingStyleWork: DispatchWorkItem?

    public override func viewDidLoad() {
        super.viewDidLoad()
        logger.log("mapvc_viewdidload")
        
        // Placeholder background while style loads - ocean blue to match underwater theme
        fallbackBackground.backgroundColor = UIColor(red: 0.04, green: 0.14, blue: 0.26, alpha: 1.0)
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
        map.isOpaque = true
        map.layer.isOpaque = true
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.automaticallyAdjustsContentInset = false
        map.delegate = self
        logger.log("map_created: frame=\(self.view.bounds.width, privacy: .public)x\(self.view.bounds.height, privacy: .public) opaque=\(self.map.isOpaque, privacy: .public)")
        
        // Enable gestures for zoom/pan
        map.allowsZooming = true
        map.allowsScrolling = true
        map.allowsRotating = true
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

        // Set initial camera - default to Phuket (smart camera will reposition based on data)
        let camera = initialCamera ?? DiveMapCamera(
            center: CLLocationCoordinate2D(latitude: 8.0, longitude: 98.3),
            zoomLevel: 8.0
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
        let mlnCamera = MLNMapCamera(
            lookingAtCenter: camera.center,
            altitude: altitudeForZoom(camera.zoomLevel),
            pitch: 0,
            heading: map.camera.heading
        )
        if animated {
            map.fly(to: mlnCamera, withDuration: 0.4, completionHandler: nil)
        } else {
            map.setCamera(mlnCamera, animated: false)
        }
    }

    private func altitudeForZoom(_ zoom: Double) -> CLLocationDistance {
        // Approximate altitude calculation for MapLibre zoom levels
        return 40_000_000 / pow(2, zoom)
    }

    // MARK: - Runtime Updates

    public func update(annotations: [DiveMapAnnotation]) {
        self.annotations = annotations
    }

    // MARK: - MLNMapViewDelegate

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        logger.log("style_loaded: name=\(style.name ?? "unknown", privacy: .public) layers=\(style.layers.count, privacy: .public) sources=\(style.sources.count, privacy: .public)")
        configureStyle(style)
        styleIsReady = true
        updateAnnotationsIfReady()
        applyLayerSettings()
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
        // Look for taps on any site layers (by difficulty) and clusters
        let identifiers: Set<String> = [
            "site-layer-beginner",
            "site-layer-intermediate",
            "site-layer-advanced",
            "site-layer-expert",
            "site-layer-default",
            "site-selected",
            "site-cluster"
        ]
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

    private func switchToStyle(for mode: MapStyleMode) {
        let styleURL: URL?
        switch mode {
        case .underwater:
            styleURL = primaryStyleURL
            fallbackBackground.backgroundColor = UIColor(red: 0.04, green: 0.14, blue: 0.26, alpha: 1.0)
        case .daylight:
            styleURL = daylightStyleURL
            fallbackBackground.backgroundColor = UIColor(red: 0.84, green: 0.92, blue: 0.97, alpha: 1.0)
        }

        guard let url = styleURL else {
            logger.error("style_switch_failed: missing style for \(mode.rawValue, privacy: .public)")
            return
        }

        styleIsReady = false
        map.styleURL = url
        map.backgroundColor = fallbackBackground.backgroundColor
        logger.log("style_switch mode=\(mode.rawValue, privacy: .public)")
    }

    private func configureStyle(_ style: MLNStyle) {
        logger.log("configureStyle: starting with layers=\(style.layers.count, privacy: .public) sources=\(style.sources.count, privacy: .public)")

        registerIcons(in: style)
        ensureBaseLayers(in: style)
        ensureDataSources(in: style)
        ensureOverlayLayers(in: style)

        logger.log("configureStyle: complete with layers=\(style.layers.count, privacy: .public) sources=\(style.sources.count, privacy: .public)")
    }

    private func registerIcons(in style: MLNStyle) {
        let renderer = MapIconRenderer()
        let icons = renderer.prerenderAllIcons()
        for (name, image) in icons {
            style.setImage(image, forName: name)
        }
        logger.log("icons_registered: \(icons.count, privacy: .public) icons")
    }

    private func ensureDataSources(in style: MLNStyle) {
        if siteSource == nil, let existingSites = style.source(withIdentifier: "sites") as? MLNShapeSource {
            siteSource = existingSites
            logger.log("source_reused: sites source already exists")
        }

        if siteSource == nil {
            let empty = MLNShapeCollectionFeature(shapes: [])
            // TEMPORARILY disable clustering to debug rendering
            let sites = MLNShapeSource(identifier: "sites", shape: empty, options: nil)
            style.addSource(sites)
            siteSource = sites
            logger.log("source_added: sites WITHOUT clustering (debugging)")
        }
    }

    private func ensureOverlayLayers(in style: MLNStyle) {
        guard let siteSource else { return }

        // CUSTOMIZE: All colors come from MapTheme.Colors - edit there to change appearance
        let clusterFill = MapTheme.Colors.clusterFill
        let clusterStroke = MapTheme.Colors.clusterStroke
        let clusterText = MapTheme.Colors.clusterText
        let stroke = MapTheme.Colors.stroke

        // MARK: - Cluster Layer
        if style.layer(withIdentifier: "site-cluster") == nil {
            let cluster = MLNCircleStyleLayer(identifier: "site-cluster", source: siteSource)
            cluster.predicate = NSPredicate(format: "cluster == YES")

            // Solid fill color for clusters (like reference image - red circles)
            cluster.circleColor = NSExpression(forConstantValue: clusterFill.withAlphaComponent(0.9))
            cluster.circleStrokeColor = NSExpression(forConstantValue: clusterStroke.withAlphaComponent(0.95))
            cluster.circleStrokeWidth = NSExpression(forConstantValue: MapTheme.Sizing.clusterStrokeWidth)

            // Static cluster radius - iOS 18+ blocks mgl_interpolate NSExpression functions
            cluster.circleRadius = NSExpression(forConstantValue: 24)
            cluster.isVisible = true
            style.addLayer(cluster)
        }

        // MARK: - Cluster Count Label
        if style.layer(withIdentifier: "site-cluster-count") == nil {
            let count = MLNSymbolStyleLayer(identifier: "site-cluster-count", source: siteSource)
            count.predicate = NSPredicate(format: "cluster == YES")
            count.text = NSExpression(format: "CAST(point_count, 'NSString')")
            count.textColor = NSExpression(forConstantValue: clusterText)
            // CUSTOMIZE: Font settings from MapTheme.Typography
            count.textFontSize = NSExpression(forConstantValue: MapTheme.Typography.clusterFontSize)
            count.textFontNames = NSExpression(forConstantValue: [MapTheme.Typography.clusterFont])
            count.textAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(count)
        }

        // MARK: - Status Glows
        // CUSTOMIZE: Status glow colors from MapTheme.Colors
        // NOTE: Use "cluster != TRUE OR cluster == NIL" to handle features without cluster attribute
        let glowSpecs: [(String, NSPredicate, UIColor)] = [
            ("site-glow-logged", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND status == %@", DiveMapAnnotation.Status.logged.rawValue), MapTheme.Colors.logged.withAlphaComponent(0.28)),
            ("site-glow-saved", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND status == %@", DiveMapAnnotation.Status.saved.rawValue), MapTheme.Colors.saved.withAlphaComponent(0.26)),
            ("site-glow-planned", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND status == %@", DiveMapAnnotation.Status.planned.rawValue), MapTheme.Colors.planned.withAlphaComponent(0.28)),
            ("site-glow-default", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND (status == %@ OR status == NIL)", DiveMapAnnotation.Status.baseline.rawValue), MapTheme.Colors.defaultGlow)
        ]

        // Static glow radius - iOS 18+ blocks mgl_interpolate NSExpression functions
        let glowRadiusExpression = NSExpression(forConstantValue: 16)

        var insertionReference: MLNStyleLayer? = style.layer(withIdentifier: "site-cluster-count")
        for spec in glowSpecs {
            if style.layer(withIdentifier: spec.0) == nil {
                let glow = MLNCircleStyleLayer(identifier: spec.0, source: siteSource)
                glow.predicate = spec.1
                glow.circleColor = NSExpression(forConstantValue: spec.2)
                // Data-driven glow radius that scales with zoom
                glow.circleRadius = glowRadiusExpression
                glow.circleBlur = NSExpression(forConstantValue: MapTheme.Sizing.glowBlur * 15)
                glow.circleOpacity = NSExpression(forConstantValue: 1.0)
                if let ref = insertionReference {
                    style.insertLayer(glow, above: ref)
                } else {
                    style.addLayer(glow)
                }
                insertionReference = glow
            }
        }

        // MARK: - Difficulty Markers
        // CUSTOMIZE: Difficulty colors from MapTheme.Colors
        // NOTE: Use "cluster != TRUE OR cluster == NIL" to handle features without cluster attribute
        let difficultySpecs: [(String, NSPredicate, UIColor)] = [
            ("site-layer-beginner", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND difficulty == %@", DiveMapAnnotation.Difficulty.beginner.rawValue), MapTheme.Colors.beginner),
            ("site-layer-intermediate", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND difficulty == %@", DiveMapAnnotation.Difficulty.intermediate.rawValue), MapTheme.Colors.intermediate),
            ("site-layer-advanced", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND difficulty == %@", DiveMapAnnotation.Difficulty.advanced.rawValue), MapTheme.Colors.advanced),
            ("site-layer-expert", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND difficulty == %@", DiveMapAnnotation.Difficulty.expert.rawValue), MapTheme.Colors.expert),
            ("site-layer-default", NSPredicate(format: "(cluster != TRUE OR cluster == NIL) AND (difficulty == %@ OR difficulty == NIL)", DiveMapAnnotation.Difficulty.other.rawValue), MapTheme.Colors.default)
        ]

        // Static marker radius - iOS 18+ blocks mgl_interpolate NSExpression functions
        let markerRadiusExpression = NSExpression(forConstantValue: 8)

        var lastLayer: MLNStyleLayer? = insertionReference
        for spec in difficultySpecs {
            if style.layer(withIdentifier: spec.0) == nil {
                let circle = MLNCircleStyleLayer(identifier: spec.0, source: siteSource)
                circle.predicate = spec.1
                circle.circleColor = NSExpression(forConstantValue: spec.2)
                // Data-driven marker radius that grows with zoom level
                circle.circleRadius = markerRadiusExpression
                circle.circleOpacity = NSExpression(forConstantValue: 0.96)
                circle.circleStrokeColor = NSExpression(forConstantValue: stroke)
                circle.circleStrokeWidth = NSExpression(forConstantValue: MapTheme.Sizing.markerStrokeWidth)
                if let ref = lastLayer {
                    style.insertLayer(circle, above: ref)
                } else {
                    style.addLayer(circle)
                }
                lastLayer = circle
            }
        }

        // MARK: - Selection Highlight
        // Static selection radius - iOS 18+ blocks mgl_interpolate NSExpression functions
        let selectionRadiusExpression = NSExpression(forConstantValue: 12)

        if style.layer(withIdentifier: "site-selected") == nil {
            let selected = MLNCircleStyleLayer(identifier: "site-selected", source: siteSource)
            selected.predicate = NSPredicate(format: "selected == 1 && cluster != YES")
            selected.circleColor = NSExpression(forConstantValue: MapTheme.Colors.selectionRing.withAlphaComponent(0.85))
            selected.circleRadius = selectionRadiusExpression
            selected.circleOpacity = NSExpression(forConstantValue: 0.9)
            selected.circleStrokeColor = NSExpression(forConstantValue: clusterFill)
            selected.circleStrokeWidth = NSExpression(forConstantValue: MapTheme.Sizing.selectionStrokeWidth)
            if let ref = lastLayer {
                style.insertLayer(selected, above: ref)
            } else {
                style.addLayer(selected)
            }
        }
    }

    private func applyLayerSettings() {
        guard styleIsReady, let style = map?.style else {
            return
        }

        let updateLayers = { [layerSettings] in
            // Toggle cluster visibility
            let clusterIds = ["site-cluster", "site-cluster-count"]
            for id in clusterIds {
                if let layer = style.layer(withIdentifier: id) as? MLNStyleLayer {
                    layer.isVisible = layerSettings.showClusters
                }
            }

            // Toggle glow visibility
            let glowIds = [
                "site-glow-logged",
                "site-glow-saved",
                "site-glow-planned",
                "site-glow-default"
            ]
            for id in glowIds {
                if let layer = style.layer(withIdentifier: id) as? MLNStyleLayer {
                    layer.isVisible = layerSettings.showStatusGlows
                }
            }

            // CUSTOMIZE: All difficulty colors from MapTheme.Colors
            let defaultColor = MapTheme.Colors.default
            let difficultyLayers: [(String, UIColor)] = [
                ("site-layer-beginner", MapTheme.Colors.beginner),
                ("site-layer-intermediate", MapTheme.Colors.intermediate),
                ("site-layer-advanced", MapTheme.Colors.advanced),
                ("site-layer-expert", MapTheme.Colors.expert),
                ("site-layer-default", defaultColor)
            ]

            for (id, color) in difficultyLayers {
                guard let layer = style.layer(withIdentifier: id) as? MLNCircleStyleLayer else { continue }
                let target = layerSettings.colorByDifficulty ? color : defaultColor
                layer.circleColor = NSExpression(forConstantValue: target)
            }
        }

        if Thread.isMainThread {
            updateLayers()
        } else {
            DispatchQueue.main.async(execute: updateLayers)
        }
    }

    private func zoomIntoCluster(at point: CGPoint) {
        let coordinate = map.convert(point, toCoordinateFrom: map)

        // Adaptive zoom: jump more at low zoom, less at high zoom for smooth drilling
        let currentZoom = map.zoomLevel
        let zoomIncrement: Double
        if currentZoom < 5 {
            zoomIncrement = 3.0  // Big jump at world/continent level
        } else if currentZoom < 8 {
            zoomIncrement = 2.5  // Medium jump at country level
        } else {
            zoomIncrement = 2.0  // Smaller jump at regional level
        }

        let targetZoom = min(currentZoom + zoomIncrement, MapTheme.Clustering.maxClusterZoom + 1)

        let mlnCamera = MLNMapCamera(
            lookingAtCenter: coordinate,
            altitude: altitudeForZoom(targetZoom),
            pitch: 0,
            heading: map.camera.heading
        )

        // Smooth animation with spring feel
        map.fly(to: mlnCamera, withDuration: 0.4, completionHandler: nil)

        // Haptic feedback for cluster expansion
        if MapTheme.Animation.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: MapTheme.Animation.clusterHapticStyle)
            generator.impactOccurred()
        }
    }

    private func updateAnnotationsIfReady() {
        guard styleIsReady, let siteSource else {
            logger.log("updateAnnotationsIfReady: NOT READY styleReady=\(self.styleIsReady, privacy: .public) hasSource=\(self.siteSource != nil, privacy: .public)")
            logger.log("  → style layers: \(self.map?.style?.layers.count ?? 0, privacy: .public), sources: \(self.map?.style?.sources.count ?? 0, privacy: .public)")
            return
        }

        logger.log("updateAnnotationsIfReady: updating \(self.annotations.count, privacy: .public) annotations")

        // DEBUG: Log difficulty distribution
        var diffCounts: [String: Int] = [:]
        for a in annotations.prefix(1000) {
            diffCounts[a.difficulty.rawValue, default: 0] += 1
        }
        for (diff, count) in diffCounts {
            logger.log("  difficulty '\(diff, privacy: .public)': \(count, privacy: .public) annotations")
        }
        if let first = annotations.first {
            logger.log("  first annotation: id=\(first.id, privacy: .public) lat=\(first.coordinate.latitude, privacy: .public) lon=\(first.coordinate.longitude, privacy: .public) difficulty=\(first.difficulty.rawValue, privacy: .public)")
        }
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
                    "siteType": annotation.siteType.rawValue,
                    "visited": annotation.visited ? 1 : 0,
                    "wishlist": annotation.wishlist ? 1 : 0,
                    "selected": annotation.isSelected ? 1 : 0,
                    "n": index + 1
                ]
                return feature
            }
            // IMPORTANT: Setting .shape doesn't update layers for clustered sources
            // We need to recreate the source with features in the constructor
            if let style = self.map.style {
                // Remove old layers that use this source
                let layersToRemove = [
                    "site-cluster", "site-cluster-count",
                    "site-glow-logged", "site-glow-saved", "site-glow-planned", "site-glow-default",
                    "site-layer-beginner", "site-layer-intermediate", "site-layer-advanced",
                    "site-layer-expert", "site-layer-default", "site-selected"
                ]
                for layerId in layersToRemove {
                    if let layer = style.layer(withIdentifier: layerId) {
                        style.removeLayer(layer)
                    }
                }

                // Remove old source
                if let oldSource = style.source(withIdentifier: "sites") {
                    style.removeSource(oldSource)
                }

                // Create new source with features (not setting .shape later)
                let newSource = MLNShapeSource(identifier: "sites", features: features, options: nil)
                style.addSource(newSource)
                self.siteSource = newSource

                // Re-add the overlay layers
                self.ensureOverlayLayers(in: style)

                self.logger.log("source_recreated: \(features.count, privacy: .public) features")
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
        // The style JSON already has raster tiles configured
        // Just ensure our background is below them
        if style.layer(withIdentifier: "umi-bg") == nil {
            let background = MLNBackgroundStyleLayer(identifier: "umi-bg")
            // CUSTOMIZE: Background color from MapTheme.Colors
            background.backgroundColor = NSExpression(forConstantValue: MapTheme.Colors.background)
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

// Note: Removed UIColor(brandHex:) extension - now using MapTheme colors from UmiDesignSystem
