import Foundation

struct CountyVisit: Codable, Identifiable, Hashable {
    let id: UUID
    let countyName: String
    let stateCode: String
    let countryCode: String
    var firstVisitedAt: Date
    var lastVisitedAt: Date
    var visitCount: Int

    init(
        id: UUID = UUID(),
        countyName: String,
        stateCode: String,
        countryCode: String,
        firstVisitedAt: Date,
        lastVisitedAt: Date,
        visitCount: Int
    ) {
        self.id = id
        self.countyName = countyName
        self.stateCode = stateCode
        self.countryCode = countryCode
        self.firstVisitedAt = firstVisitedAt
        self.lastVisitedAt = lastVisitedAt
        self.visitCount = visitCount
    }

    var key: String {
        CountyNameNormalizer.countyKey(countryCode: countryCode, stateCode: stateCode, countyName: countyName)
    }

    var displayName: String {
        "\(countyName), \(stateCode)"
    }
}
