import Foundation

enum CountyNameNormalizer {
    /// (normalized name, 2-letter state code) pairs where both an independent
    /// city AND a county with the same name exist in the same state.
    static let cityCountyCollisions: Set<CityCollision> = [
        CityCollision("st louis", "MO"),
        CityCollision("baltimore", "MD"),
        CityCollision("fairfax",   "VA"),
        CityCollision("franklin",  "VA"),
        CityCollision("richmond",  "VA"),
        CityCollision("roanoke",   "VA"),
    ]

    struct CityCollision: Hashable {
        let name: String  // already normalized (lowercase, no suffix)
        let state: String // 2-letter uppercase
        init(_ name: String, _ state: String) {
            self.name = name
            self.state = state
        }
    }

    /// MapChart stores DC as "Washington, DC" but the GeoJSON names it
    /// "District of Columbia".  Map any unrecognised DC name to the canonical form.
    static func canonicalizeDC(name: String, state: String) -> String {
        guard state.uppercased() == "DC" else { return name }
        return "District of Columbia"
    }
    static func normalizedCountyName(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let suffixes = [" County", " Parish", " Borough", " Census Area", " Municipality", " Planning Region", " Co"]
        for suffix in suffixes {
            if text.lowercased().hasSuffix(suffix.lowercased()) {
                text = String(text.dropLast(suffix.count))
                break
            }
        }

        // Fold accented characters to their ASCII base (ñ→n, é→e, í→i, etc.)
        text = text.applyingTransform(.stripDiacritics, reverse: false) ?? text

        let filteredScalars = text.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }

        let collapsed = String(filteredScalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed
    }

    static func countyKey(countryCode: String, stateCode: String, countyName: String) -> String {
        let code = stateAbbreviation(for: stateCode) ?? stateCode
        let canonical = canonicalCountyName(normalizedCountyName(countyName), stateCode: code)
        return "\(countryCode)-\(code)-\(canonical)".lowercased()
    }

    private static func canonicalCountyName(_ normalizedName: String, stateCode: String) -> String {
        let state = stateCode.uppercased()
        let lookup = "\(state)|\(normalizedName.lowercased())"
        return canonicalCountyNameByStateAndName[lookup] ?? normalizedName
    }

    private static let canonicalCountyNameByStateAndName: [String: String] = [
        "VI|st croix": "Saint Croix",
        "VI|st john": "Saint John",
        "VI|st thomas": "Saint Thomas",
        "AK|wade hampton": "Kusilvak",
        "AK|southeast fairbanks": "SE Fairbanks",
        "AK|chugach": "Copper River",
        "SD|shannon": "Oglala Lakota",
        "LA|la salle": "LaSalle",
        "IL|lasalle": "La Salle",
        "NM|do a ana": "Dona Ana",
        "MO|ste genevieve": "Sainte Genevieve",
    ]

    /// Convert a full state name (e.g. "Missouri") to its 2-letter code ("MO").
    /// If the input is already a 2-letter code, returns it as-is.
    static func stateAbbreviation(for input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 2 { return trimmed.uppercased() }
        return stateNameToCode[trimmed.lowercased()]
    }

    private static let stateNameToCode: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
        "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
        "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
        "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
        "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
        "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
        "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
        "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
        "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
        "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
        "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC",
        "puerto rico": "PR", "guam": "GU", "american samoa": "AS",
        "u.s. virgin islands": "VI", "northern mariana islands": "MP",
    ]

    static func mapChartToken(fromCountyName countyName: String) -> String {
        normalizedCountyName(countyName).replacingOccurrences(of: " ", with: "_")
    }

    static func countyName(fromMapChartToken token: String) -> String {
        token.replacingOccurrences(of: "_", with: " ")
    }
}
