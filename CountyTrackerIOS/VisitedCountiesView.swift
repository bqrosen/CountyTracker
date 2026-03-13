import SwiftUI
import MapKit
import UniformTypeIdentifiers

// MARK: - Visited county map (used on main screen)

struct VisitedCountyMapView: UIViewRepresentable {
    let visitedKeys: Set<String>
    var userLocation: CLLocationCoordinate2D?
    @Binding var resetMapZoom: Bool
    let theme: AppTheme
    var onCoordinatorReady: ((Coordinator) -> Void)?
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
        context.coordinator.mapView = mapView
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

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.6
        mapView.addGestureRecognizer(longPress)

        // Notify parent that coordinator is ready
        onCoordinatorReady?(context.coordinator)

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
                    context.coordinator.overlaysLoaded = true
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
            if context.coordinator.overlaysLoaded {
                context.coordinator.refreshRenderers(on: mapView)
            }
        } else if theme != context.coordinator.lastTheme {
            context.coordinator.lastTheme = theme
            if context.coordinator.overlaysLoaded {
                context.coordinator.refreshRenderers(on: mapView)
            }
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
        var mapView: MKMapView?
        var lastVisitedKeys: Set<String> = []
        var lastTheme: AppTheme = .system
        var hasCenteredOnOpen = false
        var currentSpan: Double = 28.0
        private var lastStrokeVisibility = true  // true = strokes visible (span <= 20.0)
        var overlaysLoaded = false

        init(_ parent: VisitedCountyMapView) {
            self.parent = parent
        }

        /// Flips the resetMapZoom binding back to false via the @Binding setter.
        func clearReset() {
            parent.resetMapZoom = false
        }

        /// Captures the current map view as a UIImage without the user location indicator.
        func takeSnapshot(of mapView: MKMapView) -> UIImage? {
            let wasShowingUserLocation = mapView.showsUserLocation
            let userLocationView = mapView.view(for: mapView.userLocation)
            let wasUserLocationViewHidden = userLocationView?.isHidden ?? false

            mapView.showsUserLocation = false
            userLocationView?.isHidden = true
            mapView.layoutIfNeeded()
            
            let renderer = UIGraphicsImageRenderer(size: mapView.bounds.size)
            let image = renderer.image { _ in
                mapView.drawHierarchy(in: mapView.bounds, afterScreenUpdates: true)
            }
            
            userLocationView?.isHidden = wasUserLocationViewHidden
            mapView.showsUserLocation = wasShowingUserLocation
            return image
        }

        /// Requests a snapshot from the parent and passes it to the callback.
        func requestSnapshot(_ completion: @escaping (UIImage?) -> Void) {
            DispatchQueue.main.async {
                guard let mapView = self.mapView,
                      mapView.bounds.width > 1,
                      mapView.bounds.height > 1 else {
                    completion(nil)
                    return
                }
                let snapshot = self.takeSnapshot(of: mapView)
                completion(snapshot)
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView = mapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            let destinationPlacemark = MKPlacemark(coordinate: coordinate)
            let destination = MKMapItem(placemark: destinationPlacemark)
            destination.name = "Pinned Destination"

            let currentLocation = MKMapItem.forCurrentLocation()
            MKMapItem.openMaps(
                with: [currentLocation, destination],
                launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ]
            )
        }

        /// First-time load (or forced full reload): remove everything and re-add fresh polygons.
        func reloadOverlays(on mapView: MKMapView) {
            overlaysLoaded = false
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
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
                        self.overlaysLoaded = true
                    }
                } catch {
                    print("VisitedCountyMapView: reload failed – \(error)")
                }
            }
        }

        /// Fast path: update renderer properties in-place without removing/re-adding overlays.
        /// Called when only visitedKeys, theme colours, or stroke visibility changes.
        func refreshRenderers(on mapView: MKMapView) {
            let strokeColor = UIColor(parent.themeSettings.mapStrokeColor)
            let fillColor   = UIColor(parent.themeSettings.mapFillColor)
            let showStrokes = currentSpan <= 20.0

            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon,
                      let renderer = mapView.renderer(for: overlay) as? MKPolygonRenderer
                else { continue }

                let isBorder = polygon.title == CountyBoundaryLoader.USBorderKey
                if isBorder {
                    renderer.strokeColor = strokeColor.withAlphaComponent(0.90)
                } else {
                    let isVisited = parent.visitedKeys.contains(polygon.title ?? "")
                    renderer.fillColor   = isVisited ? fillColor.withAlphaComponent(0.60) : .clear
                    renderer.strokeColor = showStrokes ? strokeColor.withAlphaComponent(0.85) : .clear
                }
                renderer.setNeedsDisplay()
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let span = mapView.region.span.latitudeDelta
            currentSpan = span

            // Refresh renderer stroke visibility when crossing the threshold —
            // no overlay removal needed, just update colours in-place.
            let shouldShowStrokes = span <= 20.0
            if shouldShowStrokes != lastStrokeVisibility {
                lastStrokeVisibility = shouldShowStrokes
                if overlaysLoaded {
                    refreshRenderers(on: mapView)
                }
            }

            for ann in mapView.annotations {
                (mapView.view(for: ann) as? CountyLabelAnnotationView)?.update(span: span)
            }
        }


        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let strokeColor = UIColor(parent.themeSettings.mapStrokeColor)
                let fillColor = UIColor(parent.themeSettings.mapFillColor)
                let isBorder = polygon.title == CountyBoundaryLoader.USBorderKey
                
                if isBorder {
                    // Border: always visible, theme color, no fill
                    renderer.strokeColor = strokeColor.withAlphaComponent(0.90)
                    renderer.lineWidth   = 1.5
                    renderer.fillColor   = .clear
                } else {
                    // County: visited get filled, all show stroke only when zoomed in
                    let isVisited = parent.visitedKeys.contains(polygon.title ?? "")
                    renderer.fillColor   = isVisited ? fillColor.withAlphaComponent(0.60) : .clear
                    renderer.strokeColor = currentSpan > 20.0 ? UIColor.clear : strokeColor.withAlphaComponent(0.85)
                    renderer.lineWidth   = 1.5
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
