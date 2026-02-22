//
//  BeeperAPIClient.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import Foundation

@Observable
final class BeeperAPIClient {
    let baseURL: String
    let token: String

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = ISO8601DateFormatter.shared.date(from: str) {
                return date
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    init(baseURL: String = "http://localhost:23373", token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BeeperAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BeeperAPIError.httpError(statusCode: http.statusCode, message: message)
        }
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Info

    func getInfo() async throws -> ConnectInfoResponse {
        let components = URLComponents(string: baseURL + "/v1/info")!
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BeeperAPIError.invalidResponse
        }
        return try decoder.decode(ConnectInfoResponse.self, from: data)
    }

    // MARK: - Accounts

    func getAccounts() async throws -> [BeeperAccount] {
        try await request(path: "/v1/accounts")
    }

    // MARK: - Chats

    func listChats(cursor: String? = nil, direction: String? = nil, accountIDs: [String]? = nil) async throws -> ListChatsResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        if let direction { items.append(.init(name: "direction", value: direction)) }
        if let accountIDs {
            for id in accountIDs {
                items.append(.init(name: "accountIDs", value: id))
            }
        }
        return try await request(path: "/v1/chats", queryItems: items)
    }

    func getChat(chatID: String, maxParticipantCount: Int? = nil) async throws -> BeeperChat {
        var items: [URLQueryItem] = []
        if let max = maxParticipantCount {
            items.append(.init(name: "maxParticipantCount", value: String(max)))
        }
        let encoded = chatID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chatID
        return try await request(path: "/v1/chats/\(encoded)", queryItems: items)
    }

    func searchChats(
        inbox: String? = nil,
        unreadOnly: Bool? = nil,
        query: String? = nil,
        accountIDs: [String]? = nil,
        cursor: String? = nil,
        direction: String? = nil
    ) async throws -> SearchChatsResponse {
        var items: [URLQueryItem] = []
        if let inbox { items.append(.init(name: "inbox", value: inbox)) }
        if let unreadOnly { items.append(.init(name: "unreadOnly", value: String(unreadOnly))) }
        if let query { items.append(.init(name: "query", value: query)) }
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        if let direction { items.append(.init(name: "direction", value: direction)) }
        if let accountIDs {
            for id in accountIDs {
                items.append(.init(name: "accountIDs", value: id))
            }
        }
        return try await request(path: "/v1/chats/search", queryItems: items)
    }

    // MARK: - Messages

    func listMessages(chatID: String, cursor: String? = nil, direction: String? = nil) async throws -> ListMessagesResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        if let direction { items.append(.init(name: "direction", value: direction)) }
        let encoded = chatID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chatID
        return try await request(path: "/v1/chats/\(encoded)/messages", queryItems: items)
    }

    func searchMessages(
        query: String? = nil,
        chatIDs: [String]? = nil,
        accountIDs: [String]? = nil,
        chatType: String? = nil,
        mediaTypes: [String]? = nil,
        sender: String? = nil,
        dateAfter: Date? = nil,
        dateBefore: Date? = nil,
        limit: Int? = nil,
        cursor: String? = nil,
        direction: String? = nil,
        includeMuted: Bool? = nil
    ) async throws -> SearchMessagesResponse {
        var items: [URLQueryItem] = []
        if let query { items.append(.init(name: "query", value: query)) }
        if let chatType { items.append(.init(name: "chatType", value: chatType)) }
        if let sender { items.append(.init(name: "sender", value: sender)) }
        if let limit { items.append(.init(name: "limit", value: String(limit))) }
        if let cursor { items.append(.init(name: "cursor", value: cursor)) }
        if let direction { items.append(.init(name: "direction", value: direction)) }
        if let includeMuted { items.append(.init(name: "includeMuted", value: String(includeMuted))) }
        if let chatIDs {
            for id in chatIDs { items.append(.init(name: "chatIDs", value: id)) }
        }
        if let accountIDs {
            for id in accountIDs { items.append(.init(name: "accountIDs", value: id)) }
        }
        if let mediaTypes {
            for t in mediaTypes { items.append(.init(name: "mediaTypes", value: t)) }
        }
        if let dateAfter {
            items.append(.init(name: "dateAfter", value: ISO8601DateFormatter.shared.string(from: dateAfter)))
        }
        if let dateBefore {
            items.append(.init(name: "dateBefore", value: ISO8601DateFormatter.shared.string(from: dateBefore)))
        }
        return try await request(path: "/v1/messages/search", queryItems: items)
    }

    // MARK: - Fetch All Chats (paginated)

    func fetchAllChats(accountIDs: [String]? = nil, progress: ((Int) -> Void)? = nil) async throws -> [BeeperChat] {
        var allChats: [BeeperChat] = []
        var cursor: String? = nil
        while true {
            let response = try await listChats(cursor: cursor, direction: cursor != nil ? "before" : nil, accountIDs: accountIDs)
            allChats.append(contentsOf: response.items)
            progress?(allChats.count)
            guard response.hasMore, let next = response.oldestCursor else { break }
            cursor = next
        }
        return allChats
    }
    // MARK: - Focus (Open Chat in Beeper)

    func focusChat(chatID: String) async throws {
        let url = URL(string: baseURL + "/v1/focus")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["chatId": chatID]
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BeeperAPIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
    }
}

// MARK: - Errors

enum BeeperAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Beeper Desktop"
        case .httpError(let code, let message):
            "HTTP \(code): \(message)"
        }
    }
}

// MARK: - ISO8601 Shared Formatter

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
