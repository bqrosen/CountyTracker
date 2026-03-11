import Foundation

enum CountyNameNormalizer {
    static func normalizedCountyName(_ value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let suffixes = [" County", " Parish", " Borough", " Census Area", " Municipality"]
        for suffix in suffixes {
            if text.lowercased().hasSuffix(suffix.lowercased()) {
                text = String(text.dropLast(suffix.count))
                break
            }
        }

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
        return "\(countryCode)-\(code)-\(normalizedCountyName(countyName))".lowercased()
    }

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
