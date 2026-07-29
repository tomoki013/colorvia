import Foundation

/// Centralized ad-free entitlement state.
/// StoreKit 2 purchase checks can replace this later without changing call sites.
@MainActor
@Observable
final class AdEntitlementStore {
  static let shared = AdEntitlementStore()

  private(set) var isAdFree = false

  private init() {}

  /// Test / future StoreKit hook. Production remains `false` until purchase is wired.
  func setAdFreeForTesting(_ value: Bool) {
    isAdFree = value
  }
}
