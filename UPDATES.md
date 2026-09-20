# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-09-20 (ios v6.5.0, the fuel map pins take the six label colors, 23:05)

- the six filling station pins were all `Color.energy`, the tab's brown, and read muddy over map terrain at half opacity; they now take the six home label colors, one per rank, as the home and environment maps do
- decision: warm first, orange, pink, yellow, green, blue, purple, so the dearest end of the list reads hot and the cheapest end cool
- decision: the color marks the rank, not the price level, so switching dearest to cheapest keeps the same six colors in the same order and only the stations under them change. the numbered icon is what says which rank a pin is; the color is there to tell six pins apart
- consequence: the palette has exactly as many colors as the map shows stations, which is a second reason six is the right count. a seventh would have had to repeat a color
- `Color.fuelStations` is a separate array rather than a case in `Color.sensor(selector:index:)`, because fuel uses all six while the per-source lists use three each and the nearest of each keeps its own home color; there is no home color for a filling station to keep
- validation: 87 macos and 133 ios unit tests, both apps build, ui test passes; the screenshot shows six distinct pills with their dots matching, still placed without a connector line

### 2026-09-20 (ios v6.5.0, filling stations as a map instead of a list, 22:50)

- the filling stations moved from a list at the bottom of the energy tab to a map at the top, above the crude charts, where the other tabs put theirs; the list is gone
- rationale: a price list says how much but not where, and where is the useful half. the fuel, order and radius pickers still drive the selection exactly as before
- decision: six stations, not seven, because six is the documented limit of the label placement solver; seven would have been one past what it was built for
- decision: the rank rides in the label's icon slot as a numbered circle rather than being squeezed into the text, which leaves the price at full size in a fixed width label
- the station model gained coordinates, which it never had because a list did not need them; a station the api sends without them is skipped, since it cannot be mapped
- the cc by credit line moved with the feature to sit under the map, attribution being a licence condition rather than decoration
- consequence: station names are gone entirely, since a map label holds one icon and one value. position now identifies a station
- the spoken price helper went with the list rows; the map label carries its own accessibility, so nothing called it any more
- validation: 86 macos and 132 ios unit tests, both apps build, ui test passes; the screenshot shows six numbered pins laid out without overlap or connectors and the closed fixture station correctly absent. the crowded case, six labels at a 5 km radius, is still only testable on the device
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, dearest filling stations on the energy tab, 21:45)

- the energy tab now ends with the seven dearest filling stations around the user, from tankerkoenig, which redistributes the bundeskartellamt's mts-k price data; settings gain a key field, a fuel picker, an order picker and a radius picker
- this is the first source that needs an api key, so it is the first user of the keychain store; the key goes in through settings and never near the repository, and the service takes it as a parameter rather than reading a store, because the services package cannot see the app layer, the golden url test needs a reproducible value and unsigned test runners cannot read the keychain anyway
- decision, forced by the api: sort by price is rejected while asking for all fuels, so the request always sorts by distance and every ranking happens locally. that is why the fuel and order pickers reorder instantly with no request, while the radius picker refetches
- decision: the radius offers 5, 10 and 25 km because the api caps at 25, checked directly: 26 and 50 return exactly the same stations
- decision: closed stations are dropped, as asked, even though they still report a price; equal prices are broken by distance, nearest first, so the list does not wobble between refreshes
- prices are written german pump style, 2,40 with a raised 9 and a euro sign, rather than the 2,41 the request sketched: the tenth of a cent is the digit the ranking turns on, so rounding it away would show stations the list ranks apart as identically priced. voiceover gets plain digits instead of the raised one
- the presenter copies the hazard one, a refreshable holding models rather than readings, with the generation counter and a five minute, one kilometre failure cooldown, since ios refreshes on every movement and tankerkoenig asks for at most one request every five minutes. it rides the energy enable key, so one switch governs the whole tab
- the secret field gained an onchange callback: a keychain write is not a userdefaults change, so nothing would otherwise notice a new key until the next hourly refresh
- the preference keys live in source preferences rather than on the ios view, because the controller needs the radius and the macos test target compiles the controller but not ios views
- known cosmetic wrinkle: station names are re-cased with the gauge name formatter, which fixes shouting names like berlin - westhafenstrasse but turns the company suffix ohg into ohg
- validation: 86 macos and 131 ios unit tests, all six packages, both apps build, ui test passes; the fixture screenshot shows seven stations with the closed one correctly absent, and the expected live top seven was computed from the api for comparison on the device
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, keychain store for api keys and tokens, 19:00)

- a sixth local package, doomkitsecrets, keeps api keys and tokens in the keychain, one string per named key, behind a small store protocol with a memory double for tests; the app's instance is appsecrets shared, and a secretfield settings row lets a key be pasted or removed. nothing consumes a key yet; it is there for the first source that needs one
- decision: items are synchronizable, so a key entered on the phone reaches the mac through icloud keychain, as asked; they use the data protection keychain, which is the one that syncs and the one the sandboxed macos app has, and are readable after first unlock so a background refresh can use them
- decision: a package of its own rather than a corner of the network package, so credentials do not pull the security framework into request code and the boundary stays as clean as the other five
- the keychain only works in an entitled process: the unsigned test runners and the unsigned simulator app both fail with missing entitlement, which is how a round trip test in the ios unit target failed and was removed. instead a debug launch argument runs a write, replace and remove of a probe key in the app itself; on the signed device build it passed
- validation: package tests for the memory store, the item query and the key type; both apps build; the device self check passed and the app was relaunched normally afterwards
- version bump: none; no user visible change

### 2026-09-20 (ios v6.5.0, energy prices tab and covid behind a switch, 18:00)

- a new ios energy tab shows daily brent and wti crude oil prices in usd per barrel and the eu lng spot price in eur per mwh, one chart each over the last year, a quarter at first and widened on request; it takes the slot the covid tab had
- a short footnote under each chart says what the price is and where it comes from, since the tab is for people who do not follow the markets; flush against the chart it blended into the axis labels, and a gray card was not wanted either, so it is inset with a card's padding but no visible box, and a divider separates the chart sections; the range headroom went from five to two percent so the prices fill their chart. the actual cause of the blending, found from a device screenshot, was the chart's area fill: drawn from zero on an axis that starts near the prices, it ran out of the plot and was painted behind the explainer, so the area is now anchored at the range's floor, the way the particle chart already does it
- the covid tab stays in the app behind a new enable switch, off by default on ios, and appears next to polls when switched on; macos keeps its covid tab and its single switch, on by default, the way polls already differ between the platforms
- sources: brent and wti come from the datasets oil-prices github mirror of the us eia daily series, plain csv, public domain, no key; lng comes from acer, the eu energy regulator, which has published a daily eu lng price since 2023 as a quoted latin-1 csv, no key
- decision: the mirror rather than the eia api, which needs a key that would have to live in settings or outside the repo; if the volunteer mirror ever stops, switching the url to the eia api is a small change and was written up as such
- decision: no free api exists for ttf or jkm, the european and asian lng benchmarks; every candidate was paid, a yahoo finance scrape, or dead, and dbnomics' ttf dataset was checked directly and stops in 2024. acer's own daily eu lng assessment is the one real free lng source and is what the tab shows; the benchmark column is a spread that goes negative and is left out
- decision: prices have no place, so the source is not on the map at all; the home map's label solver is sized for exactly six labels and stays there
- the selector, two single-unit dimensions, a service with three golden url entries, a controller with pure tested parsers, a transformer, a presenter and the tab; adding the selector case needed two exhaustive switches and nothing else
- dates parse as utc midnight so the chart drag lands on days; weekends and holidays carry the last price forward as uncertain, since markets are closed
- covid copies the polls two key shape on ios, an enable key for fetching and the tab and the old show key for the map label only; this also replaces the presenter's bool read of the show key, which treated an unset key as off for the map, with the same object read the other sources use
- fixtures, the subscription tests, the policy test and the ui test now enumerate the new source and the covid enable key; the ui test enables covid so its screenshot survives
- validation: all five packages, 82 macos and 117 ios unit tests, both apps build, ui test passes; the real app in the simulator fetched all three files without error, and the parsers are pinned to rows copied verbatim from those files. the tab was seen with fixture data only; real charts are for the device
- version bump: none; folded into the pending ios 6.5.0, but this is user visible and adds a tab, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, map of the particulate stations on the particles tab, 17:00)

- the ios particles tab now starts with a map of its stations, a dot and a label for each, with the same colored header pills under it, as the environment tab has
- the map itself moved into a shared view holding the camera, the height, the divider and the empty state; the environment and particles maps only build their annotations. the environment map is unchanged, which the screenshot confirms
- decision: a station reports up to a dozen pollutants and a label has room for one, so the label shows the first pollutant in the tab's chart order that has a value, pm10 then pm25, ozone and no2, so it always matches the first chart under it. the alternative, picking by the fewest gaps or a fixed pollutant, was not needed; pm10 with n/a is the fallback for a station with no values
- decision: particle colors are green for the nearest, the home particle color, then pink and blue. the tab is separate from environment, so the colors are reused across tabs and no color is spent on telling the tabs apart
- the pollutant chooser skips the marker for all pollutants, which is the first case of the enum but never reported
- known and untouched: the home map's particle label still takes an arbitrary pollutant, the first key of an unordered dictionary
- tests: the station annotations, ids, colors, order and text, the pollutant order and its fallbacks, the switch off and on, and that the map and the sections agree on each station's color; the palette test now covers the particle colors. an existing test that treated particles as a source without a color list was corrected
- validation: 76 macos and 111 ios unit tests, both apps build, ui test passes; the screenshots show three labels in green, pink and blue with matching pills on the particles tab and the environment tab unchanged. real uba stations on a real map are not seen yet
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, environment header pills use the map label transparency, 16:05)

