import SwiftUI
import MapKit

struct CountyBoundaryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.setRegion(region, animated: false)

        // Load all county polygons from the bundled GeoJSON (cached after first call).
        Task {
            do {
                let polygons = try await CountyBoundaryLoader.shared.loadPolygons()
                await MainActor.run {
                    mapView.addOverlays(polygons, level: .aboveRoads)
                }
            } catch {
                print("CountyBoundaryMapView: failed to load county polygons – \(error)")
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let centerDelta = abs(mapView.region.center.latitude - region.center.latitude)
            + abs(mapView.region.center.longitude - region.center.longitude)
        let spanDelta = abs(mapView.region.span.latitudeDelta - region.span.latitudeDelta)
            + abs(mapView.region.span.longitudeDelta - region.span.longitudeDelta)

        if centerDelta > 0.0001 || spanDelta > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: CountyBoundaryMapView

        init(_ parent: CountyBoundaryMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor.darkGray.withAlphaComponent(0.45)
                renderer.lineWidth = 0.5
                renderer.fillColor = .clear
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
