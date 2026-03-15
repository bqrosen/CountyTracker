import Foundation
import StoreKit

struct TipJarPurchaseResult {
    let message: String
    let didCompletePurchase: Bool
}

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

    var suggestedProducts: [Product] {
        products
    }

    func loadProducts() async {
        if isLoadingProducts { return }

        isLoadingProducts = true
        loadErrorMessage = nil

        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted {
                if Double($0.price) < Double($1.price) {
            }
            if products.isEmpty {
                loadErrorMessage = "No tip products found. Verify product IDs in App Store Connect."
            }
        } catch {
            loadErrorMessage = "Unable to load tip options: \(error.localizedDescription)"
        }

        isLoadingProducts = false
    }

    func purchase(product: Product) async -> TipJarPurchaseResult {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return TipJarPurchaseResult(message: "Thanks for your support!", didCompletePurchase: true)
                case .unverified:
                    return TipJarPurchaseResult(message: "Purchase could not be verified.", didCompletePurchase: false)
                }
            case .userCancelled:
                return TipJarPurchaseResult(message: "Purchase canceled.", didCompletePurchase: false)
            case .pending:
                return TipJarPurchaseResult(message: "Purchase pending approval.", didCompletePurchase: false)
            @unknown default:
                return TipJarPurchaseResult(message: "Purchase did not complete.", didCompletePurchase: false)
            }
        } catch {
            return TipJarPurchaseResult(message: "Purchase failed: \(error.localizedDescription)", didCompletePurchase: false)
        }
    }
}