- the coloured pill above each environment chart now has the same half transparent fill as the map label, so the pill and its label are the same tint; it was opaque before
- rationale: requested, so a pill and its label match in tone as well as in hue
- known consequence, seen in the screenshots: in light mode the pill is pastel with legible black text, but in dark mode the tint sits on a black page and comes out dark brown or olive, and the black text on it is hard to read. the map label has the same weakness over a dark map. this was the reason the pill had been opaque
- options left open: an opaque pill again, or light text on the pill in dark mode only, which keeps the same transparency; not done, since neither was asked for
- validation: build and ui test pass; light and dark screenshots checked
- version bump: none; folded into the pending ios 6.5.0

### 2026-09-20 (ios v6.5.0, per sensor colors on the environment map and headers, 15:50)

- every level and radiation sensor on the environment tab now has one of the six label colors from the home screen, on its map label, dot and connector and on the header above its chart, so a label can be matched to its chart
- the palette is one function, color sensor: radiation orange, pink, purple and level yellow, green, blue, nearest first. the nearest of each keeps its home color, orange for radiation and yellow for level, and the extras take the four that are left; the six are exactly the colors of the home labels and no new color values were added. the survey color is pink, not red, which the question offered had wrong
- decision: charts get a colored header pill only. the plots keep their accent gradient, which is one shared value used by ten chart views on both platforms and so is not touched here; the price is that in dark mode the accent can be orange or blue, which are also sensor colors, so a fill can resemble another sensor's pill
- the map annotation snapshot carries an optional color, nil by default, and its display color falls back to the selector's, so the home map and macos are unchanged; the label, the dot and the connector read it in the three places that used the selector color. the label type gets a defaulted color so its existing callers and tests compile as before
- the header view gets an optional color; with one, the address row is a rounded pill in it with black text, and without one it is plain, so the particles tab is unchanged. the pill is opaque where the map label is half transparent, because half transparent on a black page in dark mode reads dark
- the color is applied with multiple sensors off as well, so the two nearest sensors are still orange and yellow and match their labels
- the map and the sections work out each sensor's color from its position separately, so a test pins that they agree
- known limits: color is the only link between a label and a chart, since the labels carry no station name, so people who cannot tell the colors apart cannot make the match; pink beside orange and yellow beside green are close in hue at half opacity over map tiles
- tests: the palette is the six home colors, all different, nearest keep theirs, other selectors keep their category color, and indices wrap; the map annotations carry the colors in tab order and match the sections; the snapshot falls back to the selector color
- validation: 75 macos and 102 ios unit tests, both apps build, ui test passes; the screenshots show six different colors on the map with matching pills, legible black text on all six in light mode and on orange in dark mode at the largest text size, plain particles headers, and the earlier home map look unchanged
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, map of level and radiation sensors on the environment tab, 15:30)

- the ios environment tab now starts with a map showing only level and radiation sensors, a dot and a label for every sensor the tab lists below it, so the extra sensors from multiple sensors finally have a place on a map; the home map still labels only the nearest sensor of each source and is unchanged
- decision: a new view rather than reuse of the home map view, which hard codes the six home categories and takes its camera from a shared singleton keyed by presenter with one point each; changing that would have touched the home camera, which the map rules say not to do to fit labels. the collision map view underneath needs only a camera and a list of annotations, so the new view uses it directly with its own camera
- the camera is a rectangle around the sensors, grown by half its size on each side for the labels and never smaller than about three kilometres, so a lone sensor does not zoom in to nothing; it is recomputed from the data and its setter ignores writes, so it follows the sensors as they load and refresh
- labels are built from each reading rather than a presenter, through a second initialiser on the annotation snapshot; ids are the category plus the reading's source id, since ids must be unique within a map and an id used twice silently drops a label
- the map reads the same visible readings as the sections, so turning a source's multiple sensors off removes its extra labels at once and the map re-fits around what is left
- decision: sensors only, as asked; no points of interest, weather label, user marker or header, and it cannot be panned, like the home map, so it does not fight the scrolling. it renders nothing until a sensor has loaded, so the spinners below stay the only loading sign
- the settings footnotes said the map always shows the nearest sensor, which stopped being true with two maps, so all four now say the map on the home screen shows only the nearest one; the plan named three, particulates was changed too so they read the same
- known limits: labels sit at half opacity as on the home map with places off, so street names show through them; six close labels are what the placement solver was sized for; the labels carry the icon and value only, and the station names are in the sections below
- tests: annotation building, ids, order and the fallbacks, the camera rectangle for none, one, identical and distant sensors, the snapshot initialiser, and that the map follows each source's switch; the ui test now scrolls further on this tab
- validation: 69 macos and 93 ios unit tests, both apps build, ui test passes; the screenshots show six labels and dots clear of each other with a connector where one is displaced, two labels after re-fitting with the switches off at the largest text size, and the home map unchanged. real gauges and stations on a real map are not seen yet
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, level other waterways setting, 15:10)

- new ios setting for level, other waterways, that lets the extra gauges be on other rivers and canals instead of only the first gauge's waterway
- decision: it changes only the extra gauges; the first gauge keeps its rule, the nearest on the nearest natural waterway or the plain nearest with nearest sensor on. the alternative, all three strictly nearest, is what nearest sensor plus multiple sensors already gives, so a new switch would have duplicated it
- consequence: the extras come after the first, so one can be nearer than the first when it sits on another waterway, and the distances down the stack do not always increase; the first stays first because the map pin, the address and the menu label read the first reading
- decision: default off, ios only, and shown in the water card only while multiple sensors is on, since without extra gauges it would change nothing, the same way the poll scope picker only appears when polls are enabled
- selection: the existing waterway then nearest rule is factored out unchanged and used for the first gauge with a limit of one; the extras are the nearest remaining gauges, through the same nearest function so the 1000 km cutoff still applies. with the setting off, or a limit of one, the result is exactly what it was, so the default and macos are untouched
- the extras carry their own waterway name, so their chart titles now read their own river, which also tells them apart
- the controller reads the setting per refresh through an injectable closure, like nearest sensor and the sensor limit; the toggle refreshes the level source so the change takes effect at once
- tests: seven cases for the selection, using a spree, havel and canal layout in which two extras are nearer than the first, plus the default, a limit of one, no matching waterway, no repeats, fewer gauges than the limit and the cutoff; the new key is pinned and listed in the unrelated key loop
- validation: 67 macos and 82 ios unit tests, both apps build, ui test passes; the settings screenshot shows the toggle in the standard card style under multiple sensors, off. the fixtures seed readings directly, so the effect on real gauges is not seen yet
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, multiple sensors setting per source, default off, 14:45)

- level, radiation and particles each get an ios setting, multiple sensors, that turns the multi-sensor behaviour on; off means the previous behaviour: one sensor, the nearest, one station's data fetched, one section shown
- decision: three switches, one per source, rather than one for all; particulates are the expensive one, about seven requests against three, so the switches can be used independently
- decision: the default is off, so out of the box nothing is multi-sensor and the extra sections appear only after a switch is turned on. the build that was on the phone showed three sections and shows one again until the switches are turned on
- decision: ios only; macos already fetches and shows one sensor, so a switch there would do nothing
- keys are multisensorlevel, multisensorradiation and multisensorparticles, only ever read with bool for key, so unset is off and launch arguments reach them, which the ui test uses
- one function, source preferences sensor limit, turns a key into a limit: one when off, the platform cap when on. each controller takes it as an injectable closure re-read on every refresh, the same shape as the nearest sensor closure, so a switch takes effect on the next refresh without restarting anything
- radiation was the one source with no seam for the limit, its station count was hard coded in a private function; it now takes a limit, and with the switch off it fetches one station where the old code fetched three and threw two away, so off is slightly cheaper than the previous behaviour, with the same result on screen
- the three views list visible readings, which trims to the nearest when the switch is off. the presenter keeps its last readings until a refresh replaces them, so trimming only the fetch would leave the extra sections on screen after switching off, for good if the refresh failed. trimming in the view makes the switch immediate
- each toggle refreshes its source, so turning it on loads the extra sensors at once
- radiation had no ios settings section; it got one, between water and particulate matter, matching the order on the home screen
- footnotes say what the switch does to the data and to the map, which always shows the nearest sensor, and interpolate the cap so the text cannot go stale
- tests: source preferences limit per key, including a launch argument string, visible readings on and off, and the radiation station limit, which gives radiation its first controller test; the unrelated key loop in the conditional subscription test lists the three new keys. the ui test turns the switches on for its first launch and leaves them off for the large text launch, and now also captures the settings tab
- validation: 60 macos and 75 ios unit tests, both apps build, ui test passes; the screenshots show the settings cards in the standard style, three sections per source with the switches on, and a single radiation section with them off
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, sensor cap is three and particulate matter is multi-sensor, 14:20)

