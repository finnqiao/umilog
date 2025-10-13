import UIKit
import MapLibre

public final class MapVC: UIViewController, MLNMapViewDelegate {
    private var map: MLNMapView!

    public override func viewDidLoad() {
        super.viewDidLoad()
        let styleURL = Bundle.main.url(forResource: "dive_light", withExtension: "json")!
        map = MLNMapView(frame: view.bounds, styleURL: styleURL)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true
        map.delegate = self
        view.addSubview(map)
    }

    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        loadRuntimeSources(style)
        addRuntimeLayers(style)
        addAnimatedWater(style)
    }
}

// MARK: - Runtime sources & layers
private extension MapVC {
    func loadRuntimeSources(_ style: MLNStyle) {
        guard
            let sitesURL = Bundle.main.url(forResource: "sites", withExtension: "geojson"),
            let shopsURL = Bundle.main.url(forResource: "shops", withExtension: "geojson")
        else { return }

        let sitesShape = try! MLNShape(data: try! Data(contentsOf: sitesURL), encoding: String.Encoding.utf8.rawValue)
        let shopsShape = try! MLNShape(data: try! Data(contentsOf: shopsURL), encoding: String.Encoding.utf8.rawValue)

        let sites = MLNShapeSource(identifier: "sites", shape: sitesShape, options: [
            .clustered: true as NSNumber,
            .clusterRadius: 44 as NSNumber
        ])
        let shops = MLNShapeSource(identifier: "shops", shape: shopsShape, options: nil)

        style.addSource(sites)
        style.addSource(shops)

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
    }

    func addRuntimeLayers(_ style: MLNStyle) {
        guard let sites = style.source(withIdentifier: "sites") as? MLNShapeSource else { return }

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
        }

        // Selection halo (data-driven via 'state' later)
        let halo = MLNSymbolStyleLayer(identifier: "selection-halo", source: sites)
        halo.predicate = NSPredicate(format: "state == 'selected' && cluster != YES")
        halo.iconImageName = NSExpression(forConstantValue: "halo-icon")
        halo.iconScale = NSExpression(forConstantValue: 1.4)
        style.addLayer(halo)
    }

    func addAnimatedWater(_ style: MLNStyle) {
        // TODO: Implement custom Metal style layer (MLNCustomStyleLayer) for subtle water motion.
        // Keep this a no-op for now so we can integrate progressively without compile risk.
    }
}
