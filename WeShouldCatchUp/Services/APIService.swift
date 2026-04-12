import Foundation
import FirebaseAuth

// MARK: - Response Types

struct GoLiveResponse: Codable {
    let status: String
    let liveSince: String?
    let liveTTL: String?
}

struct AcceptPingResponse: Codable {
    let agoraChannel: String
    let agoraToken: String
    let callId: String
}

struct EndCallResponse: Codable {
    let status: String
    let duration: Int // seconds
}

struct JoinCallResponse: Codable {
    let agoraChannel: String
    let agoraToken: String
    let callId: String
}

struct CreateCatchupResponse: Codable {
    let catchupId: String
    let inviteLink: String
}

struct AcceptCatchupResponse: Codable {
    let status: String
    let catchupId: String
}

struct RemoveCatchupResponse: Codable {
    let status: String
}

struct CancelLiveResponse: Codable {
    let status: String
}

struct CallHistoryItem: Codable, Identifiable {
    let callId: String
    let otherUser: OtherUser
    let startedAt: String // ISO 8601
    let endedAt: String?  // ISO 8601
    let duration: Int?    // seconds

    var id: String { callId }

    struct OtherUser: Codable {
        let userId: String
        let name: String
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .notAuthenticated:
            return "User is not authenticated. Please sign in."
        case .httpError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Service

/// Singleton backend API client. All methods inject the Firebase Auth ID token automatically.
final class APIService {

    static let shared = APIService()

    private let baseURL: String = Constants.backendBaseURL

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Auth Token

    /// Retrieves the Firebase ID token for the currently signed-in user.
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.notAuthenticated
        }
        let token = try await user.getIDToken()
        return token
    }

    // MARK: - Request Builder

    /// Builds an authenticated URLRequest for the given endpoint.
    private func authorizedRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        let token = try await getAuthToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    /// Executes a request and decodes the response into the specified type.
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                NSError(domain: "APIService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type."
                ])
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Live Status

    /// POST /go-live -- Sets the current user's status to "live".
    func goLive() async throws -> GoLiveResponse {
        let request = try await authorizedRequest(path: "/go-live", method: "POST")
        return try await execute(request)
    }

    /// POST /cancel-live -- Cancels the current user's live status.
    func cancelLive() async throws -> CancelLiveResponse {
        let request = try await authorizedRequest(path: "/cancel-live", method: "POST")
        return try await execute(request)
    }

    // MARK: - Calls

    /// POST /accept-ping -- Accepts an incoming catch-up ping and retrieves Agora channel details.
    func acceptPing(catchupId: String, callId: String) async throws -> AcceptPingResponse {
        let body: [String: Any] = [
            "catchupId": catchupId,
            "callId": callId
        ]
        let request = try await authorizedRequest(path: "/accept-ping", method: "POST", body: body)
        return try await execute(request)
    }

    /// POST /join-call -- User A calls this after receiving call_ready push to get Agora credentials.
    func joinCall(callId: String) async throws -> JoinCallResponse {
        let body: [String: Any] = ["callId": callId]
        let request = try await authorizedRequest(path: "/join-call", method: "POST", body: body)
        return try await execute(request)
    }

    /// POST /end-call -- Ends the active call and returns duration.
    func endCall(callId: String) async throws -> EndCallResponse {
        let body: [String: Any] = ["callId": callId]
        let request = try await authorizedRequest(path: "/end-call", method: "POST", body: body)
        return try await execute(request)
    }

    // MARK: - Catch-ups

    /// POST /create-catchup -- Creates a new catch-up pair and returns an invite link.
    func createCatchup(invitedName: String? = nil) async throws -> CreateCatchupResponse {
        var body: [String: Any]? = nil
        if let name = invitedName {
            body = ["invitedName": name]
        }
        let request = try await authorizedRequest(path: "/create-catchup", method: "POST", body: body)
        return try await execute(request)
    }

    /// POST /accept-catchup -- Accepts a catch-up invite.
    func acceptCatchup(catchupId: String) async throws -> AcceptCatchupResponse {
        let body: [String: Any] = ["catchupId": catchupId]
        let request = try await authorizedRequest(path: "/accept-catchup", method: "POST", body: body)
        return try await execute(request)
    }

    /// POST /remove-catchup -- Removes a catch-up pair.
    func removeCatchup(catchupId: String) async throws -> RemoveCatchupResponse {
        let body: [String: Any] = ["catchupId": catchupId]
        let request = try await authorizedRequest(path: "/remove-catchup", method: "POST", body: body)
        return try await execute(request)
    }

    // MARK: - Profile

    /// Updates the current user's display name on the backend.
    func updateDisplayName(_ name: String) async throws {
        let body: [String: Any] = ["displayName": name]
        let request = try await authorizedRequest(path: "/update-profile", method: "POST", body: body)
        let _: [String: String] = try await execute(request)
    }

    /// Saves the FCM push token to the backend.
    func updateFCMToken(_ token: String) async throws {
        let body: [String: Any] = ["fcmToken": token]
        let request = try await authorizedRequest(path: "/update-fcm-token", method: "POST", body: body)
        let _: [String: String] = try await execute(request)
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        let request = try await authorizedRequest(path: "/delete-account", method: "POST", body: nil)
        let _: [String: String] = try await execute(request)
    }

    // MARK: - Queue Reordering

    /// POST /reorder-queue -- Saves the user's custom queue order.
    func reorderQueue(catchupIds: [String]) async throws {
        let body: [String: Any] = ["catchupIds": catchupIds]
        let request = try await authorizedRequest(path: "/reorder-queue", method: "POST", body: body)
        let _: [String: String] = try await execute(request)
    }

    // MARK: - Queue & History

    /// GET /my-queue -- Fetches the user's current catch-up queue.
    func fetchQueue() async throws -> [QueueItem] {
        let request = try await authorizedRequest(path: "/my-queue", method: "GET")
        return try await execute(request)
    }

    /// GET /call-history -- Fetches the user's past call history.
    func fetchCallHistory() async throws -> [CallHistoryItem] {
        let request = try await authorizedRequest(path: "/call-history", method: "GET")
        return try await execute(request)
    }
}
