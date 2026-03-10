import Foundation
import MapKit
import UIKit

// MARK: - Bundled county boundary loader

/// Loads and caches all US county polygons and centroid annotations from
/// bundled JSON resources once per session.
///
/// The county key for each polygon is stored in `MKPolygon.title`.
/// MKPolygon uses a class-cluster pattern that prevents safe subclassing,
/// so we use the built-in `title` property instead of a custom subclass.
actor CountyBoundaryLoader {
    static let shared = CountyBoundaryLoader()
    private init() {}

    private var cachedPolygons: [MKPolygon]?
    private var cachedAnnotations: [MKPointAnnotation]?

    // MARK: Polygons

    /// Returns all ~3,200 US county polygons, loading from bundle on first call.
    /// Each polygon's `title` is set to its county key.
    func loadPolygons() async throws -> [MKPolygon] {
        if let cached = cachedPolygons { return cached }

        guard let url = Bundle.main.url(forResource: "counties", withExtension: "json") else {
            print("CountyBoundaryLoader: counties.json NOT found in bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        print("CountyBoundaryLoader: loading polygons from \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        let objects = try MKGeoJSONDecoder().decode(data)
        print("CountyBoundaryLoader: decoded \(objects.count) GeoJSON objects")

        var result: [MKPolygon] = []
        for object in objects {
            guard
                let feature   = object as? MKGeoJSONFeature,
                let propsData = feature.properties,
                let props     = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any],
                let name      = props["NAME"]   as? String,
                let stusab    = props["STUSAB"] as? String
            else { continue }

            let key = CountyNameNormalizer.countyKey(
                countryCode: "US",
                stateCode: stusab,
                countyName: name
            )

            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon {
                    polygon.title = key
                    result.append(polygon)
                } else if let multi = geometry as? MKMultiPolygon {
                    for polygon in multi.polygons {
                        polygon.title = key
                        result.append(polygon)
                    }
                }
            }
        }

        print("CountyBoundaryLoader: produced \(result.count) MKPolygon overlays")
        cachedPolygons = result
        return result
    }

    // MARK: Centroid annotations

    /// Returns one `MKPointAnnotation` per county with:
    ///   • `coordinate` = pre-computed centroid
    ///   • `title`      = display name  (e.g. "Los Angeles")
    ///   • `subtitle`   = state code    (e.g. "CA")
    func loadAnnotations() async throws -> [MKPointAnnotation] {
        if let cached = cachedAnnotations { return cached }

        guard let url = Bundle.main.url(forResource: "county_centroids", withExtension: "json") else {
            print("CountyBoundaryLoader: county_centroids.json NOT found in bundle")
            throw CocoaError(.fileNoSuchFile)
        }
        print("CountyBoundaryLoader: loading centroids from \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var result: [MKPointAnnotation] = []
        for (_, info) in dict {
            guard
                let lat   = info["lat"]   as? Double,
                let lon   = info["lon"]   as? Double,
                let name  = info["name"]  as? String,
                let state = info["state"] as? String
            else { continue }

            let ann        = MKPointAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            ann.title      = name
            ann.subtitle   = state
            result.append(ann)
        }

        print("CountyBoundaryLoader: loaded \(result.count) centroid annotations")
        cachedAnnotations = result
        return result
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

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        isEnabled       = false   // non-interactive — doesn't steal touches
        backgroundColor = .clear
        canShowCallout  = false

        label.numberOfLines = 2
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(span: Double) {
        isHidden = span > Self.hideAboveSpan
        guard !isHidden else { return }

        let name     = (annotation?.title ?? nil) ?? ""
        let fontSize = Self.fontSize(for: span)

        // Negative strokeWidth = draw fill (foregroundColor) AND outline (strokeColor).
        let attrs: [NSAttributedString.Key: Any] = [
            .font:            UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor(white: 0.08, alpha: 0.95),
            .strokeColor:     UIColor.white,
            .strokeWidth:     NSNumber(value: -2.5)
        ]
        label.attributedText = NSAttributedString(string: name, attributes: attrs)
        label.sizeToFit()

        // Cap width so long names wrap rather than running into neighbours.
        let maxWidth = fontSize * 7.0
        if label.frame.width > maxWidth {
            label.frame.size.width = maxWidth
            label.sizeToFit()
        }

        bounds       = label.bounds
        label.frame  = bounds
        centerOffset = .zero
    }

    static func fontSize(for span: Double) -> CGFloat {
        let clamped = min(max(span, maxFontSpan), minFontSpan)
        let t = (clamped - maxFontSpan) / (minFontSpan - maxFontSpan)
        return maxFontSize - CGFloat(t) * (maxFontSize - minFontSize)
    }
}
