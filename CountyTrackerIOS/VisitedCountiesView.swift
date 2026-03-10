import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct VisitedCountiesView: View {
    @EnvironmentObject private var store: CountyTrackerStore
    @EnvironmentObject private var themeSettings: ThemeSettings

    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = MapChartTextDocument(text: "")
    @State private var alertMessage: String?

    private var palette: GlassPalette {
        GlassPalette(theme: themeSettings)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundGradientTop, palette.backgroundGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                VisitedCountyMapView(
                    visitedKeys: Set(store.visits.map { $0.key })
                )
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .glassCard(palette, cornerRadius: 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Counties Colored")
                        .font(.headline)

                    List(store.visits) { visit in
                        HStack {
                            Text(visit.displayName)
                            Spacer()
                            Text("\(visit.visitCount)")
                                .foregroundStyle(palette.secondaryText)
                        }
                        .listRowBackground(palette.rowFill)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .padding(14)
                .glassCard(palette)
            }
            .padding()
        }
        .foregroundStyle(palette.primaryText)
        .navigationTitle("Visited Counties")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Data") {
                    Button("Import MapChart File") {
                        isImporting = true
                    }

                    Button("Export MapChart File") {
                        do {
                            exportDocument = MapChartTextDocument(text: try store.exportMapChartText())
                            isExporting = true
                        } catch {
                            alertMessage = "Export failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, .json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let data = try Data(contentsOf: url)
                let text = String(decoding: data, as: UTF8.self)
                let added = try store.importMapChartText(text)
                alertMessage = "Imported \(added) new counties from MapChart file."
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "mapchartSave__usa_counties__-1"
        ) { result in
            switch result {
            case .success:
                alertMessage = "MapChart export saved."
            case .failure(let error):
                alertMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .alert("MapChart Data", isPresented: .constant(alertMessage != nil), actions: {
            Button("OK") {
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
    }
}

private struct VisitedCountyMapView: UIViewRepresentable {
    let visitedKeys: Set<String>

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 55.0)
            ),
            animated: false
        )

        let lineOverlay = MKTileOverlay(urlTemplate: "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/export?bbox={bbox-epsg-3857}&bboxSR=3857&imageSR=3857&size=256,256&format=png32&transparent=true&f=image&layers=show:1")
        lineOverlay.canReplaceMapContent = false
        lineOverlay.minimumZ = 3
        lineOverlay.maximumZ = 20
        mapView.addOverlay(lineOverlay, level: .aboveLabels)

        context.coordinator.refreshCounties(for: mapView.region)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshFillStyles(on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VisitedCountyMapView

        private var isLoading = false
        private var loadedObjectIDs = Set<Int>()

        init(_ parent: VisitedCountyMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            refreshCounties(for: mapView.region)
        }

        func refreshCounties(for region: MKCoordinateRegion) {
            guard !isLoading else { return }
            isLoading = true

            Task {
                let fetched = await fetchCountyPolygons(in: region)
                await MainActor.run {
                    defer { self.isLoading = false }
                    guard let mapView = self.currentMapView else { return }

                    let newOverlays = fetched.filter { !self.loadedObjectIDs.contains($0.objectID) }
                    newOverlays.forEach { self.loadedObjectIDs.insert($0.objectID) }
                    mapView.addOverlays(newOverlays.map(\.polygon), level: .aboveRoads)
                    self.refreshFillStyles(on: mapView)
                }
            }
        }

        func refreshFillStyles(on mapView: MKMapView) {
            for overlay in mapView.overlays {
                if let countyPolygon = overlay as? CountyPolygon {
                    countyPolygon.isVisited = parent.visitedKeys.contains(countyPolygon.countyKey)
                }
            }

            for renderer in mapView.overlays.compactMap({ mapView.renderer(for: $0) as? MKPolygonRenderer }) {
                guard let polygon = renderer.polygon as? CountyPolygon else { continue }
                renderer.fillColor = polygon.isVisited ? UIColor.systemBlue.withAlphaComponent(0.38) : UIColor.clear
                renderer.strokeColor = UIColor.clear
            }
        }

        private weak var currentMapView: MKMapView?

        func mapViewWillStartLoadingMap(_ mapView: MKMapView) {
            currentMapView = mapView
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            currentMapView = mapView
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.9
                return renderer
            }

            if let polygon = overlay as? CountyPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = polygon.isVisited ? UIColor.systemBlue.withAlphaComponent(0.38) : UIColor.clear
                renderer.strokeColor = UIColor.clear
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        private func fetchCountyPolygons(in region: MKCoordinateRegion) async -> [FetchedCounty] {
            guard let url = Self.queryURL(for: region) else { return [] }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let objects = try MKGeoJSONDecoder().decode(data)

                var results: [FetchedCounty] = []
                for object in objects {
                    guard let feature = object as? MKGeoJSONFeature else { continue }

                    let props = (try? feature.properties.flatMap { data -> [String: Any]? in
                        let jsonObject = try JSONSerialization.jsonObject(with: data)
                        return jsonObject as? [String: Any]
                    }) ?? [:]

                    guard
                        let objectID = (props["OBJECTID"] as? NSNumber)?.intValue ?? Int(props["OBJECTID"] as? String ?? ""),
                        let state = (props["STUSAB"] as? String)?.uppercased(),
                        let name = props["NAME"] as? String
                    else {
                        continue
                    }

                    let key = Self.countyKey(stateCode: state, countyName: name)

                    for geometry in feature.geometry {
                        if let polygon = geometry as? MKPolygon {
                            let countyPolygon = CountyPolygon(from: polygon, countyKey: key)
                            results.append(FetchedCounty(objectID: objectID, polygon: countyPolygon))
                        } else if let multi = geometry as? MKMultiPolygon {
                            for polygon in multi.polygons {
                                let countyPolygon = CountyPolygon(from: polygon, countyKey: key)
                                results.append(FetchedCounty(objectID: objectID, polygon: countyPolygon))
                            }
                        }
                    }
                }
                return results
            } catch {
                return []
            }
        }

        private static func queryURL(for region: MKCoordinateRegion) -> URL? {
            let minLat = region.center.latitude - region.span.latitudeDelta * 0.7
            let maxLat = region.center.latitude + region.span.latitudeDelta * 0.7
            let minLon = region.center.longitude - region.span.longitudeDelta * 0.7
            let maxLon = region.center.longitude + region.span.longitudeDelta * 0.7

            var components = URLComponents(string: "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/State_County/MapServer/1/query")
            components?.queryItems = [
                URLQueryItem(name: "where", value: "1=1"),
                URLQueryItem(name: "outFields", value: "OBJECTID,NAME,STUSAB"),
                URLQueryItem(name: "f", value: "geojson"),
                URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
                URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
                URLQueryItem(name: "inSR", value: "4326"),
                URLQueryItem(name: "outSR", value: "4326"),
                URLQueryItem(name: "geometry", value: "\(minLon),\(minLat),\(maxLon),\(maxLat)")
            ]
            return components?.url
        }

        private static func countyKey(stateCode: String, countyName: String) -> String {
            CountyNameNormalizer.countyKey(countryCode: "US", stateCode: stateCode, countyName: countyName)
        }
    }
}

private struct MapChartTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json] }

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

private struct FetchedCounty {
    let objectID: Int
    let polygon: CountyPolygon
}

private final class CountyPolygon: MKPolygon {
    let countyKey: String
    var isVisited: Bool = false

    init(from polygon: MKPolygon, countyKey: String) {
        self.countyKey = countyKey

        let outerCoordinates = polygon.coordinates
        let interiorPolygons = polygon.interiorPolygons?.map {
            MKPolygon(coordinates: $0.coordinates, count: $0.pointCount)
        }

        super.init(coordinates: outerCoordinates, count: outerCoordinates.count, interiorPolygons: interiorPolygons)
    }
}

private extension MKPolygon {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
