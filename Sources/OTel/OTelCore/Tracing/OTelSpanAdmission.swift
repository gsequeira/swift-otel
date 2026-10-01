// Isolated retail-core evaluation; Apache-2.0, upstream notice retained.
import NIOConcurrencyHelpers

/// Counts all admitted finished spans, including input, queued and in-flight work.
final class OTelSpanBudget: Sendable {
    struct State: Sendable {
        var retained = 0
        var highWater = 0
        var dropped = 0
        var accepting = true
    }
    let limit: Int
    private let state = NIOLockedValueBox(State())
    init(limit: Int) { precondition(limit > 0); self.limit = limit }
    var snapshot: State { state.withLockedValue { $0 } }
    func acquire() -> OTelSpanAdmission? {
        let admitted = state.withLockedValue { state in
            guard state.accepting, state.retained < limit else {
                state.dropped += 1
                return false
            }
            state.retained += 1
            state.highWater = max(state.highWater, state.retained)
            return true
        }
        return admitted ? OTelSpanAdmission(budget: self) : nil
    }
    func close() { state.withLockedValue { $0.accepting = false } }
    fileprivate func release() {
        state.withLockedValue { state in
            precondition(state.retained > 0)
            state.retained -= 1
        }
    }
}

/// Copies share an idempotent credit; export completion releases it even when
/// a test exporter retains the exported snapshot. Dropped work releases on deinit.
final class OTelSpanAdmission: Sendable {
    private let owner: NIOLockedValueBox<OTelSpanBudget?>
    init(budget: OTelSpanBudget) { owner = NIOLockedValueBox(budget) }
    func release() {
        let budget = owner.withLockedValue { owner in
            defer { owner = nil }
            return owner
        }
        budget?.release()
    }
    deinit { release() }
}
