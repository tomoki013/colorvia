import Foundation

/// Centralized ad-free entitlement state.
/// StoreKit 2 purchase checks can replace this later without changing call sites.
@MainActor
@Observable
final class AdEntitlementStore {
  static let shared = AdEntitlementStore()

  private(set) var isAdFree = false

  private init() {}

  /// Called by `PurchaseManager` when the remove-ads entitlement changes.
  func applyPurchaseState(_ owned: Bool) {
    isAdFree = owned
  }
}
