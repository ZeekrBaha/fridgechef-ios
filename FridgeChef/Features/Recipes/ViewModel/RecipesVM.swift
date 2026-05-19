import Foundation
import Combine

@MainActor
final class RecipesVM {

    struct Group: Equatable {
        let title: String
        let items: [RecipeBatch]
    }

    @Published private(set) var groups: [Group] = []

    let store: RecipeStoreProtocol
    private let calendar: Calendar
    private let now: () -> Date
    private var notificationToken: NSObjectProtocol?

    init(store: RecipeStoreProtocol,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.store = store
        self.calendar = calendar
        self.now = now
        notificationToken = NotificationCenter.default.addObserver(
            forName: .recipesDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    deinit { if let t = notificationToken { NotificationCenter.default.removeObserver(t) } }

    func load() async {
        let batches = (try? await store.allBatches()) ?? []
        groups = Self.group(batches: batches, calendar: calendar, now: now())
    }

    static func group(batches: [RecipeBatch], calendar: Calendar, now: Date) -> [Group] {
        guard !batches.isEmpty else { return [] }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!

        var buckets: [String: [RecipeBatch]] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for batch in batches {
            let key: String
            if batch.createdAt >= startOfToday {
                key = "TODAY"
            } else if batch.createdAt >= startOfYesterday {
                key = "YESTERDAY"
            } else if batch.createdAt >= startOfWeek {
                key = "THIS WEEK"
            } else {
                key = monthFormatter.string(from: batch.createdAt).uppercased()
            }
            buckets[key, default: []].append(batch)
        }

        let ordering = ["TODAY", "YESTERDAY", "THIS WEEK"]
        var groups: [Group] = []
        for key in ordering where buckets[key] != nil {
            groups.append(Group(title: key, items: buckets[key]!))
        }
        let months = buckets.keys.filter { !ordering.contains($0) }
        let monthsSorted = months.sorted { lhs, rhs in
            (buckets[lhs]?.first?.createdAt ?? .distantPast) > (buckets[rhs]?.first?.createdAt ?? .distantPast)
        }
        for m in monthsSorted { groups.append(Group(title: m, items: buckets[m]!)) }
        return groups
    }
}
