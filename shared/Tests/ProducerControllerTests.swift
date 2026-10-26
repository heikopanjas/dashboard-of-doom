import DoomKitLocation
import DoomKitNetwork
import DoomKitProcess
import Foundation
import Testing

@Suite struct ProducerControllerTests {
    private actor Monitor: NetworkMonitoring {
        func start(_ receive: @escaping @Sendable (Bool, ConnectionType) -> Void) { receive(true, .wifi) }
        func stop() {}
    }

    /// AmericasOilWatch's shape, trimmed: the latest month of Saudi Arabia replaces its history's figure, Iraq has a newer latest month
    /// than its history, a member outside the six is ignored, and Kuwait and Oman are missing.
    private static let opec = """
        {"latestDataPeriod":"2026-06","members":[
        {"code":"RUS","name":"Russia","group":"Non-OPEC","latestKbpd":10234,"latestPeriod":"2026-06","history":[]},
        {"code":"IRQ","name":"Iraq","group":"OPEC","latestKbpd":2003,"latestPeriod":"2026-06",
         "history":[{"period":"2026-05","kbpd":4100},{"period":"bad","kbpd":1}]},
        {"code":"SAU","name":"Saudi Arabia","group":"OPEC","latestKbpd":8409.5,"latestPeriod":"2026-06",
         "history":[{"period":"2026-06","kbpd":8000},{"period":"2026-05","kbpd":8900},{"period":"2026-04","kbpd":null}]},
        {"code":"IRN","name":"Iran","group":"OPEC","latestKbpd":3477,"latestPeriod":"2026-06",
         "history":[{"period":"2024-12","kbpd":3100},{"period":"2026-05","kbpd":3400}]},
        {"code":"ARE","name":"UAE","group":"OPEC","latestKbpd":4517,"latestPeriod":"2026-06","history":[]}]}
        """

    @Test func productionIsInMillionBarrelsAtMonthEndsWithTheLatestMonthLaidOver() throws {
        let series = ProducerController.parseProduction(Data(Self.opec.utf8))
        let saudi = try #require(series["SAU"])
        #expect(saudi.group == "OPEC")
        #expect(saudi.values.map { $0.value.value } == [8.9, 8.4095])
        #expect(saudi.values.last?.value.unit == UnitOilProduction.millionBarrelsPerDay)
        #expect(saudi.values.last?.timestamp == Date.monthEnd(from: "2026-06"))
        #expect(saudi.values.last?.customData?["period"] as? String == "2026-06")
        #expect(series["IRQ"]?.values.map { $0.value.value } == [4.1, 2.003])
        #expect(ProducerController.parseProduction(Data("not json".utf8)).isEmpty == true)
    }

    @Test func theSensorsAreTheGulfSixInTheirOrderAndSkipWhatIsMissing() async throws {
        let network = NetworkManager(
            transport: { request in
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data(Self.opec.utf8), response)
            }, makeMonitor: { Monitor() }, probeURL: nil)
        let updates = await network.updates()
        await network.startMonitoring()
        for await state in updates where state.isConnected == true { break }
        let sensors = try await ProducerController(networkManager: network, showForecasts: { false })
            .refreshData(for: Location(latitude: 52.51889, longitude: 13.36528))
        await network.stopMonitoring()
        // The six's order, Kuwait and Oman missing, Russia not among them.
        #expect(sensors.map { $0.sourceID } == ["SAU", "ARE", "IRN", "IRQ"])
        #expect(sensors.map { $0.name } == ["Saudi Arabia", "UAE", "Iran", "Iraq"])
        let saudi = try #require(sensors.first)
        #expect(saudi.location == ProducerController.producers[0].location)
        #expect(saudi.customData?["icon"] as? String == "drop.fill")
        #expect(saudi.measurements[.energy(.production)]?.count == 2)
        // The charts start in 2025: Iran's December 2024 is parsed but not shown.
        #expect(sensors[2].measurements[.energy(.production)]?.map { $0.value.value } == [3.4, 3.477])
        #expect(saudi.forecasts.isEmpty == true)
        #expect(ProducerController.producers.map { $0.code } == ["SAU", "ARE", "IRN", "IRQ", "KWT", "OMN"])
    }

    @Test func productionShowsTwoDecimalsAndItsMonth() throws {
        let date = try #require(Date.monthEnd(from: "2026-06"))
        let value = ProcessValue<Dimension>(
            value: Measurement(value: 8.4095, unit: UnitOilProduction.millionBarrelsPerDay), quality: .good, timestamp: date)
        #expect(EnergyDisplay.valueText(value, for: .energy(.production)) == "8.41 mb/d")
        #expect(EnergyDisplay.dateText(date, for: .energy(.production)) == date.formatted(.dateTime.month(.abbreviated).year()))
        // No title: the country's header above the chart names it.
        #expect(EnergyDisplay.title(for: .energy(.production)).isEmpty == true)
    }
}