- the per source sensor cap drops from five to three, and is one on macos: macos shows only the nearest sensor, so it no longer downloads the extra ones, for level and radiation as well; the cap is one constant with a platform condition, and the level and radiation controllers already derived from it
- particulate matter now reports up to three stations and the ios particles tab shows each as a section, the same way as the environment tab; the nearest section is unchanged
- decision: the first sensor is still the nearest station reporting pm10, pm25, no2 and o3, and the others are the stations that follow it by distance whatever they report; the other reading, three nearest stations that all qualify, was offered and not chosen, so sensors 2 and 3 can show fewer pollutants. following it, rather than the next nearest overall, keeps the array in distance order when the first sensor is not the nearest station
- the particulate probe is left as it was, sequential and unbounded, so a source with no qualifying station can still probe every station; bounding it is a follow up, not part of this change
- decision: the nearest station with no data still publishes nothing, so the last values stay, as before; level and radiation keep publishing an empty first sensor. the difference is deliberate, each keeps what it did
- particulate errors are now isolated per station, so one bad forecast drops that station instead of the whole refresh, and a failed geocode of the nearest station no longer discards the refresh, the next station with an address becomes the first sensor
- sensor candidate holds a dictionary of series per station and takes an injectable geocoder, which made the geocode in order rules testable for the first time; the particle controller takes an injectable nearest preference like level does, and its station selection is a pure function under test
- requests per refresh on ios go from 3 to 7 in the best case for particles; macos stays at 3
- tests: level selection and process package expectations moved from five ids to three; the level recovery test passes an explicit limit because the default is now the platform cap and is one on macos, which is how it failed once. new suites for the particle station selection and the sensor candidate rules
- fixtures and ui test: level, radiation and particles get three sensors each, and the ui test captures the middle and bottom of the environment and particles tabs
- validation: all five packages in debug and process, tools and services in release; 50 macos and 65 ios unit tests; both apps build; ui test passes and its screenshots show three sections per source in distance order with no unknown placeholder. real uba data was not checked, only the fixtures
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, environment tab shows up to five sensors per source, 13:55)

- the ios environment tab now shows every reading of level and radiation, nearest first, each as its own section with a header and its charts, with a divider between sensors; the nearest section is unchanged
- the two chart views take a reading instead of reading the presenter, and the container views loop over the readings keyed by the source id, so a gauge keeps its identity and its drag selection across refreshes
- processreading is now identifiable and owns the availability check; the presenter's version delegates to it for the nearest reading, so macos behaves as before
- sensors 2 to 5 have no address because only the nearest is geocoded, so their header shows the station name and the distance instead; the level station name is the gauge, carried in custom data, since the sensor name is the waterway and identical for all five
- decision: pegelonline writes names in capitals, so the display name re-cases only names written that way and keeps a two letter last word as it is, which turns BERLIN-CHARLOTTENBURG OP into Berlin-Charlottenburg OP and leaves mixed case bfs names alone; a token rule was chosen over a fixed list of suffixes so new gauges need nothing
- decision: every level chart keeps the waterway in its title, so five charts read the same; the header above each one tells them apart, and changing the title was left out of this change
- decision: all five sections are stacked rather than collapsed or paged, as asked; the tab is now several screens tall
- removed the dead macos branches from the two ios container views, since the ios folder is never compiled for macos and they could not fit the loop
- fixtures: level and radiation get five sensors in the ui fixture; the ui test captures the middle and bottom of the tab and the tab at the largest accessibility size, which is how the names, distances and text wrapping were checked
- project.yml: the header view is on the ios unit test include list
- validation: all five packages in debug and process, tools and services in release; 37 macos and 52 ios unit tests; both apps build without warnings from the new code; ui test passes; the screenshots show five sections with distances increasing, no unknown placeholder, and no clipping at the largest accessibility size. real gauge and station names were not seen yet, only the fixture ones
- version bump: none; folded into the pending ios 6.5.0, but this is user visible, so it should become 6.6.0 (181) if 6.5.0 has already shipped

### 2026-09-20 (ios v6.5.0, doomkit reports up to five sensors per source, 13:35)

- a source can now report up to five sensors, nearest first; level and radiation produce several, the other five sources still produce one and everything reads the first
- processpresenter stores readings, an array of sensor plus its rendered series, and sensor, measurements, current, faceplate, range, trend and timestamp are now get only forwards to the first reading; no view, chart or map code changed
- publish ignores an empty array, so a failed or cancelled refresh keeps the last good values and never moves the map camera; an app side overload also drives the map region through a visibility policy, because the seven publish bodies were not one shape: forecast never touches the map, weather always does, the rest follow their switch
- replace is the unconditional variant for fixtures and tests; the two preview helpers that read then mutated the dictionaries now merge into the first reading
- processsensor gains a stable source id and a distance in metres, and conforms to processlocatable; the per refresh uuid id stays and is documented as ephemeral
- level: the gauges on the nearest natural waterway, up to five, not padded with other rivers when it has fewer; no waterway means the five nearest overall; the 1000 km cutoff of the old single lookup is kept so a user outside germany still gets nothing; the gauge name is carried in custom data because the station name is the waterway and would be identical for all five
- radiation: three stations become five
- series are fetched two at a time through a new ordered concurrent compact map, then assembled by one shared sensor candidate step; only the first sensor is geocoded, so geocoding cost is unchanged; candidates are tried in order until one geocodes, which keeps radiation's old skip on failure and makes level degrade the same way instead of returning nothing
- decision: the nearest station is emitted even when it has no data, as before, so an outage shows an empty chart instead of silently moving the pin to another station; later stations with no data are dropped. the known consequence is that a transient fetch failure still blanks the chart, which was already true and is left for a separate change
- decision: the scalar forwards are get only rather than write through to the first reading; write through would have avoided six fixture edits but reintroduces the single sensor assumption this change removes
- project.yml: the macos unit test target lists its sources, so the two new presenter files, the array extension and the sensor candidate were added to it
- validation: all five packages in debug and process, tools and services in release; 37 macos and 48 ios unit tests; both apps build without warnings from the new code; new tests cover waterway selection, the distance cutoff, ordering under out of order completion, the concurrency bound, empty publish and the scalar forwarding. the simulator run at hkw showed level choosing five gauges on the spree in distance order and radiation fetching five stations two at a time; the map labels matched develop, but the location prompt could not be dismissed from the command line, so the level and radiation labels themselves were not seen in either build
- version bump: none; plumbing with no visible change, folded into the pending ios 6.5.0

### 2026-09-20 (ios v6.5.0, rename Shared to shared, 03:30)

- the shared code directory is now lowercase, matching ios, macos and every other tracked path at the root
- rationale: project.yml and README.md already spelled it shared, and only the case insensitive mac filesystem kept that working; a case sensitive checkout or a linux ci runner would not have found the sources
- done as two git mv steps through a temporary name, since core.ignorecase is true and a direct rename is a no-op there; git recorded all 152 files as pure renames rather than delete plus add, so blame survives
- two agents.md path references to bundled resources were the only stale spellings left in the repo
- validation: xcodegen regenerate, macOS and iOS Debug builds, all five local packages build
- version bump: none; a path rename with no behavior change

### 2026-09-20 (ios v6.5.0, poi master switch reframed and label opacity rule, 02:40)

- the ios points of interest master switch is now labelled "Show on map", since that is all it does once every category loads regardless of the switches; macos keeps "Show points of interest", where it still stops fetching
- the section gets a "Points of Interest" headline in the ios settings view, so every section has one; it was the only one relying on its first toggle as a title
- environmental map labels are now opaque when pins will actually be drawn, meaning the master switch is on and at least one category is selected, rather than on the master switch alone; before, master on with all five categories off left the labels opaque over a map with no pins
- the opacity is read from the switches through a new showsAnyPlaces property, not from the loaded points, so it keeps the no-flicker property the old rule had while a fetch is in flight
- decision: keep the master switch rather than delete it, and do not move decluttering onto the map; the user pointed out the map is already visually full between the floating sensor labels and a dense pin layer, so a one tap clear that preserves the per category choices earns its row in settings
- found while verifying: launch arguments cannot drive showPlaces or the category keys, because the presenter reads them with object as Bool to tell unset from false and argument domain values arrive as strings; AppStorage switches like showHazards use bool and do respond; noted in agents.md so the next session does not repeat the attempt
- validation: iOS and macOS Debug builds, 39 iOS and 28 macOS tests including a new showsAnyPlaces case over all four switch combinations; the three way visual comparison could not be done for the reason above
- version bump: none; folded into the pending ios 6.5.0 (180)

### 2026-09-20 (ios v6.5.0, tap a warning to open it on nina, 02:10)

- tapping a warning row on the ios home screen opens the alert's own page on warnung.bund.de in the system browser; the row shows a small open-in-browser symbol and has an accessibility hint
- the link is the form the nina web app uses itself, meldungen slash list id slash slug, found by reading the site's javascript bundle; the shorter meldung slash id redirect route rendered "meldung nicht mehr vorhanden" for an alert that was live, and the cap web field was not usable either, since dwd sets it to its generic warnings page and some issuers leave it empty
- validation: iOS Debug and macOS Debug builds, 38 iOS and 27 macOS tests including a url test; both a dwd and a mowas alert opened to their map and text in simulator safari
- version bump: none; folded into the pending ios 6.5.0 (180)

### 2026-09-20 (ios v6.5.0, all place categories on home, places always load, 01:55)

- the nearest places row on the ios home screen now lists the closest liquor or convenience store, funeral director and cemetery as well as the pharmacy and hospital, in that order
- ios keeps loading all five point of interest categories whatever the settings switches say; the switches now change only what the map draws, and the row is populated even with places switched off
- rationale: the user wants the row always filled; before, switching places off emptied the row and turning a category off dropped it from the row
- done with a second published list on the shared presenter: points stays the map's filtered set, allPoints is everything cached nearby, and an opt in fetchesWhenHidden flag that only ios sets; macos keeps not fetching what is switched off, since it has no consumer for hidden points
- the points of interest explainer on ios now says the switches change only the map; macos keeps its old text
- validation: iOS and macOS Debug builds, 37 iOS tests and 26 macOS tests including a new presenter test for fetching while hidden; simulator screenshots with places off show a clear map and a five entry row
- version bump: none; folded into the pending ios 6.5.0 (180)

