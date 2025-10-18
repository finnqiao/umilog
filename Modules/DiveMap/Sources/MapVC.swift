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
    private lazy var clusterFillColor = accentColor.withAlphaComponent(0.18)
    private var didFallbackToOfflineStyle = false
    private lazy var primaryStyleURL: URL? = Bundle.main.url(forResource: "umilog_min", withExtension: "json")
    private lazy var offlineStyleURL: URL? = Bundle.main.url(forResource: "dive_offline", withExtension: "json")
    private var hasAttemptedPrimarySwitch = false
    private let vectorTileTemplates = ["https://demotiles.maplibre.org/tiles/tiles/{z}/{x}/{y}.pbf"]

    // Runtime callbacks
    public var onSelectAnnotation: ((String) -> Void)?
    public var onRegionChange: ((DiveMapViewport) -> Void)?
    public var initialCamera: DiveMapCamera? {
        didSet {
            guard let camera = initialCamera, map != nil else { return }
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

    public func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        emitViewportChange()
    }

    // MARK: - Gesture Handling

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: map)
        let identifiers: Set<String> = ["site-layer", "site-cluster"]
        let features = map.visibleFeatures(at: point, styleLayerIdentifiers: identifiers)

        guard let feature = features.first else { return }

        if let isCluster = feature.attribute(forKey: "cluster") as? NSNumber, isCluster.boolValue {
            zoomIntoCluster(at: point)
            return
        }

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

        if style.layer(withIdentifier: "site-cluster") == nil {
            let cluster = MLNCircleStyleLayer(identifier: "site-cluster", source: siteSource)
            cluster.predicate = NSPredicate(format: "cluster == YES")
            cluster.circleColor = NSExpression(forConstantValue: clusterFillColor)
            cluster.circleStrokeColor = NSExpression(forConstantValue: accentColor)
            cluster.circleStrokeWidth = NSExpression(forConstantValue: 1.0)
            cluster.circleRadius = NSExpression(forConstantValue: 18)
            style.addLayer(cluster)
        }

        if style.layer(withIdentifier: "site-cluster-count") == nil {
            let count = MLNSymbolStyleLayer(identifier: "site-cluster-count", source: siteSource)
            count.predicate = NSPredicate(format: "cluster == YES")
            count.text = NSExpression(format: "CAST(point_count, 'NSString')")
            count.textColor = NSExpression(forConstantValue: UIColor.white)
            count.textFontSize = NSExpression(forConstantValue: 12)
            count.textFontNames = NSExpression(forConstantValue: ["HelveticaNeue-Bold"])
            count.textAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(count)
        }

        if style.layer(withIdentifier: "site-layer") == nil {
            registerPlaceholderIcon(in: style)
            let sites = MLNSymbolStyleLayer(identifier: "site-layer", source: siteSource)
            sites.predicate = NSPredicate(format: "cluster != YES")
            sites.iconImageName = NSExpression(forConstantValue: "site-placeholder")
            sites.iconScale = NSExpression(forConstantValue: 0.9)
            sites.iconAllowsOverlap = NSExpression(forConstantValue: true)
            sites.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            style.addLayer(sites)
        }

        if style.layer(withIdentifier: "site-selected") == nil {
            registerPlaceholderIcon(in: style)
            let selected = MLNSymbolStyleLayer(identifier: "site-selected", source: siteSource)
            selected.predicate = NSPredicate(format: "selected == 1 && cluster != YES")
            selected.iconImageName = NSExpression(forConstantValue: "site-placeholder")
            selected.iconScale = NSExpression(forConstantValue: 1.2)
            selected.iconAllowsOverlap = NSExpression(forConstantValue: true)
            selected.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            selected.iconColor = NSExpression(forConstantValue: accentColor)
            style.addLayer(selected)
        }
    }

    private func zoomIntoCluster(at point: CGPoint) {
        let coordinate = map.convert(point, toCoordinateFrom: map)
        let targetZoom = min(map.zoomLevel + 1.5, map.maximumZoomLevel)
        map.setCenter(coordinate, zoomLevel: targetZoom, animated: true)
    }

    private func updateAnnotationsIfReady() {
        guard styleIsReady, let siteSource else { return }

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
            siteSource.shape = collection

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

    private func registerPlaceholderIcon(in style: MLNStyle) {
        if style.image(forName: "site-placeholder") != nil { return }
        if let image = UIImage(systemName: "mappin.circle.fill")?.withTintColor(accentColor, renderingMode: .alwaysOriginal) {
            style.setImage(image, forName: "site-placeholder")
        }
    }

    private func ensureBaseLayers(in style: MLNStyle) {
        if style.layer(withIdentifier: "bg") == nil {
            let background = MLNBackgroundStyleLayer(identifier: "bg")
            // Use light blue to make it obvious the map is rendering
            background.backgroundColor = NSExpression(forConstantValue: UIColor(brandHex: "#E8F2F6") ?? UIColor(red: 0.91, green: 0.95, blue: 0.96, alpha: 1.0))
            if let firstLayer = style.layers.first {
                style.insertLayer(background, below: firstLayer)
            } else {
                style.addLayer(background)
            }
        }

        if didFallbackToOfflineStyle {
            logger.log("base_layers_skip_remote")
            return
        }

        if style.source(withIdentifier: "openmap") == nil {
            let options: [MLNTileSourceOption: Any] = [
                .minimumZoomLevel: 0,
                .maximumZoomLevel: 14
            ]
            let vector = MLNVectorTileSource(identifier: "openmap", tileURLTemplates: vectorTileTemplates, options: options)
            style.addSource(vector)
            logger.log("source_added: openmap")

            let water = MLNFillStyleLayer(identifier: "water", source: vector)
            water.sourceLayerIdentifier = "water"
            water.fillColor = NSExpression(forConstantValue: UIColor(brandHex: "#E8F2F6") ?? UIColor(red: 0.91, green: 0.95, blue: 0.96, alpha: 1.0))
            style.addLayer(water)

            let road = MLNLineStyleLayer(identifier: "major-road", source: vector)
            road.sourceLayerIdentifier = "transportation"
            road.predicate = NSPredicate(format: "class IN %@", ["motorway", "trunk", "primary"])
            road.lineColor = NSExpression(forConstantValue: UIColor(brandHex: "#E0DEDB") ?? UIColor(white: 0.88, alpha: 1.0))
            road.lineWidth = NSExpression(forConstantValue: 1.2)
            style.addLayer(road)

            let admin = MLNLineStyleLayer(identifier: "admin", source: vector)
            admin.sourceLayerIdentifier = "boundary"
            admin.lineColor = NSExpression(forConstantValue: UIColor(brandHex: "#ECEAE7") ?? UIColor(white: 0.92, alpha: 1.0))
            admin.lineWidth = NSExpression(forConstantValue: 0.6)
            style.addLayer(admin)

            let place = MLNSymbolStyleLayer(identifier: "place", source: vector)
            place.sourceLayerIdentifier = "place"
            place.text = NSExpression(forKeyPath: "name_en")  // Simplified: use name_en directly
            place.textFontSize = NSExpression(forConstantValue: 13)
            place.textColor = NSExpression(forConstantValue: UIColor(brandHex: "#5E5E5E") ?? UIColor.darkGray)
            place.textHaloColor = NSExpression(forConstantValue: UIColor.white)
            place.textHaloWidth = NSExpression(forConstantValue: 1)
            style.addLayer(place)

            let poi = MLNSymbolStyleLayer(identifier: "poi", source: vector)
            poi.sourceLayerIdentifier = "poi"
            poi.isVisible = false
            style.addLayer(poi)
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
