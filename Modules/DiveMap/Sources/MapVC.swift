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
    public let zoomLevel: Double

    public init(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double,
        zoomLevel: Double
    ) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
        self.zoomLevel = zoomLevel
    }
}

public struct DiveMapCamera {
    public let center: CLLocationCoordinate2D
    public let zoomLevel: Double
    public let pitch: Double
    public let bearing: Double

    public init(
        center: CLLocationCoordinate2D,
        zoomLevel: Double,
        pitch: Double = 0,
        bearing: Double = 0
    ) {
        self.center = center
        self.zoomLevel = zoomLevel
        self.pitch = pitch
        self.bearing = bearing
    }
}

extension DiveMapCamera: Equatable {
    public static func == (lhs: DiveMapCamera, rhs: DiveMapCamera) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.zoomLevel == rhs.zoomLevel &&
        lhs.pitch == rhs.pitch &&
        lhs.bearing == rhs.bearing
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

    /// Accessibility elements for VoiceOver rotor navigation
    private var accessibilityAnnotationElements: [MapPinAccessibilityElement] = []
    // NOTE: MapLibre works on iOS 17. iOS 18+ has NSExpression validation issues
    // that block mgl_interpolate. Zoom-responsive helpers fall back to static values on iOS 18+.
    // Style priority: vector (online) > PMTiles (offline) > raster (legacy fallback)
    private lazy var vectorStyleURL: URL? = Bundle.main.url(forResource: "umilog_underwater_vector", withExtension: "json")
    private lazy var pmtilesStyleURL: URL? = Bundle.main.url(forResource: "umilog_offline", withExtension: "json")
    private lazy var rasterStyleURL: URL? = Bundle.main.url(forResource: "umilog_underwater", withExtension: "json")
    private lazy var primaryStyleURL: URL? = vectorStyleURL ?? rasterStyleURL
    private lazy var daylightStyleURL: URL? = Bundle.main.url(forResource: "umilog_daylight", withExtension: "json")
    private lazy var offlineStyleURL: URL? = pmtilesStyleURL ?? Bundle.main.url(forResource: "dive_offline", withExtension: "json")
    private var hasAttemptedPrimarySwitch = false
    private let vectorTileTemplates = ["https://api.protomaps.com/tiles/v4/{z}/{x}/{y}.mvt"]