### 2026-09-20 (ios v6.5.0, home rows below the map and nina warnings, 01:45)

- replace the level and radiation charts below the ios home map, which duplicated the environment tab, with four rows the user chose: an hourly forecast strip, a current conditions row, the nearest pharmacy and hospital, and a warnings card
- the forecast strip and conditions row show data the app already loaded but never displayed on ios: 111 hourly forecast points with condition symbols and rain chance, and feels-like, humidity, wind, gusts and pressure from the current weather; no controller or transformer changed
- the nearest places row is a client side minimum over the points of interest already loaded and draws its own leading divider, so nothing remains when places are off
- revive the dormant nina hazards: the proxy host the app used no longer resolves, so the service now uses the official warnung.bund.de host, which returns the same shapes; live at hkw the card listed two dwd storm warnings, one covering berlin and one 16 km away
- rationale for the rewrite rather than a host swap: the old view had no empty state, the old presenter was registered nowhere and would have crashed the app on launch, it ran its own location loop outside the coordinator, and the controller fetched detail, geometry and a reverse geocode for every alert in germany, serially
- the controller now fetches the four list feeds concurrently, then each alert's small geojson to decide relevance, and only then the cap details for alerts inside or within 50 km for dwd and 25 km for civil feeds, with at most 4 region and 2 detail requests in flight; a geojson is a multi feature collection with one polygon per district and the old parser read only the first
- relevance is decided by expiry rather than a 3 day sent window, since a live mowas drinking water notice was 16 days old; cancellations arrive as their own type and are dropped
- the presenter is a small ProcessRefreshable with a conditional subscription, a showHazards switch in the home settings, and the same failure cooldown as points of interest; a failed fetch keeps the last list and never shows a false all clear
- the geojson ring parser moved out of the covid controller into a shared GeoJSON helper used by both
- the services package tests had not compiled since the waterway change removed LevelService.fetchWaterways and the covid district lookup moved to bkg; the stale case is removed and the covid expectation updated, so the package is green again
- validation: iOS Debug and Release builds, macOS Debug build, 36 iOS tests including three new suites, 25 macOS tests, the services package; simulator screenshots on iphone and ipad in light and dark with the ui fixture, which now populates the forecast strip, conditions and three sample warnings; live run at hkw against the real feed
- version bump: ios 6.4.0 (179) to 6.5.0 (180) (MINOR - new home screen content and a revived data source); macOS untouched

### 2026-09-20 (ios v6.4.0, move the location section down, 01:35)

- move the ios settings location section below points of interest, so the order is general, home, points of interest, location, water, particulate matter, election polls
- rationale: the user asked for it; it also groups location next to the two nearest sensor sections it affects, since location is what decides which gauge and station are chosen
- validation: iOS Debug build and an ipad simulator screenshot of the new order
- version bump: none; folded into the pending work on top of ee0f4e6

### 2026-09-20 (ios v6.4.0, clearer settings explainers and location section, 01:25)

- reword every short explainer on the ios settings page and restyle the location section to match the others
- the home switches did not say that they also stop a source from updating; covid, water, radiation and particles cancel that source's refresh, so the matching tab sits on stale values, while weather and the poll map switch only hide the map label; the texts now say which of the two a switch does
- the election polls enable switch had no explainer at all although it also decides whether the polls tab exists
- the two nearest sensor switches described what they avoid rather than what they pick; they now say the app otherwise prefers a gauge on a natural river, or a station reporting all four pollutants
- the poll scope text now names the bundestag and the parliament where you are, which is how the scope actually resolves, from the constituency at your location
- the location section was the odd one out: its heading sat inside the card and the card was narrower than every other section, because its texts had no trailing Spacer to push the card to full width; it now uses the same heading outside, full width card, and an Access row that reads like the toggle rows
- also reworded the points of interest explainer, which lives in a shared view, so the macos settings window picks up the same text
- validation: iOS and macOS Debug builds, 21 iOS tests; every section checked on an ipad simulator in light and dark, including the two sections below the fold, which were temporarily moved to the top to be photographed and then restored
- version bump: none; folded into the pending work on top of ee0f4e6

### 2026-09-20 (ios v6.4.0, chart markers match axis labels, 01:10)

- in light mode the vertical marker line and dot on each ios chart now use the secondary system label color, the same color as the axis labels along the bottom and right of the chart, instead of the primary label color from the previous entry
- rationale: the user wanted the markers to match the axis labels; the charts use default axis styling, so those labels are the secondary label color, and using the same semantic color keeps them in step if that default changes
- measured on a simulator screenshot: axis labels and the marker line over white background both read 138, 138, 142; the marker is drawn at 60 percent opacity like the labels, so over the blue area fill it blends to a bluish gray instead of a pure gray
- scope is unchanged from the previous entry: light mode only, dark mode keeps the accent; no test or version change
- validation: iOS Debug build and the pixel comparison above; the drag-selected markers use the same edit but could not be triggered from the command line

### 2026-09-20 (ios v6.4.0, chart markers use system color in light mode, 00:55)

- the vertical marker line and the dot on each ios chart now use the system label color in light mode and keep the accent in dark mode
- covers the current value marker and the marker shown while dragging, in all six charts: covid, forecast, level, particle, radiation and survey, so twelve rule marks and twelve point marks
- rationale: the user asked for these to follow the system color in light mode, like the accent text labels changed in the previous entries; a blue line and dot on the blue fill were also hard to pick out
- chart marks are not views, so the accentLabel modifier does not apply; each chart reads the color scheme and uses a shared ColorScheme.markerColor, defined next to accentLabel
- the area fill under each line is not a marker and keeps the accent in both modes
- validation: iOS Debug build; in the simulator, light mode shows a black line and dot on the level chart and dark mode with a stored orange accent shows an orange line and dot; the dragging markers use the same edit but could not be triggered, since the simulator cannot touch from the command line
- version bump: none; the earlier work is committed as ee0f4e6 but the version was already raised to 6.4.0 (179) there, and this is a small follow-up inside it

### 2026-09-20 (ios v6.4.0, wider bottom toolbar, 00:45)

- widen the ios bottom toolbar capsule, which spanned about 60 percent of the screen; it now sits 16 points from each screen edge
- cause: on ios 26 the capsule is sized to its content, so the spacers between the buttons had nothing to expand into, and a maximum width frame inside a toolbar item is not honored either
- the capsule now gets an explicit width: the container width measured with onGeometryChange, minus horizontal safe area, minus a 21 point margin, capped at 600 points; the capsule draws about 5 points outside its content, so 21 gives a 16 point visible gap
- the cap keeps the six or seven icons from spreading across a 13 inch ipad; on iphone it is edge to edge
- decision: keep the single glass capsule the user already had; the alternative, separate round glass buttons split by flexible toolbar spacers, was declined because it changes the look
- correction to the 2026-09-19 header entry: the light mode title row is a 34 point minimum, not a fixed height, and it does grow at accessibility text sizes; agents.md now says so
- validation: iOS Debug build; in the simulator the gap is equal on both sides in light and dark, the seven icon case with election polls on fits, the largest accessibility text size does not clip, and on an iPad Pro 13 inch the capsule is centered at about 600 points; landscape was not checked because the simulator cannot rotate from the command line
- version bump: none; folded into the pending ios 6.4.0 (179), which is still uncommitted

### 2026-09-20 (ios v6.4.0, system label color for accent text in light mode, 00:35)

- ios text labels that were accent colored now use the system label color in light mode; in dark mode they keep the accent
- affected labels are the location row (icon and address) in the covid, forecast, level, particle, radiation and survey views, and the chart title in each of the six chart views, twelve sites in all
- tab icons, chart lines and gradients are not labels and keep the accent in both modes; the last update lines were already gray and are unchanged
- one small modifier, accentLabel, carries the rule instead of a color scheme check in twelve files; new accent-colored text should use it
- hazard view still uses the accent directly; it is commented out of the home screen, so it was left alone
- rationale: with the system accent now blue in light mode, blue headings and addresses on white read as links; the user asked for these labels to use the system color instead
- validation: iOS Debug build; in the simulator, light mode shows black labels with blue icons and chart lines, and dark mode with a stored orange accent still shows orange labels
- version bump: none; folded into the pending ios 6.4.0 (179), which is still uncommitted

### 2026-09-20 (ios v6.4.0, system accent in light mode, 00:20)

- ios light mode now uses the system accent and the accent picker is hidden there; the accent choice applies in dark mode only
- rationale: the user tried the deeper light variants from the previous entry on the iphone and preferred the stock look; this supersedes those variants (B35C00, 007C96, 0057D9), which are removed along with the light/dark color wrapper
- ios has no user-set system accent like macos, so the system accent here means systemBlue; the AccentColor asset is now systemBlue, with systemCyan for dark to match the default
- a nil tint falls back to the asset catalog accent, not to swiftui's built-in blue, which is why the asset had to change; the previous entry had set it to the custom cyan, so a nil tint alone would have left light mode teal
- ColorPresenter.tint(for:) returns nil in light mode and the selected color in dark mode; the stored choice is kept, so it is still there when the app returns to dark
- the picker keeps orange, cyan and blue in dark mode as plain system colors, and its footnote now says light mode uses the system color
- validation: iOS Debug and Release builds, macOS Debug build, 21 iOS tests including a new light mode test; in the simulator, a stored orange accent shows stock blue in light mode and orange in dark mode, and a stored blue shows blue in dark mode
- version bump: none; this is folded into the pending ios 6.4.0 (179), which is still uncommitted, following the earlier pending-migration entries

