import Foundation
import MapKit
import UIKit

// MARK: - Bundled county boundary loader

/// Holds the raw coordinate data for one polygon ring, so we can create
/// fresh MKPolygon instances for each MKMapView that requests them.
/// (An MKPolygon is a class object that can only be owned by one MKMapView
/// at a time; reusing the same instance across views causes silent failures.)
private struct PolygonRecord {
    let coordinates: [CLLocationCoordinate2D]
    let interiorRings: [[CLLocationCoordinate2D]]
    let key: String

    /// Extract coordinates from a parsed MKPolygon so we can recreate it later.
    init(polygon: MKPolygon, key: String) {
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))
        self.coordinates = coords
        self.interiorRings = (polygon.interiorPolygons ?? []).map { ring in
            var r = [CLLocationCoordinate2D](repeating: .init(), count: ring.pointCount)
            ring.getCoordinates(&r, range: NSRange(location: 0, length: ring.pointCount))
            return r
        }
        self.key = key
    }

    func makePolygon() -> MKPolygon {
        var outer = coordinates
        let holes = interiorRings.map { ring -> MKPolygon in
            var r = ring
            return MKPolygon(coordinates: &r, count: r.count)
        }
        let poly = MKPolygon(
            coordinates: &outer,
            count: outer.count,
            interiorPolygons: holes.isEmpty ? nil : holes
        )
        poly.title = key
        return poly
    }
}

/// Holds centroid data for one county annotation.
private struct AnnotationRecord {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let state: String

    func makeAnnotation() -> MKPointAnnotation {
        let ann = MKPointAnnotation()
        ann.coordinate = coordinate
        ann.title      = name
        ann.subtitle   = state
        return ann
    }
}

