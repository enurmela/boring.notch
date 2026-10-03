import Foundation

/// A session keeps its place through streaming, input and approval changes.
/// Only a newly completed turn moves an existing session to the front.
struct T3SessionOrdering {
    struct Entry {
        let id: String
        let phase: T3AwarenessPhase
        let completedAt: String?
    }

    private var order: [String] = []
    private var previous: [String: Entry] = [:]

    mutating func update(_ entries: [Entry]) {
        var completed: [String] = []
        for entry in entries {
            if let old = previous[entry.id] {
                let newCompletion = entry.completedAt != nil && entry.completedAt != old.completedAt
                if entry.phase == .completed && (old.phase != .completed || newCompletion) {
                    completed.append(entry.id)
                }
            } else {
                order.append(entry.id)
            }
            previous[entry.id] = entry
        }
        let promoted = Set(completed)
        order = completed + order.filter { !promoted.contains($0) }
    }

    func sorted<Element>(_ elements: [Element], id: (Element) -> String) -> [Element] {
        let ranks = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return elements.sorted { (ranks[id($0)] ?? Int.max) < (ranks[id($1)] ?? Int.max) }
    }
}
