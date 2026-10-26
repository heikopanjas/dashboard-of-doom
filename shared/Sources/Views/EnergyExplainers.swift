import DoomKitProcess

/// What each price and stock on the Energy tab is, for a reader who does not follow the markets. Both platforms print it under the chart.
enum EnergyExplainers {
    static let text: [ProcessSelector: String] = [
        .energy(.brentSpot):
            "North Sea crude for near-term physical delivery, in US dollars per barrel. EIA's daily spot observations via EuroOilWatch arrive with a publication delay; the chart shows the observation date.",
        .energy(.ttf):
            "Dutch TTF front-month natural gas futures, in euros per megawatt hour, from Yahoo Finance via EuroOilWatch. A European wholesale benchmark, not a household tariff. Daily market observations are shown with their session date; contracts roll near expiry.",
        .energy(.brent):
            "Crude oil from the North Sea. Brent is the reference price for about two thirds of the world's oil, and so for what Europe pays. "
            + "US dollars per barrel for the front-month futures contract, from EuroOilWatch via Yahoo Finance. "
            + "Dates refer to market sessions; between updates the latest available quote or close is shown. The contract rolls as expiry approaches.",
        .energy(.lng):
            "Liquefied natural gas delivered by ship to Europe, per megawatt hour of gas, as assessed each weekday by ACER, the EU energy "
            + "regulator. Germany has imported much of its gas as LNG since 2022, so this follows what heating and power cost here.",
        .energy(.petrolStock):
            "How many days the petrol held in Germany at the end of a month would last at that month's consumption. " + Self.stockSource,
        .energy(.dieselStock):
            "How many days the diesel held in Germany at the end of a month would last at that month's consumption. " + Self.stockSource,
        .energy(.jetFuelStock):
            "How many days the jet fuel held in Germany at the end of a month would last at that month's consumption. " + Self.stockSource,
        .energy(.production):
            "How much oil each country produces a day: crude with condensate and natural gas liquids, in million barrels, from the U.S. "
            + "Energy Information Administration's international data via AmericasOilWatch. Monthly, published three to four months after "
            + "the month it describes; the app's estimate bridges the months since. Each country is placed at its capital."
    ]

    private static let stockSource =
        "From Eurostat's monthly oil statistics via EuroOilWatch, published two to three months after the month they describe; the app's "
        + "estimate bridges the months since. The red line is the minimum EuroOilWatch measures the stock against, and the badge its "
        + "assessment of the latest month."
}
