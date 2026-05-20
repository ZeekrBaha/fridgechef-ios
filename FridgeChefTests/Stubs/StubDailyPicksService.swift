import Foundation
import Combine
@testable import FridgeChef

@MainActor
final class StubDailyPicksService: DailyPicksService {
    private let subject: CurrentValueSubject<DailyPicks?, Never>
    private(set) var refreshCallCount = 0

    init(initial: DailyPicks? = nil) {
        self.subject = CurrentValueSubject(initial)
    }

    var current: DailyPicks? { subject.value }
    var publisher: AnyPublisher<DailyPicks?, Never> { subject.eraseToAnyPublisher() }

    func refreshIfStale() async {
        refreshCallCount += 1
    }

    /// Test helper — emit a value as if a fresh fetch landed.
    func emit(_ picks: DailyPicks?) {
        subject.send(picks)
    }
}
