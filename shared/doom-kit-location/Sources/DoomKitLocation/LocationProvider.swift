@MainActor
protocol LocationProvider: AnyObject {
    var onUpdate: (@MainActor (LocationProviderUpdate) -> Void)? { get set }
    func start()
    func stop()
}

struct LocationProviderUpdate: Sendable {
    var location: Location?
    var authorization: LocationState.Authorization
    var failure: LocationState.Failure?
    var authorizationScope: LocationState.AuthorizationScope = .unknown
}
