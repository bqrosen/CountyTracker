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
        "\(countryCode)-\(stateCode)-\(normalizedCountyName(countyName))".lowercased()
    }

    static func mapChartToken(fromCountyName countyName: String) -> String {
        normalizedCountyName(countyName).replacingOccurrences(of: " ", with: "_")
    }

    static func countyName(fromMapChartToken token: String) -> String {
        token.replacingOccurrences(of: "_", with: " ")
    }
}
