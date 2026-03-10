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
                print("CountyBoundaryMapView: failed to load – \(error)")
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let centerDelta = abs(mapView.region.center.latitude  - region.center.latitude)
                        + abs(mapView.region.center.longitude - region.center.longitude)
        let spanDelta   = abs(mapView.region.span.latitudeDelta  - region.span.latitudeDelta)
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
            let span = mapView.region.span.latitudeDelta
            for ann in mapView.annotations {
                (mapView.view(for: ann) as? CountyLabelAnnotationView)?.update(span: span)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = UIColor(red: 191/255, green: 97/255, blue: 106/255, alpha: 0.85)
                renderer.lineWidth   = 1.5
                renderer.fillColor   = .clear
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