    /// Path to bundled PMTiles file for offline use. Set this to enable offline maps.
    /// When set, MapLibre will resolve pmtiles:// URLs to this file.
    public var offlineTilesPath: URL? {
        didSet {
            if let path = offlineTilesPath {
                logger.log("offline_tiles_configured: \(path.lastPathComponent, privacy: .public)")
            }
        }
    }

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
    public var onLoadFailure: (() -> Void)?
    /// Called when a cluster is tapped. Passes the cluster center and count for site stack display.
    public var onClusterTap: ((CLLocationCoordinate2D, Int) -> Void)?
    private var lastSetCamera: DiveMapCamera?
    public var initialCamera: DiveMapCamera? {
        didSet {
            guard let camera = initialCamera, map != nil else { return }
            // Reduced threshold for responsive zoom control updates
            if let last = lastSetCamera,
               abs(last.center.latitude - camera.center.latitude) < 0.001 &&
               abs(last.center.longitude - camera.center.longitude) < 0.001 &&
               abs(last.zoomLevel - camera.zoomLevel) < 0.1 &&
               abs(last.pitch - camera.pitch) < 0.5 &&
               abs(last.bearing - camera.bearing) < 0.5 {
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
    private let heatmapLayerManager = HeatmapLayerManager()
    private let terrainLayerManager = TerrainLayerManager()

    public var heatmapPoints: [DiveMapHeatmapPoint] = [] {
        didSet {
            updateHeatmapLayerIfNeeded()
        }
    }

    public var showHeatmap: Bool = false {
        didSet {
            applyLayerSettings()
            updateHeatmapLayerIfNeeded()
        }
    }

    public var terrainEnabled: Bool = false {
        didSet {
            guard oldValue != terrainEnabled else { return }
            updateTerrainIfNeeded()
        }
    }

    public var terrainExaggeration: Double = 1.5 {
        didSet {
            guard oldValue != terrainExaggeration else { return }
            updateTerrainIfNeeded()
        }
    }

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
        map.allowsTilting = true
        
        view.addSubview(map)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tap.delegate = self
        map.addGestureRecognizer(tap)

        if #available(iOS 11.0, *) {
            // iOS 11+ manages insets via adjustedContentInset; nothing extra needed.
        } else if responds(to: #selector(setter: UIViewController.automaticallyAdjustsScrollViewInsets)) {
            automaticallyAdjustsScrollViewInsets = false
        }

        // Configure accessibility for VoiceOver rotor navigation
        configureAccessibility()

        // Set initial camera - default to Phuket (smart camera will reposition based on data)
        let camera = initialCamera ?? DiveMapCamera(
            center: CLLocationCoordinate2D(latitude: 8.0, longitude: 98.3),
            zoomLevel: 8.0
        )
        setCamera(camera, animated: false)
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
            pitch: camera.pitch,
            heading: camera.bearing
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

    /// Converts a coordinate to a screen point. Used by accessibility elements.
    func convertCoordinate(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        return map.convert(coordinate, toPointTo: nil)
    }

    /// Switches to offline mode using bundled PMTiles.
    /// Call this when network is unavailable or user explicitly requests offline maps.
    public func switchToOfflineMode() {
        guard let offlineURL = offlineStyleURL else {
            logger.error("offline_switch_failed: no offline style available")
            return
        }
        logger.log("switching_to_offline_mode")
        didFallbackToOfflineStyle = true
        map.styleURL = offlineURL
    }

    /// Returns whether the map is currently in offline mode.
    public var isOfflineMode: Bool {
        didFallbackToOfflineStyle
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
        updateHeatmapLayerIfNeeded()
        updateTerrainIfNeeded()
        emitViewportChange()
    }

    public func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
        logger.error("style_failed: \(error.localizedDescription, privacy: .public)")

        // If we already tried offline fallback, signal parent to use MapKit
        if didFallbackToOfflineStyle {
            logger.error("all_styles_failed: triggering MapKit fallback")
            DispatchQueue.main.async { [weak self] in
                self?.onLoadFailure?()
            }
            return
        }

        // Try offline style fallback
        guard let offlineURL = offlineStyleURL else {
            // No offline fallback available - signal parent
            logger.error("no_offline_style: triggering MapKit fallback")
            DispatchQueue.main.async { [weak self] in
                self?.onLoadFailure?()
            }
            return
        }

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
            maxLongitude: bounds.ne.longitude,
            zoomLevel: map.zoomLevel
        )

        // Only emit if significantly different from last
        if let last = lastEmittedViewport,
           abs(last.minLatitude - viewport.minLatitude) < 0.1,
           abs(last.maxLatitude - viewport.maxLatitude) < 0.1,
           abs(last.zoomLevel - viewport.zoomLevel) < 0.05 {
            return
        }

        lastEmittedViewport = viewport
        emitViewportChange()

        // Update accessibility elements when viewport changes (for VoiceOver rotor)
        updateAccessibilityElements()
    }

    // MARK: - Gesture Handling

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard !showHeatmap else { return }
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
            let count = (feature.attribute(forKey: "point_count") as? NSNumber)?.intValue ?? 0
            logger.log("cluster_tapped count=\(count, privacy: .public)")
            UIAccessibility.post(notification: .announcement, argument: "\(count) sites in this cluster")

            // Notify parent for site stack display (Resy-style)
            let clusterCenter = map.convert(point, toCoordinateFrom: map)
            if let onClusterTap {
                DispatchQueue.main.async {
                    onClusterTap(clusterCenter, count)
                }
            }

            // Also zoom in for better exploration
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
            // Re-enabled clustering for Resy-style site stack interaction
            let clusteringOptions: [MLNShapeSourceOption: Any] = [
                .clustered: true,
                .clusterRadius: MapTheme.Clustering.clusterRadius,
                .maximumZoomLevelForClustering: MapTheme.Clustering.maxClusterZoom
            ]
            let sites = MLNShapeSource(identifier: "sites", shape: empty, options: clusteringOptions)
            style.addSource(sites)
            siteSource = sites
            logger.log("source_added: sites WITH clustering (radius: \(MapTheme.Clustering.clusterRadius, privacy: .public))")
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

            // Cluster radius based on point count (zoom-responsive on iOS 17)
            cluster.circleRadius = clusterCountResponsiveRadius()
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

