import Foundation
import Security

/// A Pro feature the learner can use during the free trial; the end-of-trial summary counts them.
public enum TrialFeature: String, Codable, Sendable, CaseIterable {
    case archive, personalPuzzle
}

/// The free trial: everything is open for 72 hours from the first launch, no card, no store.
///
/// The state lives in the Keychain (a reinstall does not start a new trial). The clock cannot
/// give the trial more time: `lastSeen` only moves forward and the trial is measured against
/// the later of `now` and `lastSeen`.
public struct ReverseTrial: Codable, Equatable, Sendable {
    public static let duration: TimeInterval = 72 * 3600

    public var startedAt: Date
    /// The latest time the app has ever seen; setting the clock back does not undo it.
    public var lastSeen: Date
    /// `trial.ended` has been sent.
    public var endedReported = false
    /// The end-of-trial summary has been shown (or skipped because the learner bought Pro).
    public var summaryShown = false
    /// Uses of each Pro feature while the trial ran, by `TrialFeature` raw value.
    public var usage: [String: Int] = [:]
    /// "feature:key" of uses already counted once (the same archive puzzle opened twice is one).
    public var countedKeys: [String] = []

    public init(startedAt: Date) {
        self.startedAt = startedAt
        self.lastSeen = startedAt
    }

    public var endsAt: Date { startedAt.addingTimeInterval(Self.duration) }

    /// `now` as the trial sees it: never earlier than the latest time seen.
    public func effectiveNow(_ now: Date) -> Date { max(now, lastSeen) }

    /// Open for the first 72 hours; at exactly 72 hours it is over.
    public func isActive(now: Date) -> Bool { effectiveNow(now) < endsAt }

    public func remaining(now: Date) -> TimeInterval { max(0, endsAt.timeIntervalSince(effectiveNow(now))) }

    /// Whole days left for "Deneme: N gün kaldı": 3 at the start, 1 for the last day, 0 when over.
    public func daysLeft(now: Date) -> Int { Int((remaining(now: now) / 86_400).rounded(.up)) }

    public func uses(_ feature: TrialFeature) -> Int { usage[feature.rawValue] ?? 0 }
}

/// Where the trial state is kept.
public protocol TrialStore: AnyObject, Sendable {
    func load() -> TrialStoreResult
    func save(_ trial: ReverseTrial)
}

public enum TrialStoreResult: Equatable, Sendable {
    case found(ReverseTrial)
    /// Nothing stored: this is a first launch.
    case absent
    /// The store could not be read (for example a locked Keychain); not the same as absent.
    case unavailable
}

/// What `ReverseTrialManager.refresh` found.
public struct TrialSnapshot: Equatable, Sendable {
    /// nil when the store could not be read; the trial then grants nothing until it can be.
    public var trial: ReverseTrial?
    public var now: Date
    /// This call started the trial (first launch): send `trial.started`.
    public var justStarted = false
    /// This call saw the trial end for the first time: send `trial.ended`.
    public var justEnded = false

    public init(trial: ReverseTrial?, now: Date) {
        self.trial = trial
        self.now = now
    }

    public var isActive: Bool { trial?.isActive(now: now) ?? false }
    public var hasEnded: Bool { trial.map { !$0.isActive(now: now) } ?? false }
    public var daysLeft: Int { trial?.daysLeft(now: now) ?? 0 }
    /// The summary is due: the trial is over and has not been shown yet.
    public var summaryDue: Bool { hasEnded && !(trial?.summaryShown ?? true) }
}

/// Starts, reads and updates the trial state in a `TrialStore`.
public final class ReverseTrialManager: @unchecked Sendable {
    private let store: TrialStore
    private let lock = NSLock()

    public init(store: TrialStore) { self.store = store }

    /// Reads the state at `now`, starting the trial on the first call ever, and moves
    /// `lastSeen` forward. Call at launch and whenever the app comes to the foreground.
    @discardableResult
    public func refresh(now: Date) -> TrialSnapshot {
        lock.lock(); defer { lock.unlock() }
        var trial: ReverseTrial
        var snapshot = TrialSnapshot(trial: nil, now: now)
        switch store.load() {
        case .unavailable:
            return snapshot
        case .absent:
            trial = ReverseTrial(startedAt: now)
            snapshot.justStarted = true
        case .found(let found):
            trial = found
        }
        trial.lastSeen = max(trial.lastSeen, now)
        if !trial.isActive(now: now), !trial.endedReported {
            trial.endedReported = true
            snapshot.justEnded = true
        }
        store.save(trial)
        snapshot.trial = trial
        return snapshot
    }

    /// Counts one use of a Pro feature while the trial is running; ignored after it.
    /// With a `key`, the same key counts once (for example an archive puzzle's day).
    public func note(_ feature: TrialFeature, key: String? = nil, by count: Int = 1, now: Date) {
        lock.lock(); defer { lock.unlock() }
        guard case .found(var trial) = store.load(), trial.isActive(now: now) else { return }
        if let key {
            let id = "\(feature.rawValue):\(key)"
            guard !trial.countedKeys.contains(id) else { return }
            trial.countedKeys.append(id)
        }
        trial.usage[feature.rawValue, default: 0] += count
        trial.lastSeen = max(trial.lastSeen, now)
        store.save(trial)
    }

    /// The summary will not be shown again.
    public func markSummaryShown() {
        lock.lock(); defer { lock.unlock() }
        guard case .found(var trial) = store.load() else { return }
        trial.summaryShown = true
        store.save(trial)
    }
}

/// Holds the state in memory. For tests and previews.
public final class MemoryTrialStore: TrialStore, @unchecked Sendable {
    public var trial: ReverseTrial?
    public var unavailable = false

    public init(_ trial: ReverseTrial? = nil) { self.trial = trial }

    public func load() -> TrialStoreResult {
        if unavailable { return .unavailable }
        return trial.map(TrialStoreResult.found) ?? .absent
    }

    public func save(_ trial: ReverseTrial) { self.trial = trial }
}

/// The Keychain: survives deleting and reinstalling the app. Readable after the first unlock,
/// so a background launch on a locked phone neither fails nor restarts the trial.
public final class KeychainTrialStore: TrialStore, @unchecked Sendable {
    private let service: String
    private let account = "reverse-trial"

    public init(service: String = "com.kelimewidget.reverse-trial") { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    public func load() -> TrialStoreResult {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return .absent }
        guard status == errSecSuccess, let data = item as? Data else { return .unavailable }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let trial = try? decoder.decode(ReverseTrial.self, from: data) else { return .unavailable }
        return .found(trial)
    }

    public func save(_ trial: ReverseTrial) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(trial) else { return }
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
