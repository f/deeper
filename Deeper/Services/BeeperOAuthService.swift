//
//  BeeperOAuthService.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import AppKit
import AuthenticationServices
import CryptoKit
import Foundation

enum BeeperOAuthError: LocalizedError {
    case invalidAuthURL
    case invalidTokenURL
    case authCancelled
    case authFailed(String)
    case invalidCallback
    case stateMismatch
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidAuthURL:
            "Invalid OAuth authorization URL"
        case .invalidTokenURL:
            "Invalid OAuth token URL"
        case .authCancelled:
            "Authorization was cancelled"
        case .authFailed(let message):
            message
        case .invalidCallback:
            "Authorization callback was invalid"
        case .stateMismatch:
            "OAuth state mismatch"
        case .tokenExchangeFailed(let message):
            message
        }
    }
}

final class BeeperOAuthService {
    private let baseURL: String
    private let callbackScheme = "deeper"
    private let callbackPath = "/oauth/callback"
    private var authSession: ASWebAuthenticationSession?
    private var presentationContextProvider: BeeperAuthPresentationContextProvider?

    init(baseURL: String = "http://localhost:23373") {
        self.baseURL = baseURL
    }

    func authorizeAndGetToken() async throws -> String {
        let info = try await fetchInfo()
        let pkce = try Self.generatePKCE()
        let state = try Self.generateState()
        let redirectURI = "\(callbackScheme):\(callbackPath)"
        let clientID = Bundle.main.bundleIdentifier ?? "dev.fka.Deeper"

        guard var components = URLComponents(string: info.endpoints.oauth.authorization_endpoint) else {
            throw BeeperOAuthError.invalidAuthURL
        }
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: "read"),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizationURL = components.url else {
            throw BeeperOAuthError.invalidAuthURL
        }

        let callbackURL = try await startAuthorizationSession(url: authorizationURL, callbackScheme: callbackScheme)
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw BeeperOAuthError.invalidCallback
        }

        let callbackItems = callbackComponents.queryItems ?? []
        if let errorValue = callbackItems.first(where: { $0.name == "error" })?.value {
            throw BeeperOAuthError.authFailed("Authorization failed: \(errorValue)")
        }
        guard let code = callbackItems.first(where: { $0.name == "code" })?.value else {
            throw BeeperOAuthError.invalidCallback
        }
        guard let returnedState = callbackItems.first(where: { $0.name == "state" })?.value, returnedState == state else {
            throw BeeperOAuthError.stateMismatch
        }

        return try await exchangeCodeForToken(
            tokenEndpoint: info.endpoints.oauth.token_endpoint,
            code: code,
            verifier: pkce.verifier,
            clientID: clientID,
            redirectURI: redirectURI
        )
    }

    func fetchInfo() async throws -> ConnectInfoResponse {
        guard let url = URL(string: baseURL + "/v1/info") else {
            throw BeeperAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BeeperAPIError.invalidResponse
        }
        return try JSONDecoder().decode(ConnectInfoResponse.self, from: data)
    }

    private func exchangeCodeForToken(
        tokenEndpoint: String,
        code: String,
        verifier: String,
        clientID: String,
        redirectURI: String
    ) async throws -> String {
        guard let url = URL(string: tokenEndpoint) else {
            throw BeeperOAuthError.invalidTokenURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let params: [URLQueryItem] = [
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code", value: code),
            .init(name: "code_verifier", value: verifier),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
        ]

        var body = URLComponents()
        body.queryItems = params
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BeeperOAuthError.tokenExchangeFailed("Invalid token response")
        }

        if (200...299).contains(http.statusCode) {
            let tokenResponse = try JSONDecoder().decode(BeeperTokenResponse.self, from: data)
            return tokenResponse.access_token
        }

        if
            let oauthError = try? JSONDecoder().decode(BeeperTokenErrorResponse.self, from: data),
            let description = oauthError.error_description
        {
            throw BeeperOAuthError.tokenExchangeFailed(description)
        }

        let rawMessage = String(data: data, encoding: .utf8) ?? "Token exchange failed"
        throw BeeperOAuthError.tokenExchangeFailed(rawMessage)
    }

    @MainActor
    private func startAuthorizationSession(url: URL, callbackScheme: String) async throws -> URL {
        let contextProvider = BeeperAuthPresentationContextProvider()
        self.presentationContextProvider = contextProvider

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                self.authSession = nil
                self.presentationContextProvider = nil

                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                    continuation.resume(throwing: BeeperOAuthError.authCancelled)
                    return
                }

                continuation.resume(throwing: BeeperOAuthError.authFailed(error?.localizedDescription ?? "Authorization failed"))
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = true

            self.authSession = session
            if !session.start() {
                self.authSession = nil
                self.presentationContextProvider = nil
                continuation.resume(throwing: BeeperOAuthError.authFailed("Failed to start authorization session"))
            }
        }
    }

    private static func generatePKCE() throws -> (verifier: String, challenge: String) {
        let verifierData = try secureRandomData(count: 64)
        let verifier = base64URLEncode(verifierData)
        let challenge = base64URLEncode(Data(SHA256.hash(data: verifier.data(using: .utf8)!)))
        return (verifier, challenge)
    }

    private static func generateState() throws -> String {
        base64URLEncode(try secureRandomData(count: 32))
    }

    private static func secureRandomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw BeeperOAuthError.authFailed("Failed to generate secure random bytes")
        }
        return Data(bytes)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class BeeperAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

private struct BeeperTokenResponse: Decodable {
    let access_token: String
}

private struct BeeperTokenErrorResponse: Decodable {
    let error: String
    let error_description: String?
}
