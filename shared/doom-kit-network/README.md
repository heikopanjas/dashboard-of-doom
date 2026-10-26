# DoomKitNetwork

Local Swift 6 package (Swift tools 6.2). Declares macOS 15 and iOS 26.
macOS is validated; iOS simulator tests are validated; physical background delivery and WeatherKit checks are recorded separately in [iOS migration](../../ios/MIGRATION.md).

`NetworkManager.shared` is retained. Construct a separate actor to inject a
transport, monitor factory, cancellation-cooperative sleep closure, or probe URL.
Passing a nil probe URL disables the probe. The default probe is a HEAD request
to Apple's success page with a 10-second request timeout.

```swift
import DoomKitNetwork

let network = NetworkManager()
await network.startMonitoring()
let result = await network.performDataRequest(urlString: "https://example.com/data")
await network.stopMonitoring()
```

Each `updates()` call registers and replays a distinct `NetworkState` stream on
the actor, with `bufferingNewest(1)`. State distinguishes uninitialized,
monitoring, online/offline, and connection type. Slow observers see the latest
state. Cancel each owned consumer task to remove its observer; do not distribute
one stream to multiple consumers or rely on breaking a loop for cancellation.

Start/stop is explicit for monitoring; requests also start it on demand.
A private adapter installs its callback before starting NWPathMonitor. Each
lifecycle gets a new adapter, and generation checks ignore obsolete callbacks.
Stopping publishes reset state, finishes observers, and cancels monitoring.
Restart requires new subscriptions. Requests belong to their calling tasks:
cancel those tasks to stop transport, readiness waits, and retries.

`waitForConnection(timeout:)` observes state and races it against an injected
clock sleep using structured tasks. It throws on timeout, shutdown, or
cancellation, and cancels the losing child. It does not poll or allocate another
path monitor. Start monitoring before calling it.

Raw and `Decodable & Sendable` requests share one execution path. Headers, method,
body, HTTP response validation, and error mapping are retained. HTTP failures
and URL transport failures outside Overpass receive at most five total attempts with 2, 4, 8, and
16-second backoffs. Invalid responses and decoding failures are not retried.
Cancellation is never retried. Offline requests use the optional probe, then wait
up to 15 seconds for connectivity. Public errors include transport unavailability,
timeout, cancellation, HTTP status, and decoding failure.

Injected transport and sleep implementations must cooperate with cancellation;
a task group cannot forcibly stop an implementation that ignores it. Default
async closures are constructed inside the initializer: constructing the timing
closure as a default argument exposed a runtime failure with the tested Swift
6.2.4/macOS 15.8 combination.

Run `swift test --package-path shared/doom-kit-network` from the repository root.
All request tests use fake transport and monitoring; they make no live requests.

Overpass interpreter requests share a cancellation-aware serial queue per manager.
The trailing `priority` argument defaults to `.userInitiated`; POI services use
`.background` with a two-second startup grace period. Queued environmental work
goes first. Unrelated HTTP requests bypass this queue.

Connection, server, and JSON runtime failures can use `overpass.private.coffee`
after `overpass-api.de`. Unavailable endpoints are skipped for five minutes after
transport failures or one minute after server/runtime failures. Requests retain
the query and have a 35-second transport timeout. HTTP 429 waits at least 30 seconds
(or longer Retry-After), retries the same endpoint once, and never rotates hosts.
Invalid queries are not retried. Tests inject transport and time; no live API is used.
