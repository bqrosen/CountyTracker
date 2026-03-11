import SwiftUI
import MapKit
import UniformTypeIdentifiers

// MARK: - Visited county map (used on main screen)

struct VisitedCountyMapView: UIViewRepresentable {
    let visitedKeys: Set<String>
    var userLocation: CLLocationCoordinate2D?
    @Binding var resetMapZoom: Bool
    let theme: AppTheme
    @EnvironmentObject private var themeSettings: ThemeSettings

    // ~50-mile radius span (~0.725° each direction)
    private static let localSpan = MKCoordinateSpan(latitudeDelta: 1.45, longitudeDelta: 1.45)

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5, longitude: -96.0),
        span: MKCoordinateSpan(latitudeDelta: 28.0, longitudeDelta: 62.0)
    )

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // Always start at continental US; will animate to user once location arrives
        mapView.setRegion(Self.defaultRegion, animated: false)

        // Seed so first updateUIView doesn't trigger an unnecessary reload
        context.coordinator.lastVisitedKeys = visitedKeys
        context.coordinator.lastTheme = theme

        Task {
            do {
                async let polys = CountyBoundaryLoader.shared.loadPolygons()
                async let anns  = CountyBoundaryLoader.shared.loadAnnotations()
                let (polygons, annotations) = try await (polys, anns)
                await MainActor.run {
                    mapView.addOverlays(polygons, level: .aboveRoads)
                    mapView.addAnnotations(annotations)
                }
            } catch {
                print("VisitedCountyMapView: failed to load – \(error)")
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        // Auto-center on user once per app session as soon as location is available
        if !context.coordinator.hasCenteredOnOpen, let coord = userLocation {
            context.coordinator.hasCenteredOnOpen = true
            mapView.setRegion(MKCoordinateRegion(center: coord, span: VisitedCountyMapView.localSpan), animated: true)
        }
        if visitedKeys != context.coordinator.lastVisitedKeys {
            context.coordinator.lastVisitedKeys = visitedKeys
            context.coordinator.reloadOverlays(on: mapView)
        } else if theme != context.coordinator.lastTheme {
            context.coordinator.lastTheme = theme
            context.coordinator.reloadOverlays(on: mapView)
        }
        if resetMapZoom {
            let region: MKCoordinateRegion
            if let coord = userLocation {
                region = MKCoordinateRegion(center: coord, span: VisitedCountyMapView.localSpan)
            } else {
                region = VisitedCountyMapView.defaultRegion
            }
            mapView.setRegion(region, animated: true)
            // Clear the flag after the current update pass
            DispatchQueue.main.async { context.coordinator.clearReset() }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VisitedCountyMapView
        var lastVisitedKeys: Set<String> = []
        var lastTheme: AppTheme = .system
        var hasCenteredOnOpen = false
        var currentSpan: Double = 28.0
        private var lastStrokeVisibility = true  // true = strokes visible (span <= 7.0)

        init(_ parent: VisitedCountyMapView) {
            self.parent = parent
        }

        /// Flips the resetMapZoom binding back to false via the @Binding setter.
        func clearReset() {
            parent.resetMapZoom = false
        }

        func reloadOverlays(on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            Task {
                do {
                    async let polys = CountyBoundaryLoader.shared.loadPolygons()
                    async let anns  = CountyBoundaryLoader.shared.loadAnnotations()
                    let (polygons, annotations) = try await (polys, anns)
                    await MainActor.run {
                        mapView.addOverlays(polygons, level: .aboveRoads)
                        mapView.addAnnotations(annotations)
                    }
                } catch {
                    print("VisitedCountyMapView: reload failed – \(error)")
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let span = mapView.region.span.latitudeDelta
            currentSpan = span
            
            // Reload overlays when crossing the stroke visibility threshold
            let shouldShowStrokes = span <= 20.0
            if shouldShowStrokes != lastStrokeVisibility {
                lastStrokeVisibility = shouldShowStrokes
                reloadOverlays(on: mapView)
            }
            
            for ann in mapView.annotations {
                (mapView.view(for: ann) as? CountyLabelAnnotationView)?.update(span: span)
            }
        }


        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let isVisited = parent.visitedKeys.contains(polygon.title ?? "")
                let strokeColor = UIColor(parent.themeSettings.mapStrokeColor)
                let fillColor = UIColor(parent.themeSettings.mapFillColor)
                renderer.fillColor   = isVisited ? fillColor.withAlphaComponent(0.60) : .clear
                // Hide strokes at continental scale (span > 20.0), show only visited fills
                renderer.strokeColor = currentSpan > 20.0 ? UIColor.clear : strokeColor.withAlphaComponent(0.85)
                renderer.lineWidth   = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let id   = "CountyLabel"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? CountyLabelAnnotationView)
                       ?? CountyLabelAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.setThemeColor(UIColor(parent.themeSettings.mapStrokeColor))
            view.update(span: mapView.region.span.latitudeDelta)
            return view
        }
    }
}

struct MapChartTextDocument: FileDocument {
    static var readableContentTypes: [UTType]  { [.plainText, .json] }
    static var writableContentTypes: [UTType]  { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
