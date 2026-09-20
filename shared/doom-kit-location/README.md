# DoomKitLocation

Local Swift 6 package (Swift tools 6.2). Declares macOS 15 and iOS 26.
macOS and iOS simulator tests are validated. Real-device permissions and background delivery still require an Apple Development identity; see [iOS migration](../../ios/MIGRATION.md).

```swift
import DoomKitLocation

@MainActor
func observe() async {
    let manager = LocationManager(fallback: Location(latitude: 52.51889, longitude: 13.36528))
    let updates = manager.updates()
    manager.start()
    defer { manager.stop() }
    for await state in updates {
        print(state.location, state.origin, state.authorization, state.failure as Any)
    }
}
```

Initialization neither requests permission nor starts tracking. The caller owns
the fallback policy and the observation task's cancellation. Each call to
`updates()` atomically registers a separate observer and replays current state,
with `bufferingNewest(1)`. Failures remain in state; they do not end observation.
Cancelling a consumer removes only its observer. Do not share one stream between
consumers. Cancel the consumer task when finished; simply breaking a loop is not
a subscription cancellation mechanism.

`stop()` stops the provider, publishes stopped state, and finishes all streams.
Restart with `start()` and new subscriptions; old streams stay finished.
Deinitialization also stops the provider and finishes observers.

The first measurement replaces fallback even at identical coordinates. Later
measurements must move strictly more than 100 meters from the last accepted
location, using the exported Haversine calculation. Location preserves exact
coordinate equality/hashing and exposes a Core Location coordinate conversion.

The internal injectable `LocationProvider` supplies package-owned updates.
The private delegate adapter defaults to kilometer accuracy and When In Use
authorization. iOS callers may explicitly select `configuration: .continuousBackground`
for best accuracy, Always authorization, background updates, no automatic pauses,
and a visible background indicator. The app must declare the location background
mode and permission descriptions. `authorizationScope` distinguishes When In Use
from Always without changing the existing broad `authorization` values. It creates a new Core Location manager/delegate per lifecycle.
Broadcasting, movement filtering, fallback selection, and consumers live outside
the adapter.

A future provider using `CLLocationUpdate.liveUpdates()` is planned. It will retain
the public stream contract, but must separately validate accuracy, authorization,
delivery, cancellation, and background behavior. It is not expected to reproduce
every legacy tracking setting. Background capability belongs to the app; selecting a policy does not grant permission.

`GeocodingService` performs separate async requests with injectable lookup for
tests. `GeocodedPlace` preserves long/short address formatting and constituency
precedence: administrative area, subadministrative area, then locality. Native
requests own separate geocoders and cancel underlying geocoding when cancelled.
Throwing instance methods expose errors; convenience address methods return nil
on failure for existing app consumers.

Run `swift test --package-path shared/doom-kit-location` from the repository root.
Tests use substituted providers and geocoding; no location permission or network
is required.
