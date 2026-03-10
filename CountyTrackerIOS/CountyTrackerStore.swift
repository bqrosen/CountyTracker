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

        guard
            let rawCounty = placemark.subAdministrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawCounty.isEmpty,
            let stateCode = placemark.administrativeArea?.uppercased()
        else {
            return
        }

        let countyName = normalizeCountyName(rawCounty)
        let lookupKey = "\(countryCode)-\(stateCode)-\(countyName)".lowercased()

        if let index = visits.firstIndex(where: { $0.key == lookupKey }) {
            visits[index].lastVisitedAt = timestamp
            visits[index].visitCount += 1
        } else {
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
        }

        visits.sort {
            if $0.stateCode == $1.stateCode {
                return $0.countyName < $1.countyName
            }
            return $0.stateCode < $1.stateCode
        }

        persist()
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

    private func normalizeCountyName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: " County", with: "")
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
