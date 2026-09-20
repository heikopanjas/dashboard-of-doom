import Foundation

public struct ProcessValue<T: Dimension>: Identifiable {
    public let id = UUID()
    public let value: Measurement<T>
    public let customData: [String: Any]?
    public let quality: ProcessQuality
    public let timestamp: Date

    public init(value: Measurement<T>, customData: [String: Any]?, quality: ProcessQuality, timestamp: Date) {
        self.value = value
        self.customData = customData
        self.quality = quality
        self.timestamp = timestamp
    }

    public init(value: Measurement<T>, quality: ProcessQuality, timestamp: Date) {
        self.init(value: value, customData: nil, quality: quality, timestamp: timestamp)
    }

    public init(value: Measurement<T>, quality: ProcessQuality) {
        self.init(value: value, quality: quality, timestamp: Date.now)
    }

    public init(value: Measurement<T>) {
        self.init(value: value, quality: .unknown)
    }

    public init() {
        self.init(value: Measurement<T>(value: 0, unit: T.baseUnit()), quality: .unknown)
    }
}
