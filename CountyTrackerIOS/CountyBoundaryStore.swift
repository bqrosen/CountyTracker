import Foundation
import MapKit
import CoreLocation

// MARK: - Bundled county boundary loader

/// Loads and caches all US county polygons from the bundled `counties.geojson`
/// once per app session.  Subsequent callers receive the same cached array.
///
/// The county key for each polygon is stored in `MKPolygon.title`.
/// MKPolygon uses a class-cluster pattern that prevents safe subclassing,
/// so we use the built-in `title` property instead of a custom subclass.
actor CountyBoundaryLoader {
    static let shared = CountyBoundaryLoader()
    private init() {}

    private var cachedPolygons: [MKPolygon]?

    /// Returns all ~3,200 US county polygons, loading from bundle on first call.
    /// Each polygon's `title` is set to its county key.
    func loadPolygons() async throws -> [MKPolygon] {
        if let cached = cachedPolygons { return cached }

        guard let url = Bundle.main.url(forResource: "counties", withExtension: "geojson") else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try Data(contentsOf: url)
        let objects = try MKGeoJSONDecoder().decode(data)

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

            // MKGeoJSONDecoder already returns MKPolygon / MKMultiPolygon instances.
            // Just stamp the county key onto the title — no subclassing needed.
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

        cachedPolygons = result
        return result
    }
}
