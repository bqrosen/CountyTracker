import SwiftUI
import MapKit

struct CountyBoundaryMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @EnvironmentObject private var themeSettings: ThemeSettings

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
                async let border = CountyBoundaryLoader.shared.loadBorderPolygons()
                let (polygons, annotations, borderPolygons) = try await (polys, anns, border)
                await MainActor.run {
                    mapView.addOverlays(polygons, level: .aboveRoads)
                    mapView.addOverlays(borderPolygons, level: .aboveRoads)
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
                let strokeColor = UIColor(parent.themeSettings.mapStrokeColor)
                let isBorder = polygon.title == CountyBoundaryLoader.USBorderKey
                
                if isBorder {
                    // Border: theme color, no fill
                    renderer.strokeColor = strokeColor.withAlphaComponent(0.90)
                    renderer.lineWidth   = 1.5
                    renderer.fillColor   = .clear
                } else {
                    // County: simple outline
                    renderer.strokeColor = strokeColor.withAlphaComponent(0.85)
                    renderer.lineWidth   = 1.5
                    renderer.fillColor   = .clear
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let id = "UserBlueDot"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.canShowCallout = false
                view.isEnabled = false
                view.bounds = CGRect(x: 0, y: 0, width: 16, height: 16)
                view.backgroundColor = .systemBlue
                view.layer.cornerRadius = 8
                view.layer.borderWidth = 2
                view.layer.borderColor = UIColor.white.cgColor
                return view
            }
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
