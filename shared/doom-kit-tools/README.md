# DoomKitTools

Local Swift 6 package, Swift tools 6.2, macOS 15 and iOS 26. macOS is validated;
iOS simulator tests are validated; physical background delivery and WeatherKit checks are recorded separately in [iOS migration](../../ios/MIGRATION.md). Its only local dependency is DoomKitLocation. It has
no dependency on process models, services, or SwiftUI.

Public APIs include `ARIMAPredictor`, its parameter/result/interval/error types,
`MathematicalSymbols`, `calculateBoundingBox`, `PolygonProximityCalculator`,
`FastPolygonProximity`, `LocationAnalysis`, and Location distance extensions.
Standalone types have separate files; usage examples remain internal.
Forecasting, geometry, and symbol mappings retain their original algorithms and
values. Mutable predictors and precomputed polygon calculators belong to one
caller at a time; they are not Sendable.

## Annotation layout

`AnnotationLayout.place(_:in:previous:)` is a pure synchronous screen-space solver
using Foundation and CoreGraphics, with no SwiftUI, MapKit, or Process dependency.
Pass unique stable string IDs in priority order, projected points, actual marker
bounds, optional label sizes, and a viewport rectangle. A nil label size reserves
only the marker. Invalid points are omitted until the caller can project them.
The result returns label rectangles, source points, optional connector endpoints,
and search diagnostics. Feed its placements into the next call for stability.

The macOS label and solver share a 131 × 33-point default. Placement reserves an
8-point viewport inset, 6-point label separation, and 4-point clearance around
unrelated markers. Attached labels meet their own dot (including coincident dots)
without a gap; their corner anchors reproduce the original above-right placement.
The solver first searches previous relative positions and eight local anchors,
then adds outward anchors at 40-point intervals through 160 points if necessary,
then a viewport-aligned grid. A deterministic beam retains at most 256 partial
arrangements during expansion; the fallback grid is capped at 32 rows and columns
for unusually large caller-provided viewports. Collisions and clipping take
priority over connector count, local anchor preference, connector crossings, and
source distance. Previous-placement retention is only a final tie-breaker, so
obsolete offsets and connectors are removed as soon as a direct attachment fits. Equal scores
use input and candidate order, with above-right first among local anchors.

Clipping is scored as nonnegative outside-strip area, so fully contained labels
have exactly zero clipping cost. Edge lengths at or below 0.0000001 point are
ignored as floating-point noise before scoring collisions. The arrangement
comparator retains strict ordering; it does not use approximate equality.

Labels are never dropped to resolve collisions. A positive but undersized viewport
gets the best arrangement found by the bounded search, which can still overlap
or clip; this is not a guarantee of a global optimum. A zero or invalid viewport
returns no placements. Marker bounds describe centered ellipses; connectors run
from their boundaries to the closest label boundary. Callers draw the lines below
markers and labels and exclude them from accessibility.

Ordinary-import tests cover coincident and dense clusters, mixed sizes, edges,
marker-only obstacles, connector boundaries, offscreen grid fallback, invalid
projections, deterministic bounded fallback, and placement retention after
location, size, visibility, and viewport changes. Run Debug and Release:

```sh
swift test --package-path shared/doom-kit-tools
swift test --package-path shared/doom-kit-tools -c release
```

## Smoothing

All three functions accept and return `[Measurement<T>]` for `T: Dimension`:

```swift
import Foundation
import DoomKitTools

let values = [1.0, 4, 2].map { Measurement(value: $0, unit: UnitLength.meters) }
let result = gaussianSmoothing(data: values, windowSize: 5, sigma: 1.0)
```

`movingAverage(data:windowSize:)` uses a trailing window, shortened at the start.
Nonpositive windows return the input. `exponentialMovingAverage(data:alpha:)`
seeds from the first value and preserves the original recurrence. Both retain
the original raw-value arithmetic and use the first input unit for every output;
they do not convert mixed units.

`gaussianSmoothing(data:windowSize:sigma:)` defaults to 5 and 1.0. It converts
neighbors to each output's original unit, normalizes the truncated edge weights,
and clamps negative results to zero. Nonpositive or even windows, or nonpositive
or nonfinite sigma, return the input unchanged. Empty input always returns empty.

The app owns ProcessValue reconstruction: zip each original value with its
smoothed measurement, preserving timestamp, quality, and metadata, with a new UUID.

## Logging

`Trace` is a final, synchronously callable Sendable class. A `Synchronization.Mutex`
serializes date formatting and console/file output. It closes its file handle on
teardown, appends to existing files, and retains variadic logging overloads.
Filtering intentionally preserves the original lexical comparison of level raw
values (so ERROR sorts before INFO). No logging actor or unchecked Sendable was
introduced. The public global `trace` retains debug minimum, no colors, and
`yyyy-MM-dd HH:mm:ss` timestamps.

Run `swift test --package-path shared/doom-kit-tools` and repeat with `-c release`.
Ordinary-import tests cover captured pre-extraction smoothing and forecast
results, invalid smoothing parameters, mixed units, geometry, symbol mappings,
and concurrent file logging. Tests do not access the network or location provider.