        // Glow radius scales with zoom level (zoom-responsive on iOS 17)
        let glowRadiusExpression = zoomResponsiveGlowRadius()

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

        // Marker radius scales with zoom level (zoom-responsive on iOS 17)
        let markerRadiusExpression = zoomResponsiveMarkerRadius()

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
        // Selection radius scales with zoom level (zoom-responsive on iOS 17)
        let selectionRadiusExpression = zoomResponsiveSelectionRadius()

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

        let isHeatmapMode = showHeatmap
        let updateLayers = { [layerSettings] in
            // Toggle cluster visibility
            let clusterIds = ["site-cluster", "site-cluster-count"]
            for id in clusterIds {
                if let layer = style.layer(withIdentifier: id) {
                    layer.isVisible = !isHeatmapMode && layerSettings.showClusters
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
                if let layer = style.layer(withIdentifier: id) {
                    layer.isVisible = !isHeatmapMode && layerSettings.showStatusGlows
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
                layer.isVisible = !isHeatmapMode
            }

            if let selectedLayer = style.layer(withIdentifier: "site-selected") {
                selectedLayer.isVisible = !isHeatmapMode
            }
        }

        if Thread.isMainThread {
            updateLayers()
        } else {
            DispatchQueue.main.async(execute: updateLayers)
        }
    }

    private func updateHeatmapLayerIfNeeded() {
        guard styleIsReady, map != nil else { return }
        if showHeatmap {
            heatmapLayerManager.update(points: heatmapPoints, on: map)
        } else {
            heatmapLayerManager.remove(from: map)
        }
    }

    private func updateTerrainIfNeeded() {
        guard styleIsReady, map != nil else { return }
        terrainLayerManager.update(
            on: map,
            enabled: terrainEnabled,
            exaggeration: terrainExaggeration
        )
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
            pitch: map.camera.pitch,
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
        guard styleIsReady, siteSource != nil else {
            logger.log("updateAnnotationsIfReady: NOT READY styleReady=\(self.styleIsReady, privacy: .public) hasSource=\(self.siteSource != nil, privacy: .public)")
            logger.log("  → style layers: \(self.map?.style?.layers.count ?? 0, privacy: .public), sources: \(self.map?.style?.sources.count ?? 0, privacy: .public)")
            return
        }

        logger.log("updateAnnotationsIfReady: updating \(self.annotations.count, privacy: .public) annotations")

        // Update accessibility elements for VoiceOver rotor support
        updateAccessibilityElements()

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
            maxLongitude: bounds.ne.longitude,
            zoomLevel: map.zoomLevel
        )
        DispatchQueue.main.async {
            onRegionChange(viewport)
        }
    }

    // MARK: - VoiceOver Accessibility Support

    /// Configure the map view as an accessibility container for rotor navigation.
    private func configureAccessibility() {
        view.isAccessibilityElement = false
        view.accessibilityContainerType = .semanticGroup
        view.accessibilityLabel = NSLocalizedString("Dive sites map", comment: "VoiceOver label for the map view")
    }

