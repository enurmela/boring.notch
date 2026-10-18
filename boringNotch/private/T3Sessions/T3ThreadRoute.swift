import Foundation

enum T3ThreadRoute {
    /// The web app's thread route (`/$environmentId/$threadId`). The
    /// `/threads/…` deep link in t3code's agentAwareness belongs to the
    /// relay and mobile clients; the web router has no such route.
    static func path(environmentId: String, threadId: String) -> String {
        "/\(escape(environmentId))/\(escape(threadId))"
    }

    /// Desktop app link: `t3code://threads/{env}/{thread}` opens the thread
    /// in the running app, or launches it first.
    static func appURL(environmentId: String, threadId: String) -> URL? {
        URL(string: "t3code://threads\(path(environmentId: environmentId, threadId: threadId))")
    }

    private static func escape(_ segment: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%"))
        return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
    }
}
