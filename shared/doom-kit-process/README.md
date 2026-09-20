# DoomKitProcess

Local Swift 6 package (Swift tools 6.2), declaring macOS 15 and iOS 26.
macOS is validated; iOS simulator tests are validated; physical background delivery and WeatherKit checks are recorded separately in [iOS migration](../../ios/MIGRATION.md). Local dependencies: DoomKitLocation and DoomKitNetwork. Observation supplies the
observable presenter base; no SwiftUI dependency.

```swift
import DoomKitProcess

@MainActor
func configure() -> ProcessManager<String> {
    let manager = ProcessManager(context: "Berlin")
    manager.register(interval: .seconds(300)) { context in
        // Await work, then check cancellation immediately before publishing.
        guard Task.isCancelled == false else { return }
        print(context)
    }
    manager.start()
    return manager
}
```

The main-actor manager registers async main-actor closures by UUID. Registration
refreshes immediately when context exists, including before scheduling starts.
Registering the same UUID replaces and cancels its previous registration.
`remove(id:)` cancels exactly that registration.

The default injected clock is monotonic. Scheduling uses one owned cancellable
task, a 60-second cadence, and a 60-second minimum registration interval.
`isReady` gates scheduled refreshes, while explicit and registration refreshes
remain available. The cadence can be made longer, but not shorter than 60 seconds.

`updateContext` cancels outstanding refreshes without starting new work.
`refresh(id:)` cancels and restarts that registration, preserving its deadline.
`refreshAll()` also resets all interval deadlines. Generations prevent late
completions from clearing replacement tasks. The returned refresh task can be
awaited for deterministic completion.

Cancellation is cooperative. Closures must check cancellation after awaited
work and immediately before publication, with no suspension between that check
and publication. The package cannot prevent arbitrary writes inside an
uncooperative closure. The app uses per-refresh transformers and synchronous
main-actor publication to honor this contract.

`stop()` cancels scheduling and refreshes and retains registrations for
`start()`. Manual refresh is disabled while stopped. `shutdown()` additionally
removes registrations and context. Deinitialization cancels all owned tasks. Registration storage is Sendable,
allowing nonisolated teardown and avoiding a Swift 6.2.4 Release optimizer crash
in a generic isolated deinitializer.
Injected sleep must throw promptly on cancellation. The scheduling task captures
the manager weakly across sleeps.

The package's `ProcessCoordinator` owns location/network observation and policy:
registration refreshes use the injected location manager's fallback, first measured location causes
one bulk refresh. The default `locationRefreshPolicy: .firstMeasurement` makes
later location changes update context without bulk refresh; the iOS app explicitly
selects `.everyMovement` to refresh after each accepted location change,
and startup waits at most 30 seconds before beginning the timer. After that
bound, offline retries remain the network package's responsibility, as before.
Settings keep their individual refresh behavior; bulk refresh resets intervals.

Run `swift test --package-path shared/doom-kit-process`. Tests use a manual clock and
controlled suspended work to cover scheduling, replacement, cancellation,
context, removal, restart, shutdown, and late completion.

## Models and app integration

All process types live in this module: `ProcessController`, `ProcessLocatable`,
`ProcessPresenter`, `ProcessQuality`, `ProcessRefreshable`, `ProcessSelector`,
`ProcessSensor`, `ProcessTransformer`, `ProcessValue`, and `ProcessCoordinator`,
alongside the generic scheduler and clock. Geographic sorting, distance, and
polygon helpers are public. Selector raw values, UUID identity, measurements,
placemarks, and arbitrary `[String: Any]` metadata are preserved. Models with
arbitrary metadata are not Sendable and must remain within their owning isolation.

`ProcessPresenter` is open, observable, and main-actor isolated. Its optional
`coordinator:` initializer argument is held weakly, excluded from observation,
and used to remove its UUID registration on deinitialization. The UUID itself
is immutable and nonisolated for external Identifiable conformances.
`ProcessTransformer` is open with public state and open rendering methods;
create one per refresh, as its mutable transformation state is not Sendable.

Construct `ProcessCoordinator(locationManager:networkManager:clock:)` explicitly.
Construction and pre-start registrations are inactive. `start()` activates
registration refreshes immediately, observes location/connectivity, and begins
periodic scheduling after connection or the 30-second startup bound. Repeated
start calls are idempotent. Stop cancels tasks and location tracking while keeping
registrations for restart. Network monitoring is shared and must be stopped by
its owner at application shutdown. Lifecycle generations reject stale events.

The app owns `AppProcess.shared`, which supplies `AppLocation.shared` and
`NetworkManager.shared`, then starts the coordinator at first presenter creation.
Berlin coordinates and concrete presenters/settings remain app-owned. Internal
source protocols adapt the existing managers and permit tests without tracking,
permission requests, or live networking. Public API tests use ordinary imports.

## Custom measurement units

The eight former app unit files now live here. Public custom Dimension classes
cover acidity, electrical conductivity, incidence, percentage, population,
radiation, and turbidity; public Foundation UnitConcentrationMass extensions
provide cubic-meter concentrations. Constants, symbols, coefficients, base-unit
overrides, and existing unchecked Sendable conformances are unchanged. This
extraction makes no scientific or conversion corrections. Ordinary-import tests
check every exported definition, conversions, and use with ProcessValue.
