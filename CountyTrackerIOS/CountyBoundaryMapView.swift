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

        let countyLayerIDs = "1,3,5,7,9,11,13"
        let overlay = MKTileOverlay(urlTemplate: "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/export?bbox={bbox-epsg-3857}&bboxSR=3857&imageSR=3857&size=256,256&format=png32&transparent=true&f=image&layers=show:\(countyLayerIDs)")
        overlay.canReplaceMapContent = false
        overlay.minimumZ = 0
        overlay.maximumZ = 20
        mapView.addOverlay(overlay, level: .aboveLabels)

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
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 1.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
