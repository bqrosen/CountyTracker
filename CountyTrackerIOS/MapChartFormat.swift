import Foundation

struct MapChartSave: Codable {
    var groups: [String: MapChartGroup]
    var title: String
    var hidden: [String]
    var background: String
    var borders: String

    static func fromText(_ text: String) throws -> MapChartSave {
        let data = Data(text.utf8)
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
                "#cc3333": MapChartGroup(div: "#box1", label: "", paths: paths.sorted())
            ],
            title: "",
            hidden: [],
            background: "#ffffff",
            borders: "#000000"
        )
    }
}

struct MapChartGroup: Codable {
    var div: String
    var label: String
    var paths: [String]
}

enum MapChartPath {
    static func parse(_ value: String) -> (countyName: String, stateCode: String)? {
        let parts = value.components(separatedBy: "__")
        guard parts.count == 2 else { return nil }

        let token = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let state = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !token.isEmpty, state.count == 2 else { return nil }
        return (CountyNameNormalizer.countyName(fromMapChartToken: token), state)
    }

    static func build(countyName: String, stateCode: String) -> String {
        "\(CountyNameNormalizer.mapChartToken(fromCountyName: countyName))__\(stateCode.uppercased())"
    }
}
