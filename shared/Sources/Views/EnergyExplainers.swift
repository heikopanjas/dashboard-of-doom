import DoomKitProcess

/// What each price on the Energy tab is, for a reader who does not follow the markets. Both platforms print it under the chart.
enum EnergyExplainers {
    static let text: [ProcessSelector: String] = [
        .energy(.brent):
            "Crude oil from the North Sea. Brent is the reference price for about two thirds of the world's oil, and so for what Europe pays. "
            + "US dollars per barrel, the spot price on each trading day, from the US Energy Information Administration.",
        .energy(.wti):
            "West Texas Intermediate, the US reference crude, priced at Cushing, Oklahoma. It usually trades a few dollars below Brent; "
            + "a wider gap means American oil is hard to get to the coast. Same source as Brent.",
        .energy(.lng):
            "Liquefied natural gas delivered by ship to Europe, per megawatt hour of gas, as assessed each weekday by ACER, the EU energy "
            + "regulator. Germany has imported much of its gas as LNG since 2022, so this follows what heating and power cost here.",
    ]
}
