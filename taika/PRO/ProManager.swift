//
//  ProManager.swift
//  taika
//
//  Created by product on 13.12.2025.
//

import Foundation
import Combine

// MARK: - Pro Feature Gates

enum ProFeature: String, CaseIterable {
    case dailyPicksExtra
    case unlimitedSessions
    case aiAdvanced
}

// MARK: - Pro Tier

enum ProTier: String {
    case none
    case pro
}

// MARK: - Pro Entitlement Source

enum ProEntitlementSource {
    case none
    case localReceipt
    case server
    case debug
}

// MARK: - Pro Manager

@MainActor
final class ProManager: ObservableObject {

    static let shared = ProManager()

    // MARK: Published State

    @Published private(set) var isPro: Bool = false
    @Published private(set) var tier: ProTier = .none
    @Published private(set) var source: ProEntitlementSource = .none

    // MARK: Debug Override

    private static let debugOverrideKey = "pro.debug.override"

    /// nil = no override, true/false = force entitlement (debug only)
    @Published private(set) var debugOverride: Bool? = UserDefaults.standard.object(forKey: ProManager.debugOverrideKey) as? Bool

    // MARK: Dependencies

    private var cancellables = Set<AnyCancellable>()
    private var session: UserSession?

    // MARK: Init

    private init() {}

    // MARK: Lifecycle

    /// Call once when user session becomes available (login / app start)
    func start(session: UserSession) {
        self.session = session
        bindSession(session)
        refreshEntitlement()
    }

    /// Call on logout
    func reset() {
        cancellables.removeAll()
        session = nil
        setPro(false, tier: .none, source: .none)
    }

    // MARK: Session Binding

    private func bindSession(_ session: UserSession) {
        // listen to server-driven flags if they exist
        session.$isProFromServer
            .removeDuplicates()
            .sink { [weak self] serverFlag in
                guard let self else { return }
                // if debug override is active, do not let server updates replace it
                guard self.debugOverride == nil else {
                    self.refreshEntitlement()
                    return
                }
                if let serverFlag {
                    self.setPro(serverFlag, tier: serverFlag ? .pro : .none, source: .server)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Entitlement

    /// Recalculate PRO entitlement (StoreKit receipt / server flags)
    func refreshEntitlement() {
        // priority:
        // 1) debug override (if set)
        // 2) server flag (if present)
        // 3) local receipt (StoreKit)
        // 4) fallback to none

        if let forced = debugOverride {
            setPro(forced, tier: forced ? .pro : .none, source: .debug)
            return
        }

        if let serverFlag = session?.isProFromServer {
            setPro(serverFlag, tier: serverFlag ? .pro : .none, source: .server)
            return
        }

        // TODO: integrate StoreKit 2 receipt check
        // For now: keep current state
    }

    // MARK: Debug Control

    func setDebugOverride(_ enabled: Bool?) {
        debugOverride = enabled
        if let enabled {
            UserDefaults.standard.set(enabled, forKey: ProManager.debugOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ProManager.debugOverrideKey)
        }
        refreshEntitlement()
    }

    func setDebugPro(_ enabled: Bool) {
        setDebugOverride(enabled)
    }

    func clearDebugOverride() {
        setDebugOverride(nil)
    }

    // MARK: Feature Gates

    func can(_ feature: ProFeature) -> Bool {
        guard isPro else { return false }

        switch feature {
        case .dailyPicksExtra:
            return true
        case .unlimitedSessions:
            return true
        case .aiAdvanced:
            return tier == .pro
        }
    }

    // MARK: StoreKit (stubs)

    func purchasePro() async throws {
        // TODO: StoreKit 2 purchase flow
        // on success -> setPro(true, tier: .pro, source: .localReceipt)
    }

    func restorePurchases() async throws {
        // TODO: StoreKit 2 restore flow
    }

    // MARK: Internal State

    private func setPro(_ enabled: Bool, tier: ProTier, source: ProEntitlementSource) {
        self.isPro = enabled
        self.tier = tier
        self.source = source
    }
}