/// Parses bundled JSON resources once per session and vends fresh MapKit
/// objects (MKPolygon / MKPointAnnotation) on every call.
actor CountyBoundaryLoader {
    static let shared = CountyBoundaryLoader()
    private init() {}

    private var polygonRecords: [PolygonRecord]?
    private var annotationRecords: [AnnotationRecord]?
    private var borderRecords: [PolygonRecord]?
    
    static let USBorderKey = "_us_border"
    private static let maxBorderRingPoints = 6000

    // MARK: Polygons

    /// Returns freshly created MKPolygon instances for all ~3,200 US counties.
    /// Each polygon's `title` is set to its county key.
    /// Parses the JSON only once; subsequent calls create new instances from cached data.
    func loadPolygons() async throws -> [MKPolygon] {
        if polygonRecords == nil {
            polygonRecords = try await parsePolygonRecords()
        }
        return polygonRecords!.map { $0.makePolygon() }
    }

    private func parsePolygonRecords() async throws -> [PolygonRecord] {
        guard let url = Bundle.main.url(forResource: "counties", withExtension: "json") else {
            print("CountyBoundaryLoader: counties.json NOT found in bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        print("CountyBoundaryLoader: loading polygons from \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        let objects = try MKGeoJSONDecoder().decode(data)
        print("CountyBoundaryLoader: decoded \(objects.count) GeoJSON objects")

        // First pass: find (name.lowercased, stusab) pairs that have BOTH a city and a
        // county-type entry — only those need disambiguation via " city" suffix.
        var nameStateCounts: [String: Int] = [:]
        for object in objects {
            guard
                let feature   = object as? MKGeoJSONFeature,
                let propsData = feature.properties,
                let props     = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any],
                let name      = props["NAME"]   as? String,
                let stusab    = props["STUSAB"] as? String
            else { continue }
            let pairKey = "\(name.lowercased())|\(stusab.lowercased())"
            nameStateCounts[pairKey, default: 0] += 1
        }
        let collisions: Set<String> = Set(nameStateCounts.filter { $0.value > 1 }.keys)

        // Second pass: build polygon records, appending " city" only for true collisions.
        var result: [PolygonRecord] = []
        for object in objects {
            guard
                let feature   = object as? MKGeoJSONFeature,
                let propsData = feature.properties,
                let props     = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any],
                let name      = props["NAME"]   as? String,
                let stusab    = props["STUSAB"] as? String
            else { continue }

            let lsad = (props["LSAD"] as? String ?? "").lowercased()
            let pairKey = "\(name.lowercased())|\(stusab.lowercased())"
            // Only append " city" when there is a genuine name collision in the same state.
            let countyName = (lsad == "city" && collisions.contains(pairKey)) ? "\(name) city" : name

            let key = CountyNameNormalizer.countyKey(
                countryCode: "US",
                stateCode: stusab,
                countyName: countyName
            )

            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon {
                    result.append(PolygonRecord(polygon: polygon, key: key))
                } else if let multi = geometry as? MKMultiPolygon {
                    for polygon in multi.polygons {
                        result.append(PolygonRecord(polygon: polygon, key: key))
                    }
                }
            }
        }

        print("CountyBoundaryLoader: cached \(result.count) polygon records")
        return result
    }

    // MARK: Centroid annotations

    /// Returns freshly created MKPointAnnotation instances for all county centroids.
    func loadAnnotations() async throws -> [MKPointAnnotation] {
        if annotationRecords == nil {
            annotationRecords = try await parseAnnotationRecords()
        }
        return annotationRecords!.map { $0.makeAnnotation() }
    }

    private func parseAnnotationRecords() async throws -> [AnnotationRecord] {
        guard let url = Bundle.main.url(forResource: "county_centroids", withExtension: "json") else {
            print("CountyBoundaryLoader: county_centroids.json NOT found in bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        print("CountyBoundaryLoader: loading centroids from \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var result: [AnnotationRecord] = []
        for (_, info) in dict {
            guard
                let lat   = info["lat"]   as? Double,
                let lon   = info["lon"]   as? Double,
                let name  = info["name"]  as? String,
                let state = info["state"] as? String
            else { continue }

            result.append(AnnotationRecord(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                name: name,
                state: state
            ))
        }

        print("CountyBoundaryLoader: cached \(result.count) annotation records")
        return result
    }

    // MARK: US Border

    private enum BorderRegion: CaseIterable {
        case continentalUS
        case alaskaAleutians
        case hawaii
        case territories
    }

    /// Returns freshly created MKMultiPolygon overlays for the US national border,
    /// partitioned into regions (continental US, Alaska/Aleutians, Hawaii, territories).
    ///
    /// Regional partitioning avoids a single world-spanning overlay bounds (especially
    /// due to Aleutian/date-line geometry), which can cause clipping artifacts at
    /// near-maximum zoom out.
    ///
    /// Each returned overlay has title `USBorderKey` for renderer identification.
    /// Parses the GeoJSON only once; subsequent calls create new instances from cached data.
    func loadBorderPolygons() async throws -> [MKMultiPolygon] {
        if borderRecords == nil {
            borderRecords = try await parseBorderRecords()
        }
        var grouped: [BorderRegion: [MKPolygon]] = [:]
        for region in BorderRegion.allCases {
            grouped[region] = []
        }

        for record in borderRecords! {
            let polygon = record.makePolygon()
            let region = classifyBorderRegion(for: record.coordinates)
            grouped[region, default: []].append(polygon)
        }

        var result: [MKMultiPolygon] = []
        for region in BorderRegion.allCases {
            guard let polys = grouped[region], !polys.isEmpty else { continue }
            let multi = MKMultiPolygon(polys)
            multi.title = Self.USBorderKey
            result.append(multi)
        }
        return result
    }

    private func classifyBorderRegion(for coordinates: [CLLocationCoordinate2D]) -> BorderRegion {
        guard !coordinates.isEmpty else { return .territories }

        let lons = coordinates.map(\.longitude)
        let lats = coordinates.map(\.latitude)

        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0

        // Continental US (CONUS + nearshore islands)
        if minLon >= -130, maxLon <= -60, minLat >= 22, maxLat <= 52 {
            return .continentalUS
        }
        // Hawaii
        if minLon >= -162, maxLon <= -154, minLat >= 18, maxLat <= 23 {
            return .hawaii
        }
        // Alaska / Aleutians (includes polygons near +180 for date-line crossing)
        if maxLat >= 50, (maxLon >= 170 || minLon <= -130) {
            return .alaskaAleutians
        }
        // Remaining polygons: PR/VI, Guam, CNMI, AS, other territories/islands
        return .territories
    }

    private func parseBorderRecords() async throws -> [PolygonRecord] {
        guard let url = Bundle.main.url(forResource: "us_border", withExtension: "geojson") else {
            print("CountyBoundaryLoader: us_border.geojson NOT found in bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        print("CountyBoundaryLoader: loading border from \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        let objects = try MKGeoJSONDecoder().decode(data)
        print("CountyBoundaryLoader: decoded \(objects.count) border GeoJSON objects")

        var result: [PolygonRecord] = []
        for object in objects {
            guard let feature = object as? MKGeoJSONFeature else { continue }

            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon {
                    let simplified = simplifyBorderPolygonIfNeeded(polygon)
                    result.append(PolygonRecord(polygon: simplified, key: Self.USBorderKey))
                } else if let multi = geometry as? MKMultiPolygon {
                    for polygon in multi.polygons {
                        let simplified = simplifyBorderPolygonIfNeeded(polygon)
                        result.append(PolygonRecord(polygon: simplified, key: Self.USBorderKey))
                    }
                }
            }
        }

        print("CountyBoundaryLoader: cached \(result.count) border polygon records")
        return result
    }

    private func simplifyBorderPolygonIfNeeded(_ polygon: MKPolygon) -> MKPolygon {
        var outer = [CLLocationCoordinate2D](repeating: .init(), count: polygon.pointCount)
        polygon.getCoordinates(&outer, range: NSRange(location: 0, length: polygon.pointCount))
        outer = downsampleRingIfNeeded(outer, maxPoints: Self.maxBorderRingPoints)

        let holes: [MKPolygon]? = polygon.interiorPolygons?.map { hole in
            var holeCoords = [CLLocationCoordinate2D](repeating: .init(), count: hole.pointCount)
            hole.getCoordinates(&holeCoords, range: NSRange(location: 0, length: hole.pointCount))
            holeCoords = downsampleRingIfNeeded(holeCoords, maxPoints: Self.maxBorderRingPoints)
            return MKPolygon(coordinates: &holeCoords, count: holeCoords.count)
        }

        return MKPolygon(
            coordinates: &outer,
            count: outer.count,
            interiorPolygons: (holes?.isEmpty ?? true) ? nil : holes
        )
    }

    private func downsampleRingIfNeeded(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints, maxPoints >= 4 else { return coordinates }

        let isClosed = coordinates.first?.latitude == coordinates.last?.latitude
            && coordinates.first?.longitude == coordinates.last?.longitude

        let base = isClosed ? Array(coordinates.dropLast()) : coordinates
        guard base.count > maxPoints else { return coordinates }

        let targetCount = maxPoints - (isClosed ? 1 : 0)
        let step = Double(base.count - 1) / Double(targetCount - 1)
        var sampled: [CLLocationCoordinate2D] = []
        sampled.reserveCapacity(maxPoints)

        for i in 0..<targetCount {
            let idx = Int((Double(i) * step).rounded())
            sampled.append(base[min(idx, base.count - 1)])
        }

        if isClosed, let first = sampled.first {
            sampled.append(first)
        }
        return sampled
    }
}

// MARK: - County label annotation view

/// A non-interactive map annotation view that displays a county name as
/// outlined text. Call `update(span:)` whenever the map's latitudeDelta
/// changes to re-scale the font and show/hide the label.
final class CountyLabelAnnotationView: MKAnnotationView {

    // Zoom thresholds (map latitudeDelta in degrees)
    static let hideAboveSpan: Double  = 7.0
    static let maxFontSpan:   Double  = 0.3    // fully zoomed in  → largest font
    static let minFontSpan:   Double  = 7.0    // just before hide → smallest font
    static let maxFontSize:   CGFloat = 14
    static let minFontSize:   CGFloat = 7

    private let label = UILabel()
    private var themeColor: UIColor = UIColor(red: 191/255, green: 97/255, blue: 106/255, alpha: 1.0)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        isEnabled       = false   // non-interactive — doesn't steal touches
        backgroundColor = .clear
        canShowCallout  = false

        label.numberOfLines = 1
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setThemeColor(_ color: UIColor) {
        themeColor = color
    }

    func update(span: Double) {
        isHidden = span > Self.hideAboveSpan
        guard !isHidden else { return }

        let name     = (annotation?.title ?? nil) ?? ""
        let state    = (annotation?.subtitle ?? nil) ?? ""
        let label_text = state.isEmpty ? name : "\(name), \(state)"
        let fontSize = Self.fontSize(for: span)

        // Negative strokeWidth = draw fill (foregroundColor) AND outline (strokeColor).
        let attrs: [NSAttributedString.Key: Any] = [
            .font:            UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: themeColor
        ]
        label.attributedText = NSAttributedString(string: label_text, attributes: attrs)
        updateShadow()
        label.sizeToFit()

        bounds       = label.bounds
        label.frame  = bounds
        centerOffset = .zero
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func updateShadow() {
        // Resolve systemBackground against the current trait so the halo colour
        // is white in light mode and near-black in dark mode.
        let halo = UIColor.systemBackground.resolvedColor(with: traitCollection)
        label.layer.shadowColor   = halo.cgColor
        label.layer.shadowOffset  = .zero
        label.layer.shadowRadius  = 2.5
        label.layer.shadowOpacity = 0.85
        label.layer.masksToBounds = false
    }

    static func fontSize(for span: Double) -> CGFloat {
        let clamped = min(max(span, maxFontSpan), minFontSpan)
        let t = (clamped - maxFontSpan) / (minFontSpan - maxFontSpan)
        return maxFontSize - CGFloat(t) * (maxFontSize - minFontSize)
    }
}