    /// Update accessibility elements for VoiceOver rotor navigation.
    /// Creates an accessibility element for each visible annotation.
    private func updateAccessibilityElements() {
        // Get visible annotations in viewport
        let visibleAnnotations = annotations.filter { annotation in
            guard let map = map else { return false }
            let bounds = map.visibleCoordinateBounds
            return annotation.coordinate.latitude >= bounds.sw.latitude &&
                   annotation.coordinate.latitude <= bounds.ne.latitude &&
                   annotation.coordinate.longitude >= bounds.sw.longitude &&
                   annotation.coordinate.longitude <= bounds.ne.longitude
        }

        // Limit to reasonable number for performance (VoiceOver can handle ~100 elements well)
        let limitedAnnotations = Array(visibleAnnotations.prefix(100))

        // Create accessibility elements for visible annotations
        accessibilityAnnotationElements = limitedAnnotations.compactMap { annotation in
            // Create element with site name for the label
            MapPinAccessibilityElement(
                annotationId: annotation.id,
                siteName: "Dive site",  // Will be updated with actual name when available
                mapController: self,
                accessibilityContainer: view as Any
            )
        }

        // Update the accessibility elements
        view.accessibilityElements = accessibilityAnnotationElements

        // Post notification for VoiceOver to refresh
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    /// Override to provide accessibility elements for VoiceOver rotor.
    public override var accessibilityElements: [Any]? {
        get {
            return accessibilityAnnotationElements
        }
        set {
            // Allow setting via updateAccessibilityElements
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

// MARK: - Accessibility Element for VoiceOver Rotor

/// Custom accessibility element for map pins that enables VoiceOver rotor navigation.
/// Each element represents a dive site annotation on the map.
public final class MapPinAccessibilityElement: UIAccessibilityElement {
    let annotationId: String
    let siteName: String
    private weak var mapController: MapVC?

    init(annotationId: String, siteName: String, mapController: MapVC, accessibilityContainer: Any) {
        self.annotationId = annotationId
        self.siteName = siteName
        self.mapController = mapController
        super.init(accessibilityContainer: accessibilityContainer)

        // Configure accessibility properties
        self.accessibilityLabel = siteName
        self.accessibilityHint = NSLocalizedString("Double tap to view details", comment: "VoiceOver hint for dive site pins")
        self.accessibilityTraits = .button
    }

    override public var accessibilityFrame: CGRect {
        get {
            guard let mapController = mapController,
                  let annotation = mapController.annotations.first(where: { $0.id == annotationId }) else {
                return .zero
            }
            // Convert coordinate to screen position
            let point = mapController.convertCoordinate(annotation.coordinate)
            // Ensure minimum touch target size (44x44 per Apple HIG)
            let size: CGFloat = 44
            return CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        }
        set { }
    }

    override public func accessibilityActivate() -> Bool {
        guard let mapController = mapController else { return false }
        mapController.onSelectAnnotation?(annotationId)
        return true
    }
}

// MARK: - Zoom-Responsive Expression Helpers
// iOS 17: Use mgl_interpolate for dynamic sizing that responds to zoom level
// iOS 18+: Fall back to static values (NSExpression validation blocks mgl_interpolate)

private extension MapVC {

    /// Creates a zoom-responsive radius expression using MapTheme.Sizing.markerRadiusStops.
    /// Returns static value on iOS 18+ where mgl_interpolate is blocked.
    func zoomResponsiveMarkerRadius() -> NSExpression {
        if #available(iOS 18, *) {
            return NSExpression(forConstantValue: 8)
        }
        let stops = MapTheme.Sizing.markerRadiusStops as NSDictionary
        return NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", stops)
    }

    /// Creates a cluster-count-responsive radius expression using MapTheme.Sizing.clusterRadiusStops.
    /// Returns static value on iOS 18+ where mgl_interpolate is blocked.
    func clusterCountResponsiveRadius() -> NSExpression {
        if #available(iOS 18, *) {
            return NSExpression(forConstantValue: 24)
        }
        let stops = MapTheme.Sizing.clusterRadiusStops as NSDictionary
        return NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:(point_count, 'linear', nil, %@)", stops)
    }

    /// Creates a zoom-responsive glow radius (marker radius * multiplier).
    /// Returns static value on iOS 18+ where mgl_interpolate is blocked.
    func zoomResponsiveGlowRadius() -> NSExpression {
        if #available(iOS 18, *) {
            return NSExpression(forConstantValue: 16)
        }
        // Glow radius = marker radius * multiplier at each zoom stop
        let multiplier = MapTheme.Sizing.glowRadiusMultiplier
        var glowStops: [Double: Double] = [:]
        for (zoom, radius) in MapTheme.Sizing.markerRadiusStops {
            glowStops[zoom] = radius * multiplier
        }
        let stops = glowStops as NSDictionary
        return NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", stops)
    }

    /// Creates a zoom-responsive selection ring radius (slightly larger than marker).
    /// Returns static value on iOS 18+ where mgl_interpolate is blocked.
    func zoomResponsiveSelectionRadius() -> NSExpression {
        if #available(iOS 18, *) {
            return NSExpression(forConstantValue: 12)
        }
        // Selection radius = marker radius + offset at each zoom stop
        let offset: Double = 4
        var selectionStops: [Double: Double] = [:]
        for (zoom, radius) in MapTheme.Sizing.markerRadiusStops {
            selectionStops[zoom] = radius + offset
        }
        let stops = selectionStops as NSDictionary
        return NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", stops)
    }
}
