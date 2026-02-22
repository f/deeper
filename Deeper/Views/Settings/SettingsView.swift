//
//  SettingsView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let deeperDidLogout = Notification.Name("deeper.did.logout")
}

struct SettingsView: View {
    var onConnect: (BeeperAPIClient) -> Void
    var closeOnDisconnect: Bool = false
    @Environment(\.openURL) private var openURL

    @State private var isAuthorizing = false
    @State private var isCheckingAPI = false
    @State private var isAPIAvailable = false
    @State private var token: String = ""
    @State private var baseURL: String = KeychainHelper.loadBaseURL() ?? "http://localhost:23373"
    @State private var isConnecting = false
    @State private var connectionInfo: ConnectInfoResponse?
    @State private var error: String?
    @State private var hasExistingToken = false
    @State private var showAdvancedWindow = false

    var body: some View {
        Form {
            // MARK: - Connection Section
            Section {
                if hasExistingToken, let info = connectionInfo {
                    // Connected state
                    LabeledContent("Status") {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    LabeledContent("App") {
                        Text("\(info.app.name) v\(info.app.version)")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Platform") {
                        Text("\(info.platform.os) (\(info.platform.arch))")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Server") {
                        Text(info.server.base_url)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } else if isCheckingAPI {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking API…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !isAPIAvailable {
                    LabeledContent("Status") {
                        Label("API Unavailable", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enable Beeper Desktop API:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("1. Open Beeper Desktop → Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("2. Go to the Developers tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("3. Toggle Beeper Desktop API to On")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Status") {
                        Label("Ready to connect", systemImage: "circle.dotted")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Beeper Desktop")
            }

            // MARK: - Actions Section
            Section {
                if hasExistingToken {
                    Button(role: .destructive) {
                        disconnect()
                    } label: {
                        Text("Disconnect")
                    }
                } else {
                    Button(action: authorizeWithBeeper) {
                        if isAuthorizing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Connecting…")
                            }
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(isAuthorizing || isConnecting || isCheckingAPI || !isAPIAvailable)

                    if !isAPIAvailable && !isCheckingAPI {
                        HStack(spacing: 8) {
                            Button("Open Beeper") {
                                if let url = URL(string: "beeper://connect") {
                                    openURL(url)
                                }
                            }
                            Button("Refresh") {
                                Task { await refreshAPIAvailability() }
                            }
                        }
                    }

                    Button("Advanced…") {
                        showAdvancedWindow = true
                    }
                }

                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } header: {
                Text("Connection")
            }

            // MARK: - About Section
            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Author") {
                    Text("Fatih Kadir Akin")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("License") {
                    Text("MIT")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            Section {
                Link(destination: URL(string: "https://github.com/f/deeper")!) {
                    LabeledContent("Source Code") {
                        HStack(spacing: 4) {
                            Text("github.com/f/deeper")
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Link(destination: URL(string: "https://github.com/f/deeper/releases")!) {
                    LabeledContent("Releases") {
                        HStack(spacing: 4) {
                            Text("Changelog & Downloads")
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Link(destination: URL(string: "https://developers.beeper.com/desktop-api")!) {
                    LabeledContent("Beeper API Docs") {
                        HStack(spacing: 4) {
                            Text("developers.beeper.com")
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Link(destination: URL(string: "https://github.com/f/deeper/issues")!) {
                    LabeledContent("Report an Issue") {
                        HStack(spacing: 4) {
                            Text("GitHub Issues")
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Links")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            Task {
                baseURL = KeychainHelper.loadBaseURL() ?? "http://localhost:23373"
                await refreshAPIAvailability()
                if let saved = KeychainHelper.loadToken() {
                    token = saved
                    hasExistingToken = true
                    testConnection(token: saved)
                }
            }
        }
        .sheet(isPresented: $showAdvancedWindow) {
            AdvancedConnectView(initialBaseURL: baseURL, initialToken: token) { testedBaseURL, testedToken, testedInfo in
                connectWithVerifiedCredentials(baseURL: testedBaseURL, token: testedToken, info: testedInfo)
                showAdvancedWindow = false
            }
        }
    }

    private func connect() {
        guard !token.isEmpty else { return }
        isConnecting = true
        error = nil

        Task {
            do {
                let client = BeeperAPIClient(baseURL: baseURL, token: token)
                let info = try await validateConnection(baseURL: baseURL, token: token)
                connectionInfo = info
                KeychainHelper.saveToken(token)
                KeychainHelper.saveBaseURL(baseURL)
                hasExistingToken = true
                onConnect(client)
            } catch {
                self.error = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func testConnection(token: String) {
        Task {
            do {
                let client = BeeperAPIClient(baseURL: baseURL, token: token)
                let info = try await validateConnection(baseURL: baseURL, token: token)
                connectionInfo = info
                onConnect(client)
            } catch {
                self.error = "Saved token invalid: \(error.localizedDescription)"
            }
        }
    }

    private func authorizeWithBeeper() {
        isAuthorizing = true
        error = nil

        Task {
            do {
                guard await ensureAPIAvailable() else {
                    isAuthorizing = false
                    return
                }
                let oauth = BeeperOAuthService(baseURL: baseURL)
                let issuedToken = try await oauth.authorizeAndGetToken()
                token = issuedToken
                isAuthorizing = false
                connect()
            } catch {
                self.error = error.localizedDescription
                isAuthorizing = false
            }
        }
    }

    private func ensureAPIAvailable() async -> Bool {
        await refreshAPIAvailability()
        if !isAPIAvailable {
            error = "Turn on Beeper Desktop API in Beeper Settings → Developers, then try again."
        }
        return isAPIAvailable
    }

    private func refreshAPIAvailability() async {
        isCheckingAPI = true
        defer { isCheckingAPI = false }

        do {
            let oauth = BeeperOAuthService(baseURL: baseURL)
            _ = try await oauth.fetchInfo()
            isAPIAvailable = true
        } catch {
            isAPIAvailable = false
        }
    }

    private func validateConnection(baseURL: String, token: String) async throws -> ConnectInfoResponse {
        let client = BeeperAPIClient(baseURL: baseURL, token: token)
        _ = try await client.getAccounts()
        return try await client.getInfo()
    }

    private func connectWithVerifiedCredentials(baseURL: String, token: String, info: ConnectInfoResponse) {
        self.baseURL = baseURL
        self.token = token
        self.connectionInfo = info
        self.error = nil
        self.hasExistingToken = true

        KeychainHelper.saveBaseURL(baseURL)
        KeychainHelper.saveToken(token)

        let client = BeeperAPIClient(baseURL: baseURL, token: token)
        onConnect(client)
    }

    private func disconnect() {
        KeychainHelper.deleteToken()
        KeychainHelper.deleteBaseURL()
        token = ""
        baseURL = "http://localhost:23373"
        connectionInfo = nil
        hasExistingToken = false
        NotificationCenter.default.post(name: .deeperDidLogout, object: nil)
        if closeOnDisconnect {
            NSApplication.shared.keyWindow?.performClose(nil)
        }
    }
}

struct AdvancedConnectView: View {
    let initialBaseURL: String
    let initialToken: String
    let onConnect: (String, String, ConnectInfoResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var baseURL: String
    @State private var token: String
    @State private var testedBaseURL: String?
    @State private var testedToken: String?
    @State private var testedInfo: ConnectInfoResponse?
    @State private var isTesting = false
    @State private var isConnecting = false
    @State private var error: String?
    @FocusState private var tokenFocused: Bool

    init(initialBaseURL: String, initialToken: String, onConnect: @escaping (String, String, ConnectInfoResponse) -> Void) {
        self.initialBaseURL = initialBaseURL
        self.initialToken = initialToken
        self.onConnect = onConnect
        _baseURL = State(initialValue: initialBaseURL)
        _token = State(initialValue: initialToken)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Advanced Connection")
                .font(.headline)
            Text("Set a custom Base URL and access token. Test first, then connect.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Base URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://localhost:23373", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Access Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Paste access token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .focused($tokenFocused)
                    .onSubmit { Task { await testConnection() } }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await testConnection() }
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting || isConnecting || token.isEmpty || baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Connect") {
                    connect()
                }
                .buttonStyle(.bordered)
                .disabled(isConnecting || !isTestStillValid)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
            }

            if let testedInfo {
                Label("Connection looks good", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("Server: \(testedInfo.server.base_url)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                tokenFocused = true
            }
        }
    }

    private var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isTestStillValid: Bool {
        testedInfo != nil && testedBaseURL == normalizedBaseURL && testedToken == token
    }

    private func testConnection() async {
        error = nil
        testedInfo = nil
        isTesting = true
        defer { isTesting = false }

        do {
            let client = BeeperAPIClient(baseURL: normalizedBaseURL, token: token)
            _ = try await client.getAccounts()
            let info = try await client.getInfo()
            testedInfo = info
            testedBaseURL = normalizedBaseURL
            testedToken = token
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func connect() {
        guard let testedInfo else {
            error = "Test the connection first."
            return
        }
        guard isTestStillValid else {
            error = "Connection details changed. Please test again."
            return
        }

        isConnecting = true
        onConnect(normalizedBaseURL, token, testedInfo)
        dismiss()
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
    }
}
