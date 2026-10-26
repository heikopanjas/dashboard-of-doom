/// Whether a presenter's nearest sensor takes part in fitting the map camera.
enum ProcessMapVisibility {
    /// The source never touches the map region.
    case never
    /// The source always contributes its location.
    case always
    /// The source contributes its location while the closure returns true, and is removed from the region otherwise.
    case conditional(@MainActor () -> Bool)
}
