public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case noData
    case decodingError(error: any Error)
    case networkUnavailable
    case taskCancelled
    case timeout
}
