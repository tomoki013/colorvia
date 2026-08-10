import Foundation
import Observation
import StoreKit

enum StoreProduct {
  static let removeAdsID = "io.tmkch.colorvia.removeads"
}

enum PurchaseVerificationError: Error {
  case unverified
}

@MainActor
@Observable
final class PurchaseManager {
  static let shared = PurchaseManager(entitlementStore: .shared)

  private(set) var removeAdsProduct: Product?
  private(set) var isLoadingProducts = false
  private(set) var purchaseInFlight = false
  private(set) var lastErrorMessage: String?

  private let entitlementStore: AdEntitlementStore
  private var updatesTask: Task<Void, Never>?
  private var didStart = false

  init(entitlementStore: AdEntitlementStore) {
    self.entitlementStore = entitlementStore
  }

  /// Loads the product, applies any existing entitlement, and starts listening
  /// for transactions from renewals, family sharing, or other devices.
  func start() async {
    guard !didStart else { return }
    didStart = true
    updatesTask = Task { [weak self] in
      await self?.observeTransactionUpdates()
    }
    await loadProducts()
    await refreshEntitlements()
  }

  func loadProducts() async {
    guard removeAdsProduct == nil else { return }
    isLoadingProducts = true
    defer { isLoadingProducts = false }
    do {
      let products = try await Product.products(for: [StoreProduct.removeAdsID])
      removeAdsProduct = products.first
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func purchaseRemoveAds() async {
    guard let product = removeAdsProduct, !purchaseInFlight else { return }
    purchaseInFlight = true
    defer { purchaseInFlight = false }
    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verification):
        let transaction = try checkVerified(verification)
        await apply(transaction)
        await transaction.finish()
      case .userCancelled, .pending:
        break
      @unknown default:
        break
      }
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func restorePurchases() async {
    do {
      try await AppStore.sync()
    } catch {
      lastErrorMessage = error.localizedDescription
    }
    await refreshEntitlements()
  }

  private func observeTransactionUpdates() async {
    for await update in Transaction.updates {
      guard let transaction = try? checkVerified(update) else { continue }
      await apply(transaction)
      await transaction.finish()
    }
  }

  private func refreshEntitlements() async {
    var owned = false
    for await result in Transaction.currentEntitlements {
      guard let transaction = try? checkVerified(result),
        transaction.productID == StoreProduct.removeAdsID
      else { continue }
      owned = transaction.revocationDate == nil
    }
    entitlementStore.applyPurchaseState(owned)
  }

  private func apply(_ transaction: Transaction) async {
    guard transaction.productID == StoreProduct.removeAdsID else { return }
    entitlementStore.applyPurchaseState(transaction.revocationDate == nil)
  }

  private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified: throw PurchaseVerificationError.unverified
    case .verified(let value): return value
    }
  }
}