### 2026-09-19 (ios v6.4.0, light mode header and three accents, 17:20)

- ios light mode shows the title as bold text instead of the logo image; the logo is dark red lettering drawn for black and disappears on white, and macOS already did this before its header was removed in dd0f972; dark mode keeps the logo
- the header row keeps a 34 point minimum height in both schemes so the map below does not move when the theme changes, and the title shrinks to fit rather than growing at large Dynamic Type sizes
- reduce the accent choices from fifteen to orange, cyan and blue; white, gray and black were invisible against one of the two themes and the rest were rarely useful
- light mode uses deeper accents (B35C00, 007C96, 0057D9, about 4.7 to 6.2 to 1 against white) because the system orange and cyan measure about 2.2 to 1 and made every chart line and tab icon look faint; dark mode keeps the system colors
- replace the two index-matched accent arrays with one array of accent structs; the old lookup fell back to index 6, which would have crashed at launch once the arrays shrank below seven entries
- retired accents migrate on launch to the nearest survivor (red, yellow, brown and pink to orange; green, mint and teal to cyan; indigo and purple to blue; white, gray and black to the cyan default) and the stored value is rewritten, so the settings ring and the tint cannot disagree
- settings swatches are now buttons with accessibility labels, and the settings view no longer writes the selectedColor key itself; the presenter is the only writer
- apply the tint on the NavigationStack in ContentView instead of in the App body; a first attempt one level lower, on the ScrollView chain, left the charts and bottom bar on the default color, found by launching with a non-default accent and seeing cyan
- the asset catalog AccentColor was black in light mode and referenced a macOS color in dark mode; it is now the cyan default, so anything the tint misses degrades to the accent
- validation: iOS Debug and Release builds, macOS Debug build, 20 iOS tests including the migration cases; in the simulator, orange and a retired purple (now blue) retint the charts, header text and tab bar, and dark mode shows the logo
- version bump: ios 6.3.0 (178) to 6.4.0 (179) (MINOR - user-visible palette and header changes); macOS untouched

### 2026-09-07 (macos v6.5.4, area-weighted covid district centroid, 17:50)

- fix the covid sensor's displayed location, reported by the user as an oddly specific street address for a district-wide statistic
- the location was a district polygon centroid computed as a plain average of every boundary vertex, which is skewed toward wherever the boundary happens to be traced with more points, such as a winding riverbank; for berlin mitte this landed the reverse-geocoded placemark on seydlitzstrasse, a real address but not near the district's actual center
- replace it with a proper area-weighted centroid, computed per ring with the standard polygon centroid formula and combined across a district's rings by area, so a multi-part district is not skewed by one oddly-shaped or finely-traced piece
- this is the same function used for every district nationwide, not just berlin's boroughs, since both call sites share it
- validation: computed both the old and new centroid for berlin mitte and reverse-geocoded each; the old one reproduces the user's exact report, the new one resolves to a different, still-plausible address in the same postal district; all automated checks pass (22 tool tests, debug and release macos builds, point-of-interest tests, ios build, six build-script tests); the district id resolution itself was already correct and unaffected, since it uses real point-in-polygon containment separately from this display-only centroid
- version bump: 6.5.3 to 6.5.4 (patch - corrects a display value, no new user-facing capability)

### 2026-09-07 (macos v6.5.3, audit waterway classification against wrrl, 17:25)

