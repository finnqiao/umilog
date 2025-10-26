import SwiftUI
import MapKit
import UmiDB
import os

struct SiteAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    let visited: Bool
    let wishlist: Bool
    let difficulty: DiveSite.Difficulty
}

final class MapCoordinator: NSObject, MKMapViewDelegate {
    private let onSelect: (String) -> Void
    private let onRegionChange: (MKCoordinateRegion) -> Void
    private let logger = Logger(subsystem: "app.umilog", category: "MapCluster")
    var layerSettings: MapLayerSettings {
        didSet {
            guard oldValue != layerSettings else { return }
            logger.log("layers_updated clustering=\\(self.layerSettings.showClusters, privacy: .public) glow=\\(self.layerSettings.showStatusGlows, privacy: .public) difficulty=\\(self.layerSettings.colorByDifficulty, privacy: .public)")
        }
    }
    
    init(layerSettings: MapLayerSettings, onSelect: @escaping (String) -> Void, onRegionChange: @escaping (MKCoordinateRegion) -> Void) {
        self.onSelect = onSelect
        self.onRegionChange = onRegionChange
        self.layerSettings = layerSettings
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let id = "site-marker"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil { view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id) }
        view?.annotation = annotation
        applyAppearance(to: view, annotation: annotation)
        return view
    }

    func refresh(mapView: MKMapView) {
        for annotation in mapView.annotations {
            guard let marker = mapView.view(for: annotation) as? MKMarkerAnnotationView else { continue }
            applyAppearance(to: marker, annotation: annotation)
        }
    }

    private func applyAppearance(to view: MKMarkerAnnotationView?, annotation: MKAnnotation) {
        guard let view else { return }
        view.clusteringIdentifier = layerSettings.showClusters ? "site" : nil
        view.glyphImage = UIImage(systemName: "mappin")

        guard let point = annotation as? MKPointAnnotation else {
            view.markerTintColor = .systemGray3
            return
        }
        let attributes = parseAttributes(from: point.subtitle)

        if layerSettings.colorByDifficulty, let difficulty = attributes["difficulty"] {
            view.markerTintColor = color(for: difficulty)
        } else if layerSettings.showStatusGlows {
            if attributes["visited"] == "1" {
                view.markerTintColor = UIColor(Color.oceanBlue)
            } else if attributes["wishlist"] == "1" {
                view.markerTintColor = .systemYellow
            } else {
                view.markerTintColor = .systemGray3
            }
        } else {
            view.markerTintColor = .systemGray4
        }
    }

    private func parseAttributes(from subtitle: String?) -> [String: String] {
        guard let subtitle, !subtitle.isEmpty else { return [:] }
        return subtitle
            .split(separator: ";")
            .reduce(into: [String: String]()) { partialResult, pair in
                let parts = pair.split(separator: ":", maxSplits: 1).map { String($0) }
                guard parts.count == 2 else { return }
                partialResult[parts[0]] = parts[1]
            }
    }

    private func color(for difficulty: String) -> UIColor {
        switch difficulty {
        case DiveSite.Difficulty.beginner.rawValue:
            return .systemGreen
        case DiveSite.Difficulty.intermediate.rawValue:
            return .systemBlue
        case DiveSite.Difficulty.advanced.rawValue:
            return .systemOrange
        default:
            return UIColor(Color.oceanBlue)
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let cluster = view.annotation as? MKClusterAnnotation {
            // Zoom into cluster
            let members = cluster.memberAnnotations
            mapView.showAnnotations(members, animated: true)
            return
        }
        guard let point = view.annotation as? MKPointAnnotation else { return }
        let idPrefix = "id:"
        if let t = point.title, let range = t.range(of: idPrefix) {
            let id = String(t[range.upperBound...])
            logger.log("pin_selected id=\\(id, privacy: .public)")
            onSelect(id)
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = mapView.region.center
        let span = mapView.region.span
        let region = MKCoordinateRegion(center: center, span: span)
        onRegionChange(region)
    }
}

struct MapClusterView: UIViewRepresentable {
    var annotations: [SiteAnnotation]
    var layerSettings: MapLayerSettings
    var onSelect: (String) -> Void
    var onRegionChange: (MKCoordinateRegion) -> Void = { _ in }
    var center: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        context.coordinator.layerSettings = layerSettings
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.showsScale = false
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "site-marker")
        if let c = center {
            map.setRegion(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)), animated: false)
        }
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.layerSettings = layerSettings

        // Diff existing vs desired annotations to avoid churn and visual jitter
        let existing = uiView.annotations.compactMap { $0 as? MKPointAnnotation }
        var existingById: [String: MKPointAnnotation] = [:]
        for e in existing {
            if let t = e.title, t.hasPrefix("id:") {
                let id = String(t.dropFirst(3))
                existingById[id] = e
            }
        }
        let desiredById: [String: SiteAnnotation] = Dictionary(uniqueKeysWithValues: annotations.map { ($0.id, $0) })
        
        // Remove annotations that are no longer desired
        let toRemove = existing.filter { e in
            guard let t = e.title, t.hasPrefix("id:") else { return true }
            let id = String(t.dropFirst(3))
            return desiredById[id] == nil
        }
        if !toRemove.isEmpty { uiView.removeAnnotations(toRemove) }
        
        // Add or update annotations
        var toAdd: [MKPointAnnotation] = []
        for (id, ann) in desiredById {
            if let ex = existingById[id] {
                // Update coordinate and subtitle if changed
                if ex.coordinate.latitude != ann.coordinate.latitude || ex.coordinate.longitude != ann.coordinate.longitude {
                    ex.coordinate = ann.coordinate
                }
                let newSubtitle = "visited:\(ann.visited ? 1 : 0);wishlist:\(ann.wishlist ? 1 : 0);difficulty:\(ann.difficulty.rawValue)"
                if ex.subtitle != newSubtitle { ex.subtitle = newSubtitle }
            } else {
                let p = MKPointAnnotation()
                p.coordinate = ann.coordinate
                p.title = "id:\(ann.id)"
                p.subtitle = "visited:\(ann.visited ? 1 : 0);wishlist:\(ann.wishlist ? 1 : 0);difficulty:\(ann.difficulty.rawValue)"
                toAdd.append(p)
            }
        }
        if !toAdd.isEmpty {
            UIView.performWithoutAnimation {
                uiView.addAnnotations(toAdd)
            }
        }
        // Do not constantly recenter here; region is controlled by gestures and initial makeUIView

        context.coordinator.refresh(mapView: uiView)
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(layerSettings: layerSettings, onSelect: onSelect, onRegionChange: onRegionChange)
    }
}
