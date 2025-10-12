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
    private let logger = Logger(subsystem: "app.umilog", category: "MapCluster")
    init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }
    
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
        guard let point = view.annotation as? MKPointAnnotation else { return }
        let idPrefix = "id:"
        if let t = point.title, let range = t.range(of: idPrefix) {
            let id = String(t[range.upperBound...])
            logger.log("pin_selected id=\(id, privacy: .public)")
            onSelect(id)
        }
    }
}

struct MapClusterView: UIViewRepresentable {
    var annotations: [SiteAnnotation]
    var onSelect: (String) -> Void
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
        // Remove old annotations
        uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
        // Add new
        let pts = annotations.map { ann -> MKPointAnnotation in
            let p = MKPointAnnotation()
            p.coordinate = ann.coordinate
            p.title = "id:\(ann.id)"
            p.subtitle = "visited:\(ann.visited ? 1 : 0);wishlist:\(ann.wishlist ? 1 : 0)"
            return p
        }
        uiView.addAnnotations(pts)
        if let c = center { uiView.setCenter(c, animated: true) }
    }

    func makeCoordinator() -> MapCoordinator { MapCoordinator(onSelect: onSelect) }
}
