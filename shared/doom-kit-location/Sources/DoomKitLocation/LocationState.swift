import Foundation

public struct LocationState: Sendable, Equatable {
    public enum Origin: Sendable { case fallback, measured }
    public enum Authorization: Sendable { case notDetermined, restricted, denied, authorized }
    public enum AuthorizationScope: Sendable { case unknown, whenInUse, always }
    public enum Tracking: Sendable { case stopped, starting, tracking }
    public enum Failure: Sendable, Equatable {
        case denied, unavailable
        case other(Int)
    }

    public var location: Location
    public var origin: Origin
    public var authorization: Authorization
    public var tracking: Tracking
    public var failure: Failure?
    public var authorizationScope: AuthorizationScope = .unknown
}
