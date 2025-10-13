import SwiftUI
import MapLibre
import CoreLocation

public struct DiveMapView: UIViewControllerRepresentable {
    public var annotations: [DiveMapAnnotation]
    public var initialCamera: DiveMapCamera
    public var onSelect: (String) -> Void
    public var onRegionChange: (DiveMapViewport) -> Void

    public init(
        annotations: [DiveMapAnnotation],
        initialCamera: DiveMapCamera = DiveMapCamera(
            center: CLLocationCoordinate2D(latitude: 27.78, longitude: 34.32),
            zoomLevel: 4.8
        ),
        onSelect: @escaping (String) -> Void = { _ in },
        onRegionChange: @escaping (DiveMapViewport) -> Void = { _ in }
    ) {
        self.annotations = annotations
        self.initialCamera = initialCamera
        self.onSelect = onSelect
        self.onRegionChange = onRegionChange
    }

    public func makeUIViewController(context: Context) -> MapVC {
        print("[DEBUG] Creating MapVC with \(annotations.count) annotations")
        let controller = MapVC()
        controller.initialCamera = initialCamera
        controller.onSelectAnnotation = onSelect
        controller.onRegionChange = onRegionChange
        controller.annotations = annotations
        return controller
    }

    public func updateUIViewController(_ uiViewController: MapVC, context: Context) {
        uiViewController.onSelectAnnotation = onSelect
        uiViewController.onRegionChange = onRegionChange
        uiViewController.initialCamera = initialCamera
        uiViewController.update(annotations: annotations)
    }
}
