import UIKit
import MapLibre
import os

public final class MapVC: UIViewController, MLNMapViewDelegate {
    private var map: MLNMapView!
    private let logger = Logger(subsystem: "app.umilog", category: "DiveMap")

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a background view as fallback while tiles load
        let backgroundView = UIView(frame: view.bounds)
        backgroundView.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 0.96, alpha: 1.0) // Light blue
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundView)
        
        guard let styleURL = Bundle.main.url(forResource: "dive_light", withExtension: "json") else {
            logger.error("style_missing: dive_light.json not found in bundle")
            return
        }
        
        // Verify style JSON is valid
        do {
            let styleData = try Data(contentsOf: styleURL)
            let _ = try JSONSerialization.jsonObject(with: styleData)
            logger.log("style_url=\(styleURL.absoluteString, privacy: .public) [valid JSON]")
        } catch {
            logger.error("style_invalid: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        map = MLNMapView(frame: view.bounds, styleURL: styleURL)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.delegate = self
        view.addSubview(map)
    }

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        logger.log("style_loaded")
        loadRuntimeSources(style)
        addRuntimeLayers(style)
        addAnimatedWater(style)
        // Set an initial camera to a seeded region (Red Sea)
        let center = CLLocationCoordinate2D(latitude: 27.78, longitude: 34.32)
        map.setCenter(center, zoomLevel: 4.8, animated: false)
        logger.log("camera_center lat=\(center.latitude, privacy: .public) lon=\(center.longitude, privacy: .public) zoom=4.8")
    }
}

// MARK: - Runtime sources & layers
private extension MapVC {
    func countFeatures(in url: URL) -> Int {
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let features = json["features"] as? [Any] {
                return features.count
            }
        } catch {
            logger.error("geojson_count_error: \(error.localizedDescription, privacy: .public)")
        }
        return -1
    }

    func loadRuntimeSources(_ style: MLNStyle) {
        guard
            let sitesURL = Bundle.main.url(forResource: "sites", withExtension: "geojson"),
            let shopsURL = Bundle.main.url(forResource: "shops", withExtension: "geojson")
        else {
            logger.error("geojson_missing: sites.geojson or shops.geojson not found")
            return
        }
        logger.log("geojson_sites=\(sitesURL.lastPathComponent, privacy: .public) count=\(self.countFeatures(in: sitesURL))")
        logger.log("geojson_shops=\(shopsURL.lastPathComponent, privacy: .public) count=\(self.countFeatures(in: shopsURL))")

        do {
            let sitesData = try Data(contentsOf: sitesURL)
            let shopsData = try Data(contentsOf: shopsURL)
            let sitesShape = try MLNShape(data: sitesData, encoding: String.Encoding.utf8.rawValue)
            let shopsShape = try MLNShape(data: shopsData, encoding: String.Encoding.utf8.rawValue)

            let sites = MLNShapeSource(identifier: "sites", shape: sitesShape, options: [
                .clustered: true as NSNumber,
                .clusterRadius: 44 as NSNumber
            ])
            let shops = MLNShapeSource(identifier: "shops", shape: shopsShape, options: nil)

            style.addSource(sites)
            style.addSource(shops)
            logger.log("sources_added: sites+shops")
        } catch {
            logger.error("shape_load_error: \(error.localizedDescription, privacy: .public)")
        }

        // Runtime icons using SF Symbols as placeholders
        if let siteImg = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.systemTeal, renderingMode: .alwaysOriginal) {
            style.setImage(siteImg, forName: "site-icon")
        }
        if let wreckImg = UIImage(systemName: "shippingbox.fill")?.withTintColor(.brown, renderingMode: .alwaysOriginal) {
            style.setImage(wreckImg, forName: "wreck-icon")
        }
        if let shopImg = UIImage(systemName: "bag.fill")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal) {
            style.setImage(shopImg, forName: "shop-icon")
        }
        if let haloImg = UIImage(systemName: "circle")?.withTintColor(.systemTeal, renderingMode: .alwaysOriginal) {
            style.setImage(haloImg, forName: "halo-icon")
        }
        logger.log("icons_registered: site wreck shop halo")
    }

    func addRuntimeLayers(_ style: MLNStyle) {
        guard let sites = style.source(withIdentifier: "sites") as? MLNShapeSource else {
            logger.error("layer_error: sites source missing")
            return
        }

        // Non-clustered sites (symbol)
        let siteLayer = MLNSymbolStyleLayer(identifier: "site-layer", source: sites)
        siteLayer.predicate = NSPredicate(format: "cluster != YES")
        siteLayer.iconImageName = NSExpression(format: "TERNARY(kind == 'wreck', 'wreck-icon', 'site-icon')")
        siteLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
        style.addLayer(siteLayer)

        // Cluster circles
        let cluster = MLNCircleStyleLayer(identifier: "site-cluster", source: sites)
        cluster.predicate = NSPredicate(format: "cluster == YES")
        cluster.circleColor = NSExpression(forConstantValue: UIColor.systemTeal)
        cluster.circleRadius = NSExpression(forConstantValue: 16)
        style.addLayer(cluster)

        // Cluster count text
        let count = MLNSymbolStyleLayer(identifier: "cluster-count", source: sites)
        count.predicate = NSPredicate(format: "cluster == YES")
        count.text = NSExpression(format: "CAST(point_count, 'NSString')")
        count.textColor = NSExpression(forConstantValue: UIColor.white)
        count.textFontSize = NSExpression(forConstantValue: 12)
        style.addLayer(count)

        // Shops
        if let shops = style.source(withIdentifier: "shops") as? MLNShapeSource {
            let shopLayer = MLNSymbolStyleLayer(identifier: "shop-layer", source: shops)
            shopLayer.iconImageName = NSExpression(forConstantValue: "shop-icon")
            shopLayer.iconAllowsOverlap = NSExpression(forConstantValue: true)
            style.addLayer(shopLayer)
        } else {
            logger.error("layer_error: shops source missing")
        }

        // Selection halo (data-driven via 'state' later)
        let halo = MLNSymbolStyleLayer(identifier: "selection-halo", source: sites)
        halo.predicate = NSPredicate(format: "state == 'selected' && cluster != YES")
        halo.iconImageName = NSExpression(forConstantValue: "halo-icon")
        halo.iconScale = NSExpression(forConstantValue: 1.4)
        style.addLayer(halo)

        logger.log("layers_added: site-layer, site-cluster, cluster-count, shop-layer, selection-halo")
    }

    func addAnimatedWater(_ style: MLNStyle) {
        // TODO: Implement custom Metal style layer (MLNCustomStyleLayer) for subtle water motion.
        // Keep this a no-op for now so we can integrate progressively without compile risk.
        logger.log("water_layer: TODO")
    }
}
