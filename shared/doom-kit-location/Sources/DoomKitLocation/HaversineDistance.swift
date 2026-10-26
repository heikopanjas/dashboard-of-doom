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

public func averageRadius(_ latitude0: Double, _ latitude1: Double) -> Double {
    return (radiusAtLocation(latitude0) + radiusAtLocation(latitude1)) / 2
}

public func haversineDistance(latitude0: Double, longitude0: Double, latitude1: Double, longitude1: Double) -> Measurement<UnitLength> {

    let lat1 = degreesToRadians(latitude0)
    let lon1 = degreesToRadians(longitude0)

    let lat2 = degreesToRadians(latitude1)
    let lon2 = degreesToRadians(longitude1)

    let latitudeDistance = lat2 - lat1
    let longitudeDistance = lon2 - lon1

    let a =
        pow(sin(latitudeDistance / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(longitudeDistance / 2), 2)

    let c = 2 * asin(sqrt(a))

    let earthRadius = 6371000.0  // meters

    let distance = earthRadius * c

    return Measurement(value: distance, unit: UnitLength.meters)
}

public func haversineDistance(location0: Location, location1: Location) -> Measurement<UnitLength> {
    return haversineDistance(
        latitude0: location0.latitude, longitude0: location0.longitude,
        latitude1: location1.latitude, longitude1: location1.longitude)
}
