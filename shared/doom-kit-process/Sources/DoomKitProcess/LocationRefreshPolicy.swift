/// Controls immediate refreshes after the location source accepts a measurement.
public enum LocationRefreshPolicy: Sendable {
    case firstMeasurement
    case everyMovement
}
