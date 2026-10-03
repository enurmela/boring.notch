import Foundation

enum T3ThreadRoute {
    static func path(environmentId: String, threadId: String, protocolVersion: Int?) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%"))
        let environment = environmentId.addingPercentEncoding(withAllowedCharacters: allowed) ?? environmentId
        let thread = threadId.addingPercentEncoding(withAllowedCharacters: allowed) ?? threadId
        let prefix = (protocolVersion ?? 1) >= 2 ? "/threads" : ""
        return "\(prefix)/\(environment)/\(thread)"
    }
}