- audit the name-based natural/artificial heuristic from the previous entry against wasserblick, the eu water framework directive's own water body classification, after the user downloaded the current dataset directly (the public version investigated during the previous entry's research pass was inaccessible)
- parsed the esri filegdb format by hand to read it, since no gdal or python geo library was available in this environment; validated the parser byte-exact against the declared field count and per-row length before trusting any output
- found wrrl cannot replace the heuristic wholesale: its names are ecological water bodies, not pegelonline's shipping-route names, so only 47 of 103 names join exactly; and its artificial flag is origin-based, not behavioural, so a canal dug along an old river course reads as not artificial to wrrl, which is the wrong signal for a heuristic that cares whether the level is naturally variable or lock-controlled
- of the 47 exact-name joins, most disagreements were kanal-named waterways where wrrl's origin-based flag was simply the wrong classifier for our purpose and the existing heuristic was kept
- one real correction: muritz-elde-wasserstrasse has no kanal in its name but is a heavily locked system connecting the mueritz lake district to the elbe; wrrl's constituent water bodies agree it is artificial by a clear majority, so it is now hard-overridden in the offline curation script rather than left to the name heuristic
- no swift code changed; only the bundled classification data and its curation script were touched
- version bump: 6.5.2 to 6.5.3 (patch - corrects one waterway's classification, no new user-facing capability)

### 2026-09-07 (macos v6.5.2, waterway lookup via bundled verknet-bwastr, 16:50)

- replace the osm overpass query used to find the nearest natural waterway for water-level gauge resolution with a bundled, offline-converted federal waterway network, removing the osm dependency from level lookups entirely
- rationale: the prior overpass-based fix already solved the real problem it targeted (the pegelonline station reported as nearest is not always on the waterway nearest to the user, e.g. a landwehrkanal gauge outranking a spree gauge purely because of gauge placement, not because overpass was wrong), but the user asked to remove osm from this codepath too since it shares overpass's latency and reliability problems with the covid lookup this session already replaced
- investigated whether gdws's authoritative verknet-bwastr dataset could also resolve the classification question, not just geometry; its schema has no natural/artificial field at all, only implicit in freetext segment names, so osm's waterway=river/canal tag was actually the cleaner classifier for that specific question, before this change removed it; also checked pegelonline's new beta hydas api and the eu water framework directive's wrrl/wasserblick classification (bfg hosts the right schema but the public arcgis folder is empty and the live one requires auth), neither usable as a live replacement today
- built a one-time offline conversion pipeline (not shipped): hand-wrote a shapefile and dbf binary parser since no gdal was available, converted verknet's utm32n geometry to wgs84 with a closed-form inverse transverse mercator formula, then matched each of pegelonline's 103 distinct waterway names against verknet's segment groups through several normalization tiers (hyphenation, concatenation, nested parent groups, description-text fallback), hand-assigning the natural/artificial flag per matched name since verknet has no such field; 81 of 103 names matched real geometry, the rest (foreign rivers, a few nested sub-canal names) fall back to the existing nearest-gauge behavior
- bundle the curated result as compressed json (`bundeswasserstrassennetz.json.zlib`, 2mb) and add a new open-polyline nearest-point primitive alongside the existing closed-polygon one, since a river is a line, not a ring
- delete the overpass-based waterway query, name-matching, and synchronization code from the level controller and service entirely; overpass is now used only by the background point-of-interest system
- add a wsv/gdws attribution line to the about tab alongside the existing bkg and berlin credits, even though the data's geozg/geonutzv licence does not require it
- validation: new polyline-proximity unit tests pass alongside all existing tests (22 total), signed debug and release builds succeed, point-of-interest tests pass including the existing missing-waterway-data fallback case, ios build unaffected, nine build-script tests pass; live verification at the user's real location and of the canal-only-nearby fallback case is still pending
- version bump: 6.5.1 to 6.5.2 (patch - corrects existing gauge-resolution behavior, no new user-facing capability)

### 2026-09-07 (macos v6.5.1, berlin bezirk exception for covid lookup, 15:50)

- discovered during manual verification of the prior entry: bkg's vg250 kreis layer models all of berlin as one feature, but rki reports covid data per berlin bezirk (12 boroughs, ids 11001 through 11012), since the bezirke are not independent gemeinden and never appear as separate features in any bkg layer; the whole-city id bkg returns for berlin is not even a valid rki district id, so covid data for any berlin location silently never loaded under the prior entry's implementation
- confirmed live against the current rki district list that this is the only such exception nationwide: 411 rki districts against germany's roughly 401 official kreise, with hamburg and every other city reporting as a single district like the rest of the country; the user's recollection was that hamburg had the same problem historically, but the live api disagrees today, so hamburg is left unhandled as a known possible gap rather than asserted fixed
- when bkg resolves a location to berlin's whole-city feature, fall through to a bundled dataset of the 12 bezirk boundaries (sourced from the amt fuer statistik berlin-brandenburg via a cc-by mirror) and re-resolve with the same point-in-polygon and nearest-edge logic already written for the general case, reusing rather than duplicating it
- add a second attribution line for the bezirk data alongside the bkg one
- validation: live end to end test at the user's actual location now correctly resolves to berlin mitte and successfully loads real incidence, cases, deaths, and recovered data, closing out the manual verification left pending in the previous entry; signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected
- no version bump: continues the 6.5.1 patch from the previous entry

### 2026-09-07 (macos v6.5.1, covid district lookup via bkg wfs, 14:45)

- replace the osm overpass query used to resolve a location's covid district with a direct query against bkg's own vg250 wfs kreis layer
- rationale: the overpass approach queried four administrative tiers at once as a workaround for incomplete regionalschluessel tagging in osm, but never deduplicated the resulting candidates and only ever had centroid distance to rank them, since overpass's out center never returns real polygon geometry; a kreis and a nested gemeinde or stadtteil could both surface as separate candidates, and centroid distance is a poor proxy for which polygon a point actually falls inside near a kreis border
- bkg is the federal agency that owns the regionalschluessel scheme itself, so querying only its kreis layer returns exactly one feature per kreis with no tagging gaps to work around, and real multipolygon geometry enables genuine point-in-polygon containment for the first time, with a nearest-polygon-edge fallback for points outside every fetched candidate
- reused the app's existing point-in-polygon and nearest-point-on-polygon helpers and the geojson polygon-parsing pattern already established by the unrelated civil-protection hazard controller, rather than introducing new geometry primitives
- add a bkg attribution line to the macos about tab per its data licence; no equivalent about surface exists on ios today, so ios carries no attribution yet, a known gap rather than an in-scope fix
- no fallback to overpass if bkg is unreachable; district data is simply skipped that refresh cycle, matching how every other network failure in this controller already behaves
- validation: verified the bkg wfs endpoint, layer name, and response shape live before implementation; isPointInPolygon and filterItemsInPolygon unit tests still pass; manual verification of district resolution across several real locations, including a kreis-border case, and of graceful offline behavior is still pending
- version bump: 6.5.0 to 6.5.1 (patch - corrects existing district-resolution behavior, no new user-facing capability)

### 2026-09-07 (macos v6.5.0, combined sensors tab, 14:00)

- merge the level, radiation, and particles dashboard tabs into one sensors tab with a gauge icon, shortening the toolbar from seven tabs to five
- stack the three sections vertically in one scrolling view, each keeping its own placemark and last update header since these sensors can each sit at a different location
- also rename weather forecast to weather and particulate matter to particles in the toolbar, matching the existing settings tab labels
- rationale: level, radiation, and particles are all small, thematically related physical sensor readings, and did not need a dedicated toolbar slot each
- explicitly left the settings window untouched: it keeps separate level, radiation, and particles tabs with their own enable toggles and refresh intervals, since merging the dashboard display has no bearing on those per source settings
- validation: signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected since it owns separate content and category views; manually verified all three sections render with distinct locations and data, dividers separate them, and settings still shows the three tabs unchanged
- no version bump: continues the current macos 6.5.0 cycle

### 2026-09-07 (macos v6.5.0, remove dashboard card chrome, 12:10)

- remove the card treatment from all six category views and from the home map, and delete the now unused dashboard card modifier
- keep only the outer padding on the home map, so it stays inset from the window edges with square corners and no border
- rationale: the card look was not wanted; charts read better bare on the plain background
- chart height stays at the fixed 167 points introduced in the previous entry; nothing here reintroduces height growth
- validation: signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected; a clean build confirms no stale references to the deleted modifier, and the bare charts and padded map were verified visually
- no version bump: continues the current macos 6.5.0 cycle

### 2026-09-07 (macos v6.5.0, dashboard chart cards, 12:00)

- present each chart as a card with a faint fill, hairline border, and the app's existing corner radius of 13, via a new shared `dashboardCard` view modifier
- restore the fixed 167 point chart height and remove the geometryreader that had made charts grow with the window
- rationale: growing charts were not wanted; a card layout reads better than bare charts on a flat background
- apply the same outer padding to the home map as the category tabs, and give it the same card treatment with no inner padding so it fills its card edge to edge; this also restores the rounded map look the pre-tab layout had
- use concrete black and white opacities rather than the semantic primary color inside the light and dark color initializer, which resolves through a dynamic nscolor provider
- validation: signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected; manually verified cards on every category tab, the fixed chart height on a single-chart category, the padded and clipped map, and card contrast in both light and dark themes
- two apparent regressions during verification were false alarms from accessibility scripting, not app defects: system events does not enumerate the settings nspanel and does not report frontmost correctly for this lsuielement app; the settings panel was confirmed visible through its own window frame
- no version bump: continues the current macos 6.5.0 cycle

### 2026-09-07 (macos v6.5.0, tabbed dashboard and resizable window, 11:40)

- replace the dashboard header title, logo, and settings button with a toolbar strip of category buttons matching the settings window pattern: home, weather forecast, covid-19, level, radiation, particulate matter, polls
- replace the stacked disclosure-group panels with a tab interface; selecting a toolbar button shows exactly one category full screen instead of scrolling through all of them at once
- make the home tab the full-size map view, filling the whole content area instead of a fixed 600 point strip above the panels
- make the dashboard window freely resizable with a 700x500 minimum and no maximum, instead of a fixed 800x859
- make each category's chart grid grow to fill available height via a per-view geometryreader, falling back to a 167 point minimum with scrolling once a category has too many selectors to fit
- extract the settings window's toolbar button into a shared `toolbartabbutton` view reused by both the settings panel and the new dashboard toolbar, removing the duplicate implementation
- truncate the full election party name on macos to one line, matching the existing ios truncation, since narrow resized windows would otherwise wrap it across three or four lines and crush the chart
- rationale: the previous single scrolling column did not scale to many data sources and could not be resized at all; the map was squeezed into a small preview instead of being a first class view
- bug caught during manual verification: wrapping each category view in an additional outer scrollview at the content-view level collapsed its internal geometryreader to zero height, rendering charts invisibly; fixed by letting each category view scroll only internally
- validation: signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected since ios owns a separate content view and map sizing modifier; manually verified every toolbar tab, chart growth at a 3-selector category, chart scrolling at a 12-selector category, the 700x500 resize floor, unbounded growth to 1400x1000, and single-line party name truncation at the minimum width
- no version bump: continues the current macos 6.5.0 cycle

### 2026-09-07 (macos v6.5.0, menu bar menu and global hotkey, 11:10)

- replace the menu bar click-to-open dashboard popover with a status item menu: open dashboard, settings, about, quit
- promote the dashboard to a real swiftui window scene opened and focused via appdelegate, since the menu no longer hosts it directly
- add a user-configurable system-wide hotkey, default control-command-d, that toggles the dashboard window, using the sindresorhus keyboardshortcuts package
- move all nine presenters from app-struct state into appdelegate as non-optional properties so settings and the dashboard window both see live presenters regardless of which scene renders first
- add a shared settings-selection object so about opens the settings panel directly on its about tab while other entry points keep the last used tab
- remove the header quit button from the dashboard now that quit lives in the menu; keep the settings ellipsis button
- rationale: a single click-to-open popover left no room for settings, about, or a keyboard path to the app; the previous onAppear presenter handoff also broke silently once the dashboard stopped being the first rendered view
- validation: signed debug and release builds succeed, all 14 macos unit tests and nine build-script tests pass, ios build unaffected; manually verified the menu, dashboard window open and close, about routing, the recorder, and the global hotkey opening, closing, and raising the window from another frontmost app
- version bump: 6.4.3 to 6.5.0 (minor - new user-facing capability, no breaking change)

### 2026-09-07 (macos v6.4.3, archive paths, 01:37)

- fix macos archive finalization by applying output roots through xcode build-location preferences; keep direct build-setting overrides for ordinary debug and release builds
- rationale: command-line SYMROOT and OBJROOT flatten the archive layout and cause the missing BuildProductsPath error after successful compilation
- add regression assertions for archive routing; shell syntax, shellcheck, and all nine macos and ios build-script tests pass
- validation: reproduced the original archive error; repaired release archive, developer id export, and strict code signature verification pass; apple notarization upload awaits explicit approval
- no version bump: build tooling correction with unchanged app behavior and signing configuration

### 2026-09-07 (ios v6.3.0, ios display name, 01:12)

- explicitly set the ios display name in the source plist and product name in project.yml to Dashboard of Doom for iphone and ipad
- align the ios product name with the display name and update the simulator installation path; retain the module name, app identifier, signing, and background location configuration
- no version bump for this display metadata correction


### 2026-09-07 (macos v6.4.3, ios v6.3.0, platform directories, 00:54)

- group macos app sources, rendering tests, build-script tests, signing export configuration, and screenshots under macos
- group ios app sources, unit and ui tests, build-script tests, build entry point, and migration record under ios
- group common app sources and tests, five doomkit packages and their tests, and shared test tooling under shared
- retain repository entry points and the combined xcodegen specification at root; retain existing build output locations and dependency pins
- validation: all 187 tracked swift files preserved byte-for-byte, both signed debug app builds and signature checks pass, 14 macos tests, 17 ios tests, and nine build-script tests pass
- package validation: all five packages pass debug tests from their new paths; process, tools, and services also pass release tests
- no version bump: directory organization only, with unchanged app behavior


### 2026-09-07 (ios v6.3.0, narrower map labels, 00:39)

- enlarge ios label symbols from subheadline to title3 and reduce horizontal padding from ten to five points per side
- reduce label width from 142 to 132 points while retaining the 36-point height and callout measurement text
- validation: all 17 ios tests pass; longer particle and radiation readings visually checked over dense pois in light and dark appearances; signed build installed and launched on iphone
- included in the pending ios 6.3.0 (178) migration; no additional version bump


### 2026-09-07 (ios v6.3.0, compact map labels, 00:32)

- replace tall stacked ios map labels with 142 × 36-point horizontal labels, smaller symbols, and larger callout text
- rationale: physical iphone screenshots showed symbols dominating the labels and measurement text too small to read comfortably
- keep collision placement dimensions synchronized, preserve full voiceover values, and retain macos styling
- validation: all 17 ios tests pass, including dense poi rendering in light and dark appearances; signed iphone build succeeds
- included in the pending ios 6.3.0 (178) migration; no additional version bump


### 2026-09-07 (ios v6.3.0, correct ios app identity, 00:16)

- use the user-confirmed `com.panjas.dashboard-of-doom` app id for ios signing, simulator launching, tests, and current documentation
- rationale: the imported source's different identifier did not match the intended developer-account configuration and weatherkit authentication failed on the ipad
- validation: corrected signed debug build installed and launched on the physical ipad; jwt authentication errors no longer appear in its startup log; nine script tests, shell syntax, and shellcheck pass
- preserve the previous differently identified installation and its data; this correction remains part of the pending ios 6.3.0 (178) migration


### 2026-09-06 (macos v6.4.3, ios v6.3.0, ios modernization, 23:53)

- preserve the original ios develop history through a non-squashed subtree import under ios; generate both apps and test targets from root project.yml
- share controllers, presenters, models, transformers, extensions, and map/poi views with the five local doomkit packages; retain platform entry points, navigation, charts, settings, and assets
- retain ios always/best-accuracy background location, no automatic pauses, visible indicator, and the 100-metre movement filter; refresh each accepted ios movement and once after foreground return
- preserve legacy ios water and independent poll enable/visibility preferences, cancellation, disabled-source retention, and unconditional weather/forecast fetching
- port collision layout and batched poi rendering with ios label dimensions; keep the fallback map available without weatherkit and correct large-text label overflow
- add isolated ios tests, offline iphone/ipad ui fixtures, and build-ios.sh with explicit output paths and hkw simulator launching
- validation: all package debug tests and process/tools/services release tests pass on macos and ios simulator; 14 macos app tests, 17 ios app tests, and iphone/ipad ui checks pass; signed macos builds/signatures and unsigned ios simulator/device builds pass
- physical ios validation remains pending because this mac has no apple development certificate/private key; preserve existing app identities and weatherkit entitlements
- rationale: modernize the older ios app on the maintained data pipeline while retaining its platform behavior; see ios_migration.md for evidence and remaining device checks
- version bumps: macos 6.4.2 (146) to 6.4.3 (147), patch for internal consolidation; ios 6.2.0 (177) to 6.3.0 (178), minor for shared infrastructure, source controls, and restored configurable pois


### 2026-09-06 (v6.4.2, source refresh controls and readable labels, 22:38)

- remove and cancel disabled covid, water-level, radiation, particle, and poll subscriptions independently of popover visibility; retain successful values and refresh immediately on re-enable
- preserve unconditional weather and forecast refreshes and existing poi fetch controls
- stop cancelled controller work before dependent requests, station fallbacks, and geocoding
- use opaque environmental label backgrounds while the poi master switch is enabled, including loading and empty results; retain half opacity otherwise
- rationale: respect source switches and keep dense places from obscuring environmental labels without changing placement or rendering
- validation: 14 app tests passed, including parameterized coverage of all five sources; 16 process tests passed in both debug and release; unsigned app build passed; inspected rendered dense-poi overlays in light and dark appearances
- version bump: 6.4.1 (145) to 6.4.2 (146), patch for refresh and label readability fixes

### 2026-09-06 (v6.4.1, recover shared map data requests)

- coordinate all overpass requests with environmental discovery ahead of background pois
- fall back to a secondary public endpoint for availability failures and remember unavailable hosts
- respect shared rate-limit cooldowns without rotating endpoints on quota refusals
- retain official water-level data by choosing the nearest gauge when waterway discovery fails
- add injected regressions for scheduling, cancellation, fallback, cooldowns, and gauge recovery
- rationale: the unavailable primary overpass service blocked covid, water levels, and every poi category
- version bump: 6.4.0 (144) to 6.4.1 (145), patch for data-loading recovery

### 2026-09-05 (v6.4.0, points of interest restored, 23:30)

- restore all five poi categories with master and individual settings switches, enabled by default
- render every valid onscreen place with compact category symbols in one canvas, retaining apple places and environmental label priority
- retain the 6.7 km search radius, cache per category for an hour within 1 km, and bound requests to two across cancelled generations
- publish successful categories as they arrive so a slow or failing request cannot hold back other places
- give the app delegate explicit startup and shutdown ownership, reuse the existing location stream, and keep popover reopening independent of fetching
- use one core graphics image pass inside canvas after repeated swiftui symbol and image draws crashed the gpu encoder at 10,000 points
- add isolated macos swift testing coverage and deterministic dense map previews
- rationale: avoid per-place annotation views and identity churn while preserving the user's choice to show all places without clustering or thinning
- version bump: 6.3.6 (143) to 6.4.0 (144), minor for restored configurable poi functionality


### 2026-09-05 (v6.3.6, map collision score precision, 22:37)

- replaced area subtraction with nonnegative outside-strip clipping scores, ensuring contained labels score exactly zero.
- excluded negligible floating-point edge noise from overlap scoring without weakening comparator ordering.
- reproduced the unwanted-connector bug with fractional-coordinate tests and verified that genuine clipping still overrides the preferred anchor.
- rationale: rounding errors must not outweigh direct attachment or preserve unnecessary connector lines.
- version bump: 6.3.5 to 6.3.6, build 142 to 143 (PATCH - display correction).

### 2026-09-05 (v6.3.5, direct map label attachment, 22:23)

- restored direct above-right label attachment instead of leaving a clearance gap around each source dot.
- prioritized fewer connectors and natural anchors over retaining old placements, so startup and crowding offsets disappear when space opens up.
- retained geometry-only caching; text refreshes do not determine placement quality.
- added regression tests for direct attachment and removing obsolete connectors after visibility and viewport changes, plus a separated-location preview.
- rationale: labels should visibly belong to their dots and only use lines when displacement is required.
- version bump: 6.3.4 to 6.3.5, build 141 to 142 (PATCH - display correction).

### 2026-09-05 (v6.3.4, map label collision correction, 22:03)

- separated macos map labels using one ordered snapshot, native location dots, and a projected overlay with category-colored connectors.
- added a pure tools layout solver with bounded deterministic beam search, marker clearance, outward anchors, and a viewport grid fallback.
- favored stable placements across refreshes; cached by geometry and kept text updates independent of layout.
- moved projection outside rendering and deferred geometry changes in a cancellable view task to handle transient map registration; retained weather dots when labels are disabled.
- preserved label styling, selectors, region fitting, noninteractive maps, signing, entitlements, pins, and the unvalidated ios presentation.
- added ordinary-import geometry regression tests and deterministic crowded-map previews; validation evidence is recorded in package_validation.md.
- rationale: make crowded measurements readable without changing their geographic meaning or refresh behavior.
- version bump: 6.3.3 to 6.3.4, build 140 to 141 (PATCH - display correction).


### 2026-09-05 (v6.3.3, units tools and services extraction, 21:39)

- moved eight unit files into doom-kit-process and extracted eight utility files into doom-kit-tools and seven service files into doom-kit-services.
- kept tools independent of process models; measurement smoothing callers preserve original metadata and units while creating new value identities.
- exported synchronous sendable trace with mutex-protected formatting and output; retained original filtering and shared logger configuration.
- preserved all 25 static service fetch contracts with trailing injectable network managers and shared tools logging and geometry.
- added ordinary-import regression tests using captured numerical and request fixtures, fake network dependencies, and concurrent file logging.
- rationale: reuse units, tools, and api services across clients without changing app behavior, signing, preferences, or pinned dependencies.
- version bump: 6.3.2 to 6.3.3, build 139 to 140 (PATCH - complete internal refactor).


### 2026-09-05 (v6.3.2, process module expansion, 21:05)

- moved all ten remaining process files into doom-kit-process, with local location and network dependencies and public model/helper contracts.
- opened presenter and transformer bases for app subclasses; retained arbitrary metadata and weak, observation-excluded coordinator cleanup.
- made coordinator construction inactive and injectable; appprocess supplies managers and starts it at the existing first-presenter initialization point.
- retained fallback, first-measurement and settings refresh behavior, with cancellation generations and restart coverage.
- rationale: consolidate process contracts and lifecycle implementation in the agreed single module while preserving app behavior.
- version bump: 6.3.1 to 6.3.2, build 138 to 139 (PATCH - internal refactor).


### 2026-09-05 (v6.3.1, 20:40 CEST extract update packages)

- extracted local doom-kit-location, doom-kit-network, and doom-kit-process packages with swift tools 6.2 and swift 6 language mode; kept the app in swift 5 mode
- declared macos 15 and ios 26 package support; ios validation and integration remain deferred
- replaced location delegates and network notifications with bounded per-consumer state streams and explicit lifecycle ownership
- isolated the initial core location delegate behind an injectable provider; native live updates remain a follow-up with separate behavior validation
- consolidated raw and decoded network requests, added injectable monitoring and timing, and replaced readiness polling with bounded observation
- moved scheduling into an independent main-actor generic manager with uuid removal, registration replacement, and cancel/restart generations
- kept fallback, measured-location, startup, and settings policy in the app coordinator; added per-refresh transformers and cancellation checks before publication
- added deterministic package tests and documented cancellation, shutdown, restart, and injection contracts
- rationale: make update providers replaceable while fixing stale refresh publication and lifecycle leaks
- version bump: 6.3.0 to 6.3.1, build 138 (patch - internal extraction and refresh cancellation fixes)


### 2026-09-05 (v6.3.0, 19:54 CEST consolidate build script)

- made build.sh default to a signed debug build, with separate release and notarization modes
- made clean remove root build outputs and exit unless combined with a build mode
- regenerated the xcodegen project before builds and fixed output paths under .build
- required accepted notarization before stapling and repackaged the stapled app for distribution
- added mock-based script tests for routing, cleanup, and failure handling
- rationale: provide one predictable command for development and distribution workflows
- version bump: none; build tooling changes without application behavior changes

### 2026-09-05 (v6.3.0, 19:43 CEST migrate to xcodegen)

- made project.yml authoritative for the app target, build settings, dependency, and shared scheme
- preserved debug and release settings, signing, entitlements, app version 6.3.0, and build 137
- ignored generated project files while retaining the tracked package lockfile
- documented generation, signing configuration, and command-line builds
- rationale: maintain reproducible project configuration through xcodegen going forward
- version bump: none; build-system migration without application behavior changes

### 2026-09-05 (v6.3.0, 19:38 CEST instruction accuracy update)

- clarified swift language mode and the macos deployment target
- refreshed the technology status date and macos-specific guidance
- replaced unrelated commit examples and corrected the omega symbol name
- rationale: align agent guidance with project settings and remove copied examples
- version bump: none; documentation-only corrections

### 2026-09-05 (v6.3.0, consolidate project history)

- moved the historical updates from AGENTS.md into UPDATES.md, preserving all entries
- linked AGENTS.md to the consolidated log
- rationale: keep current instructions separate from project history
- version bump: none; documentation-only consolidation

### January 9, 2026 (ProcessManager Timer RunLoop Fix)
- **Critical Bug Fix**: Subscription system timer was never firing, causing data to never update after initial load
- **Root Cause**: `Timer.scheduledTimer` was called from inside a `Task` block in `ProcessManager.init()`. Tasks run on a cooperative thread pool where threads lack an active RunLoop, so the timer was scheduled but never fired
- **Solution**: Wrapped timer scheduling in `DispatchQueue.main.async` to ensure the timer is added to the main RunLoop
- **Files Changed**: `ProcessManager.swift`
- **Added Logging**: Added trace log in `updateSubscriptions()` to help verify timer is firing
- **Reasoning**: Foundation `Timer` requires an active RunLoop on its thread. The main thread always has an active RunLoop, ensuring reliable timer execution

### January 9, 2026 (Settings Reactivity - Sensor and Scope Options)
- **Bug Fix**: "Use Nearest Sensor" toggles (Level/Particles) and "Federal vs State" poll scope now trigger immediate data refresh
- **Root Cause**: Settings were only read during periodic data refresh, not when user changed them in settings window
- **Solution**: 
  - Added presenter references to `SettingsView` (`levelPresenter`, `particlePresenter`, `surveyPresenter`)
  - Added `.onChange` modifiers that call `ProcessManager.shared.refreshSubscription(subscriber:)` when settings change
  - Modified `AppDelegate` to store presenter references, passed from main App via `.onAppear`
- **Files Changed**: `SettingsView.swift`, `DashboardOfDoomApp.swift`
- **Reasoning**: When behavioral settings change (not just visibility), the data needs to be re-fetched with the new parameters. Direct presenter access enables immediate refresh

### January 9, 2026 (MapView Settings Reactivity Fix)
- **Bug Fix**: Map annotations and map region now update immediately when services are enabled/disabled in settings
- **Root Cause**: `MapView` was using direct `UserDefaults.standard.bool(forKey:)` calls which SwiftUI does not observe for changes
- **Solution**: Added `@AppStorage` property wrappers to `MapView` for all service visibility settings (`showWeather`, `showCovid`, `showLevels`, `showRadiation`, `showParticles`, `showElectionPolls`)
- **Map Region Updates**: Added `.onChange` modifiers that call `MapPresenter.shared.updateRegion()` when settings change, ensuring the map zooms to fit visible annotations
- **Technical Detail**: `@AppStorage` integrates with SwiftUI's observation system, triggering view re-renders when values change. The `updateMapRegion()` helper registers or removes presenter locations from the `MapPresenter` visible region
- **Reasoning**: Consistent use of `@AppStorage` across views that depend on the same settings ensures reactive UI updates without manual notification mechanisms

### January 9, 2026 (ContentView Header UI Simplification)
- **Header Title Display**: Light mode shows "Dashboard of Doom" text, dark mode shows the logo image (`dashboard-of-doom-logo`)
- **Direct Action Buttons**: Replaced dropdown menu with two direct action buttons in the header bar:
  - `ellipsis.circle` button → Opens settings window via `appDelegate.showSettings()`
  - `togglepower` button → Quits application via `NSApplication.shared.terminate(nil)`
- **Removed AppMenuView**: Deleted `Views/AppMenuView.swift` - buttons now implemented directly in `ContentView.swift`
- **UX Improvement**: Simplified interaction by eliminating popover menu, saving a click for common actions
- **Reasoning**: Direct buttons provide faster access to settings and quit functionality without needing a menu. Color scheme-aware header title maintains brand identity while optimizing for dark mode aesthetics

### December 24, 2025 (Settings Window Implementation)
- **Settings Window Architecture**: Implemented NSPanel-based settings window for menu bar extra application
- **Window Ordering Solution**: Used NSPanel with .popUpMenu level and NSRunningApplication activation to ensure settings window appears in front
- **AppDelegate Environment Injection**: Made AppDelegate @Observable and passed through SwiftUI environment to access from menu bar extra views
- **Technical Details**: SwiftUI's Settings scene incompatible with menu bar extras for proper window ordering. NSPanel with NSHostingController provides reliable control over window levels and activation
- **Implementation Pattern**: Settings persist via @AppStorage directly in SettingsView, no presenter needed. Panel reused across invocations via persistent AppDelegate property
- **Reasoning**: Menu bar extras lack parent windows for activation context. Direct NSPanel management with aggressive activation (NSRunningApplication.current.activate) and high window level (.popUpMenu) ensures settings appear reliably in front of other windows

### November 4, 2025 (Evening Update - Build System)
- **Build Configuration**: Added comprehensive .gitignore file for Xcode project
- **Source Control**: Implemented proper ignore patterns for macOS development including xcuserdata, DerivedData, build artifacts, Swift Package Manager files, dependency managers, fastlane outputs, macOS system files, IDE configurations, and temporary files
- **Reasoning**: Essential for maintaining clean repository state, preventing accidental commits of user-specific settings, build artifacts, and system files. Follows Xcode and Swift community best practices for version control

### November 4, 2025 (Evening Update - README)
- **README.md Modernization**: Updated README.md to reflect macOS-only repository status
- **Platform Focus**: Removed iOS-specific content, badges, and installation instructions
- **Repository Structure**: Updated project structure diagram to show actual macOS-only file organization
- **Installation Updates**: Changed clone URL to heikopanjas/dashboard-of-doom-mac and simplified setup steps for single-platform development
- **Feature Enhancement**: Expanded macOS menu bar application features section with detailed system integration capabilities
- **Architecture Simplification**: Removed cross-platform architecture references, focused on MVP pattern for menu bar apps
- **Reasoning**: After separating repositories, README.md needed comprehensive updates to accurately represent the macOS-only codebase, remove iOS references, and provide clear installation instructions for the new repository location

### November 4, 2025 (Evening Update)
- **Repository Split**: Updated AGENTS.md to reflect macOS-only repository status after separation from iOS codebase
- **Platform Focus**: Removed cross-platform references and iOS-specific content, emphasizing macOS menu bar application architecture
- **Structure Clarification**: Updated Repository Structure, Platform Architecture, Platform-Specific Considerations, Code Organization, and Maintenance Guidelines sections to reflect single-platform focus
- **Reasoning**: The project has been split into separate iOS and macOS repositories. This macOS repository now contains a dedicated menu bar application with similar business logic patterns but platform-specific implementations. Documentation needed to accurately reflect this architectural change and guide future development with correct platform context

### November 4, 2025
- **Documentation Consolidation**: Replaced full content in `.github/copilot-instructions.md` and `CLAUDE.md` with simple references to `AGENTS.md`
- **Implementation Accuracy Update**: Synchronized AGENTS.md with actual codebase implementation details including iOS 26.0+ deployment target, WeatherKit integration, URLSession retry extensions, implemented utilities (ARIMA, MovingAverage, HaversineDistance, PointInPolygon, PolygonProximityCalculator, OSMUtilities, MathematicalSymbols, Trace), and accurate data source listings
- **Git Workflow Enhancement**: Integrated comprehensive commit message guidelines into Development Workflow section with detailed conventional commits format, character limits, special character safety rules, and practical examples to prevent terminal crashes and ensure clean git history
- **Reasoning**: Completed the consolidation process started on November 2nd by removing duplicate content from both agent-specific files and establishing AGENTS.md as the single source of truth. Updated technical specifications to match the current production codebase, ensuring documentation accurately reflects implemented architecture patterns and available utilities. Enhanced git workflow documentation to provide clear, actionable guidance for maintaining code quality and preventing common commit message issues

### November 2, 2025
- **Documentation Restructure**: Moved full instructions from `.github/copilot-instructions.md` to `AGENTS.md` at project root
- **Reasoning**: Centralized agent instructions in a dedicated file for easier maintenance and access, while keeping a simple reference in the GitHub Copilot-specific location

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles

### October 3, 2025
- **Documentation Cleanup**: Removed 'Contributing' section from README.md
- **Reasoning**: Streamlined documentation by removing contribution guidelines, focusing on core project documentation and features

### August 22, 2025
- **Documentation Enhancement**: Added macOS screenshots section to README.md showcasing application UI with four key views (main dashboard, forecast, environment, particles)
- **File Organization**: Moved copilot instructions from root directory to `.github/` for better project structure and GitHub integration
- **README Structure**: Enhanced documentation with professional screenshot layout and maintained existing comprehensive feature descriptions
- **Political Data Visualization**: Added election poll screenshots (state and federal) to showcase comprehensive political polling capabilities
- **Reasoning**: Improved project presentation for potential contributors and users while organizing development guidelines in standard GitHub directory structure
