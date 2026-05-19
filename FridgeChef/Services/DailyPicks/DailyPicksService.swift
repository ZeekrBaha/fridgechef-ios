import Foundation
import Combine

/// Cached, once-per-day AI recipe-title suggestions for the catalog cards.
/// Lives in UserDefaults — tiny payload (~120 bytes), no Core Data needed.
@MainActor
protocol DailyPicksService: AnyObject {
    /// Latest known picks. Nil if no fetch has ever succeeded.
    var current: DailyPicks? { get }

    /// Fires whenever `current` changes (including initial load from cache).
    var publisher: AnyPublisher<DailyPicks?, Never> { get }

    /// Fetch fresh picks if the cached value is from a previous calendar day
    /// (or missing entirely). Never throws — failures keep stale value.
    func refreshIfStale() async
}

@MainActor
final class LiveDailyPicksService: DailyPicksService {

    static let cacheKey = "DailyPicksService.cache"

    private let client: OpenAIClientProtocol
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let subject: CurrentValueSubject<DailyPicks?, Never>

    init(client: OpenAIClientProtocol,
         defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.client = client
        self.defaults = defaults
        self.calendar = calendar

        // Load from cache on init so the publisher fires the cached value
        // before any network call.
        let loaded: DailyPicks?
        if let data = defaults.data(forKey: Self.cacheKey),
           let decoded = try? JSONDecoder().decode(DailyPicks.self, from: data) {
            loaded = decoded
        } else {
            loaded = nil
        }
        self.subject = CurrentValueSubject(loaded)
    }

    var current: DailyPicks? { subject.value }

    var publisher: AnyPublisher<DailyPicks?, Never> {
        subject.eraseToAnyPublisher()
    }

    func refreshIfStale() async {
        if !isStale(subject.value) { return }
        do {
            let fresh = try await client.dailyPicks()
            if let encoded = try? JSONEncoder().encode(fresh) {
                defaults.set(encoded, forKey: Self.cacheKey)
            }
            subject.send(fresh)
        } catch {
            // Swallow — daily picks must never break the UI.
        }
    }

    private func isStale(_ picks: DailyPicks?) -> Bool {
        guard let picks else { return true }
        let savedDay = calendar.startOfDay(for: picks.savedAt)
        let today = calendar.startOfDay(for: Date())
        return savedDay != today
    }
}
