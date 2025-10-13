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
}

final class MapCoordinator: NSObject, MKMapViewDelegate {
    private let onSelect: (String) -> Void
    private let onRegionChange: (MKCoordinateRegion) -> Void
    private let logger = Logger(subsystem: "app.umilog", category: "MapCluster")
    init(onSelect: @escaping (String) -> Void, onRegionChange: @escaping (MKCoordinateRegion) -> Void) {
        self.onSelect = onSelect
        self.onRegionChange = onRegionChange
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let id = "site-marker"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
        if view == nil { view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id) }
        view?.annotation = annotation
        view?.clusteringIdentifier = "site"
        if let site = annotation as? MKPointAnnotation {
            // Color: visited vs wishlist vs default
            if (site.subtitle ?? "").contains("visited:1") {
                view?.markerTintColor = UIColor(Color.oceanBlue)
            } else if (site.subtitle ?? "").contains("wishlist:1") {
                view?.markerTintColor = .systemYellow
            } else {
                view?.markerTintColor = .systemGray3
            }
            view?.glyphImage = UIImage(systemName: "mappin")
        }
        return view
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
    var onSelect: (String) -> Void
    var onRegionChange: (MKCoordinateRegion) -> Void = { _ in }
    var center: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
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
                let newSubtitle = "visited:\(ann.visited ? 1 : 0);wishlist:\(ann.wishlist ? 1 : 0)"
                if ex.subtitle != newSubtitle { ex.subtitle = newSubtitle }
            } else {
                let p = MKPointAnnotation()
                p.coordinate = ann.coordinate
                p.title = "id:\(ann.id)"
                p.subtitle = "visited:\(ann.visited ? 1 : 0);wishlist:\(ann.wishlist ? 1 : 0)"
                toAdd.append(p)
            }
        }
        if !toAdd.isEmpty {
            UIView.performWithoutAnimation {
                uiView.addAnnotations(toAdd)
            }
        }
        // Do not constantly recenter here; region is controlled by gestures and initial makeUIView
    }

    func makeCoordinator() -> MapCoordinator { MapCoordinator(onSelect: onSelect, onRegionChange: onRegionChange) }
}
