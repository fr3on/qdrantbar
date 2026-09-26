import Foundation

/// What we know about the active server. `/healthz` needs no key, so reachable is not the same as usable.
public enum ConnectionState: Sendable, Equatable {
    case offline
    case unauthorized
    case online
}
