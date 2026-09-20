public struct GeocodedPlace: Sendable, Equatable {
    public var name: String?
    public var postalCode: String?
    public var locality: String?
    public var subLocality: String?
    public var administrativeArea: String?
    public var subAdministrativeArea: String?

    public init(
        name: String? = nil, postalCode: String? = nil, locality: String? = nil,
        subLocality: String? = nil, administrativeArea: String? = nil,
        subAdministrativeArea: String? = nil
    ) {
        self.name = name
        self.postalCode = postalCode
        self.locality = locality
        self.subLocality = subLocality
        self.administrativeArea = administrativeArea
        self.subAdministrativeArea = subAdministrativeArea
    }

    public var constituency: String? {
        return self.administrativeArea ?? self.subAdministrativeArea ?? self.locality
    }

    public func address(full: Bool) -> String {
        if full == false {
            return (self.locality ?? "") + (self.subLocality.map { "-" + $0 } ?? "")
        }
        var result = self.name ?? ""
        if let postalCode = self.postalCode, let locality = self.locality {
            result += (result.isEmpty == true ? "" : ", ") + postalCode + " " + locality
            if let subLocality = self.subLocality { result += "-" + subLocality }
        }
        return result
    }
}
