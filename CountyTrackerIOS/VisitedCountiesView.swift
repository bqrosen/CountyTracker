import SwiftUI
import MapKit
import UniformTypeIdentifiers

// MARK: - Visited county map (used on main screen)

struct VisitedCountyMapView: UIViewRepresentable {
    let visitedKeys: Set<String>
    var userLocation: CLLocationCoordinate2D?
    @Binding var resetMapZoom: Bool

    // ~50-mile radius span (~0.725° each direction)
    private static let localSpan = MKCoordinateSpan(latitudeDelta: 1.45, longitudeDelta: 1.45)

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5, longitude: -96.0),
        span: MKCoordinateSpan(latitudeDelta: 28.0, longitudeDelta: 62.0)
    )

    private static let udCenterLat = "visitedMap.centerLat"
    private static let udCenterLon = "visitedMap.centerLon"
    private static let udLatDelta  = "visitedMap.latDelta"
    private static let udLonDelta  = "visitedMap.lonDelta"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func savedRegion() -> MKCoordinateRegion {
        let ud = UserDefaults.standard
        guard ud.object(forKey: Self.udCenterLat) != nil else {
            // No saved region — center on user if available
            if let coord = userLocation {
                return MKCoordinateRegion(center: coord, span: Self.localSpan)
            }
            return Self.defaultRegion
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  ud.double(forKey: Self.udCenterLat),
                longitude: ud.double(forKey: Self.udCenterLon)
            ),
            span: MKCoordinateSpan(
                latitudeDelta:  ud.double(forKey: Self.udLatDelta),
                longitudeDelta: ud.double(forKey: Self.udLonDelta)
            )
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.setRegion(savedRegion(), animated: false)

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
        context.coordinator.refreshFillStyles(on: mapView)
        if resetMapZoom {
            let region: MKCoordinateRegion
            if let coord = parent.userLocation {
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

        init(_ parent: VisitedCountyMapView) {
            self.parent = parent
        }

        /// Flips the resetMapZoom binding back to false via the @Binding setter.
        func clearReset() {
            parent.resetMapZoom = false
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            let span   = region.span.latitudeDelta
            for ann in mapView.annotations {
                (mapView.view(for: ann) as? CountyLabelAnnotationView)?.update(span: span)
            }
            // Persist the current region
            let ud = UserDefaults.standard
            ud.set(region.center.latitude,   forKey: VisitedCountyMapView.udCenterLat)
            ud.set(region.center.longitude,  forKey: VisitedCountyMapView.udCenterLon)
            ud.set(region.span.latitudeDelta,  forKey: VisitedCountyMapView.udLatDelta)
            ud.set(region.span.longitudeDelta, forKey: VisitedCountyMapView.udLonDelta)
        }

        func refreshFillStyles(on mapView: MKMapView) {
            let visited = parent.visitedKeys
            for renderer in mapView.overlays.compactMap({ mapView.renderer(for: $0) as? MKPolygonRenderer }) {
                let isVisited = visited.contains(renderer.polygon.title ?? "")
                renderer.fillColor = isVisited
                    ? UIColor.systemBlue.withAlphaComponent(0.38)
                    : UIColor.clear
                renderer.strokeColor = UIColor(red: 191/255, green: 97/255, blue: 106/255, alpha: 0.85)
                renderer.lineWidth   = 1.5
                renderer.setNeedsDisplay()
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let isVisited = parent.visitedKeys.contains(polygon.title ?? "")
                renderer.fillColor   = isVisited
                    ? UIColor.systemBlue.withAlphaComponent(0.38)
                    : UIColor.clear
                renderer.strokeColor = UIColor(red: 191/255, green: 97/255, blue: 106/255, alpha: 0.85)
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
