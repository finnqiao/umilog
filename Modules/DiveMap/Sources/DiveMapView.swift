import SwiftUI
import MapLibre
import CoreLocation
import os

private let logger = Logger(subsystem: "com.umilog", category: "DiveMap")

public struct DiveMapLayerSettings: Equatable {
    public var showClusters: Bool
    public var showStatusGlows: Bool
    public var colorByDifficulty: Bool

    public static let `default` = DiveMapLayerSettings()

    public init(
        showClusters: Bool = true,
        showStatusGlows: Bool = true,
        colorByDifficulty: Bool = true
    ) {
        self.showClusters = showClusters
        self.showStatusGlows = showStatusGlows
        self.colorByDifficulty = colorByDifficulty
    }
}

public struct DiveMapPowerSettings: Equatable {
    public var preferredFramesPerSecond: Int
    public var showsCompass: Bool

    public static let `default` = DiveMapPowerSettings()

    public init(
        preferredFramesPerSecond: Int = 60,
        showsCompass: Bool = true
    ) {
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.showsCompass = showsCompass
    }
}

public struct DiveMapView: UIViewControllerRepresentable {
    public var annotations: [DiveMapAnnotation]
    public var initialCamera: DiveMapCamera
    public var cameraUpdateToken: Int
    public var layerSettings: DiveMapLayerSettings
    public var powerSettings: DiveMapPowerSettings
    public var onSelect: (String) -> Void
    public var onRegionChange: (DiveMapViewport) -> Void
    public var onLoadFailure: (() -> Void)?
    public var onClusterTap: ((CLLocationCoordinate2D, Int) -> Void)?

    public class Coordinator {
        var lastCameraUpdateToken: Int

        init(token: Int) {
            self.lastCameraUpdateToken = token
        }
    }

    public init(
        annotations: [DiveMapAnnotation],
        initialCamera: DiveMapCamera = DiveMapCamera(
            center: CLLocationCoordinate2D(latitude: 0.0, longitude: 120.0),
            zoomLevel: 4.0
        ),
        cameraUpdateToken: Int = 0,
        layerSettings: DiveMapLayerSettings = .default,
        powerSettings: DiveMapPowerSettings = .default,
        onSelect: @escaping (String) -> Void = { _ in },
        onRegionChange: @escaping (DiveMapViewport) -> Void = { _ in },
        onLoadFailure: (() -> Void)? = nil,
        onClusterTap: ((CLLocationCoordinate2D, Int) -> Void)? = nil
    ) {
        self.annotations = annotations
        self.initialCamera = initialCamera
        self.cameraUpdateToken = cameraUpdateToken
        self.layerSettings = layerSettings
        self.powerSettings = powerSettings
        self.onSelect = onSelect
        self.onRegionChange = onRegionChange
        self.onLoadFailure = onLoadFailure
        self.onClusterTap = onClusterTap
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(token: cameraUpdateToken)
    }

    public func makeUIViewController(context: Context) -> MapVC {
        logger.debug("Creating MapVC with \(annotations.count) annotations")
        let controller = MapVC()
        controller.initialCamera = initialCamera
        controller.onSelectAnnotation = onSelect
        controller.onRegionChange = onRegionChange
        controller.onLoadFailure = onLoadFailure
        controller.onClusterTap = onClusterTap
        controller.layerSettings = layerSettings
        controller.powerSettings = powerSettings
        controller.annotations = annotations
        return controller
    }

    public func updateUIViewController(_ uiViewController: MapVC, context: Context) {
        logger.debug("updateUIViewController called with \(annotations.count) annotations")
        uiViewController.onSelectAnnotation = onSelect
        uiViewController.onRegionChange = onRegionChange
        uiViewController.onLoadFailure = onLoadFailure
        uiViewController.onClusterTap = onClusterTap
        if context.coordinator.lastCameraUpdateToken != cameraUpdateToken {
            uiViewController.initialCamera = initialCamera
            context.coordinator.lastCameraUpdateToken = cameraUpdateToken
        }
        uiViewController.layerSettings = layerSettings
        uiViewController.powerSettings = powerSettings
        uiViewController.update(annotations: annotations)
    }
}
