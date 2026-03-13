import Foundation

struct MapChartSave: Codable {
    var groups: [String: MapChartGroup]
    var title: String?
    var hidden: [String]?
    var background: String?
    var borders: String?

    static func fromText(_ text: String) throws -> MapChartSave {
        // Strip leading BOM or whitespace
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
        guard let data = stripped.data(using: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return try JSONDecoder().decode(MapChartSave.self, from: data)
    }

    func toText() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    var allPaths: [String] {
        groups.values.flatMap(\.paths)
    }

    static func fromCountyPaths(_ paths: [String]) -> MapChartSave {
        MapChartSave(
            groups: [
                "#cc3333": MapChartGroup(div: nil, label: "", paths: paths.sorted())
            ],
            title: "",
            hidden: [],
            background: "#ffffff",
            borders: "#000000"
        )
    }
}

struct MapChartGroup: Codable {
    var div: String?
    var label: String
    var paths: [String]
}

enum MapChartPath {
    /// Extract (countyName, stateCode) from a MapChart path token.
    /// Uses a regex to find the `__XX` state code suffix so that county
    /// names containing `__` (e.g. `St__Louis__MO`) are handled correctly.
    static func parse(_ value: String) -> (countyName: String, stateCode: String)? {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        if let alias = MapChartTemplateOverrides.parseAliases[s] {
            return alias
        }

        // Match the last __ followed by exactly 2 uppercase letters at end of string
        guard let range = s.range(of: #"__([A-Z]{2})$"#, options: .regularExpression) else {
            return nil
        }
        let stateCode = String(s[range].dropFirst(2)) // drop leading "__"
        let token = String(s[s.startIndex ..< range.lowerBound])
        guard token.count >= 1, stateCode.count == 2 else { return nil }

        // Convert token to county name: collapse all underscore runs to a single space
        let raw = token.replacingOccurrences(of: #"_+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if the raw token explicitly carries a " Co" suffix (MapChart's way
        // of marking the county side of a name collision, e.g. "St Louis Co" vs "St Louis").
        let hasCoSuffix = raw.lowercased().hasSuffix(" co")

        var name = CountyNameNormalizer.normalizedCountyName(raw) // strips " co", " county" etc.
        guard !name.isEmpty else { return nil }

        // DC: MapChart uses "Washington" but GeoJSON uses "District of Columbia"
        name = CountyNameNormalizer.canonicalizeDC(name: name, state: stateCode)

        // For collision pairs (same name exists as both city and county in the same state),
        // if there is NO explicit " Co" suffix this is the city variant.
        if !hasCoSuffix {
            let collision = CountyNameNormalizer.CityCollision(name.lowercased(), stateCode.uppercased())
            if CountyNameNormalizer.cityCountyCollisions.contains(collision) {
                name = name + " city"
            }
        }

        return (name, stateCode)
    }

    static func build(countyName: String, stateCode: String) -> String {
        let key = CountyNameNormalizer.countyKey(
            countryCode: "US",
            stateCode: stateCode,
            countyName: countyName
        )
        if let templatePath = MapChartTemplateOverrides.pathByCountyKey[key] {
            return templatePath
        }
        return "\(CountyNameNormalizer.mapChartToken(fromCountyName: countyName))__\(stateCode.uppercased())"
    }
}
