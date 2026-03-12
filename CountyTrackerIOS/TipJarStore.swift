import Foundation
import StoreKit

@MainActor
final class TipJarStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var loadErrorMessage: String?

    private let productIDs = [
        "com.bqrosen.CountyTracker.tip.099",
        "com.bqrosen.CountyTracker.tip.499",
        "com.bqrosen.CountyTracker.tip.999"
    ]

    private let suggestedAmounts: [Decimal] = [0.99, 4.99, 9.99]

    var suggestedProducts: [Product] {
        if products.isEmpty { return [] }

        var chosen: [Product] = []
        var usedIDs = Set<String>()

        for amount in suggestedAmounts {
            if let product = closestProduct(to: amount, excluding: usedIDs) {
                chosen.append(product)
                usedIDs.insert(product.id)
            }
        }

        return chosen
    }

    func loadProducts() async {
        if isLoadingProducts { return }

        isLoadingProducts = true
        loadErrorMessage = nil

        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted {
                NSDecimalNumber(decimal: $0.price).doubleValue < NSDecimalNumber(decimal: $1.price).doubleValue
            }
            if products.isEmpty {
                loadErrorMessage = "No tip products found. Verify product IDs in App Store Connect."
            }
        } catch {
            loadErrorMessage = "Unable to load tip options: \(error.localizedDescription)"
        }

        isLoadingProducts = false
    }

    func purchase(product: Product) async -> String {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return "Thanks for your support!"
                case .unverified:
                    return "Purchase could not be verified."
                }
            case .userCancelled:
                return "Purchase canceled."
            case .pending:
                return "Purchase pending approval."
            @unknown default:
                return "Purchase did not complete."
            }
        } catch {
            return "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func closestProduct(to amount: Decimal, excluding excludedIDs: Set<String>) -> Product? {
        products
            .filter { !excludedIDs.contains($0.id) }
            .min { lhs, rhs in
                let lhsDiff = abs(NSDecimalNumber(decimal: lhs.price).doubleValue - NSDecimalNumber(decimal: amount).doubleValue)
                let rhsDiff = abs(NSDecimalNumber(decimal: rhs.price).doubleValue - NSDecimalNumber(decimal: amount).doubleValue)
                return lhsDiff < rhsDiff
            }
    }
}
