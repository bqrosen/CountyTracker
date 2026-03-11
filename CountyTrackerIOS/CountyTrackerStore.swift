import Foundation
import CoreLocation

@MainActor
final class CountyTrackerStore: ObservableObject {
    @Published private(set) var visits: [CountyVisit] = []

    private let storageKey = "county_tracker_visits_v1"

    init() {
        load()
    }

    func recordVisit(from placemark: CLPlacemark, at timestamp: Date) {
        guard let countryCode = placemark.isoCountryCode?.uppercased(), countryCode == "US" else {
            return
        }
        guard let stateCode = placemark.administrativeArea?.uppercased() else { return }

        let rawCounty: String
        if let sub = placemark.subAdministrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sub.isEmpty {
            // Normal county/parish/borough — strip suffix as usual
            rawCounty = sub
        } else if let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !city.isEmpty {
            // Independent city (e.g. St. Louis City, VA independent cities)
            // Append " city" so the key matches the GeoJSON LSAD="city" polygons
            rawCounty = "\(city) city"
        } else {
            return
        }

        let countyName = CountyNameNormalizer.normalizedCountyName(rawCounty)
        upsertVisit(countyName: countyName, stateCode: stateCode, countryCode: countryCode, timestamp: timestamp, incrementVisitCount: true)
    }

    func importMapChartText(_ text: String) throws -> Int {
        let save = try MapChartSave.fromText(text)
        let uniquePaths = Set(save.allPaths)
        let timestamp = Date()

        var added = 0
        for path in uniquePaths {
            guard let parsed = MapChartPath.parse(path) else { continue }
            let countyName = CountyNameNormalizer.normalizedCountyName(parsed.countyName)
            let didAdd = upsertVisit(
                countyName: countyName,
                stateCode: parsed.stateCode,
                countryCode: "US",
                timestamp: timestamp,
                incrementVisitCount: false
            )
            if didAdd {
                added += 1
            }
        }

        return added
    }

    func exportMapChartText() throws -> String {
        let paths = visits
            .filter { $0.countryCode.uppercased() == "US" }
            .map { MapChartPath.build(countyName: $0.countyName, stateCode: $0.stateCode) }

        return try MapChartSave.fromCountyPaths(paths).toText()
    }

    func clearAll() {
        visits = []
        persist()
    }

    var totalUniqueCounties: Int {
        visits.count
    }

    var totalVisits: Int {
        visits.reduce(0) { $0 + $1.visitCount }
    }

    var totalStatesVisited: Int {
        Set(visits.map(\.stateCode)).count
    }

    @discardableResult
    private func upsertVisit(
        countyName: String,
        stateCode: String,
        countryCode: String,
        timestamp: Date,
        incrementVisitCount: Bool
    ) -> Bool {
        let lookupKey = CountyNameNormalizer.countyKey(countryCode: countryCode, stateCode: stateCode, countyName: countyName)

        if let index = visits.firstIndex(where: { $0.key == lookupKey }) {
            visits[index].lastVisitedAt = timestamp
            if incrementVisitCount {
                visits[index].visitCount += 1
            }
            persist()
            return false
        }

        visits.append(
            CountyVisit(
                countyName: countyName,
                stateCode: stateCode,
                countryCode: countryCode,
                firstVisitedAt: timestamp,
                lastVisitedAt: timestamp,
                visitCount: 1
            )
        )

        visits.sort {
            if $0.stateCode == $1.stateCode {
                return $0.countyName < $1.countyName
            }
            return $0.stateCode < $1.stateCode
        }

        persist()
        return true
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(visits)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save county visits: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            visits = try JSONDecoder().decode([CountyVisit].self, from: data)
        } catch {
            print("Failed to load county visits: \(error)")
            visits = []
        }
    }
}
