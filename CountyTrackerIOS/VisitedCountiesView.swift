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

        Task {
            do {
                let polygons = try await CountyBoundaryLoader.shared.loadPolygons()
                await MainActor.run {
                    mapView.addOverlays(polygons, level: .aboveRoads)
                }
            } catch {
                print("VisitedCountyMapView: failed to load county polygons – \(error)")
            }
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshFillStyles(on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VisitedCountyMapView

        init(_ parent: VisitedCountyMapView) {
            self.parent = parent
        }

        func refreshFillStyles(on mapView: MKMapView) {
            let visited = parent.visitedKeys
            for renderer in mapView.overlays.compactMap({ mapView.renderer(for: $0) as? MKPolygonRenderer }) {
                let isVisited = visited.contains(renderer.polygon.title ?? "")
                renderer.fillColor = isVisited
                    ? UIColor.systemBlue.withAlphaComponent(0.38)
                    : UIColor.clear
                renderer.strokeColor = UIColor.clear
                renderer.setNeedsDisplay()
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let isVisited = parent.visitedKeys.contains(polygon.title ?? "")
                renderer.fillColor = isVisited
                    ? UIColor.systemBlue.withAlphaComponent(0.38)
                    : UIColor.clear
                renderer.strokeColor = UIColor.clear
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
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
