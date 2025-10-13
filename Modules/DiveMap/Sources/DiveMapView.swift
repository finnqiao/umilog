import SwiftUI
import MapLibre

public struct DiveMapView: UIViewControllerRepresentable {
    public init() {}
    public func makeUIViewController(context: Context) -> MapVC { MapVC() }
    public func updateUIViewController(_ uiViewController: MapVC, context: Context) {}
}
