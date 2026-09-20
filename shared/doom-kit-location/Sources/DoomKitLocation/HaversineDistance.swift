import Foundation

public func degreesToRadians(_ degrees: Double) -> Double {
    return degrees * .pi / 180
}

public func radiusAtLocation(_ latitude: Double) -> Double {
    let polarRadius = Measurement(value: 6356752.3, unit: UnitLength.meters)
    let equatorialRadius = Measurement(value: 6378137.0, unit: UnitLength.meters)
    return sqrt(pow(polarRadius.value, 2) * pow(cos(latitude), 2) + pow(equatorialRadius.value, 2) * pow(sin(latitude), 2))
        / sqrt(pow(polarRadius.value * cos(latitude), 2) + pow(equatorialRadius.value * sin(latitude), 2))
}

public func averageRadius(_ latitude_0: Double, _ latidude_1: Double) -> Double {
    return (radiusAtLocation(latitude_0) + radiusAtLocation(latidude_1)) / 2
}

public func haversineDistance(latitude_0: Double, longitude_0: Double, latitude_1: Double, longitude_1: Double) -> Measurement<UnitLength> {

    let LAT1 = degreesToRadians(latitude_0)
    let LON1 = degreesToRadians(longitude_0)

    let LAT2 = degreesToRadians(latitude_1)
    let LON2 = degreesToRadians(longitude_1)

    let latitudeDistance = LAT2 - LAT1
    let longitudeDistance = LON2 - LON1

    let A =
        pow(sin(latitudeDistance / 2), 2) + cos(LAT1) * cos(LAT2) * pow(sin(longitudeDistance / 2), 2)

    let C = 2 * asin(sqrt(A))

    let R = 6371000.0  // Radius of the Earth in meters

    let distance = R * C

    return Measurement(value: distance, unit: UnitLength.meters)
}

public func haversineDistance(location_0: Location, location_1: Location) -> Measurement<UnitLength> {
    return haversineDistance(
        latitude_0: location_0.latitude, longitude_0: location_0.longitude,
        latitude_1: location_1.latitude, longitude_1: location_1.longitude)
}
