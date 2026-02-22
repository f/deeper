//
//  SettingsView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI

extension Notification.Name {
    static let deeperDidLogout = Notification.Name("deeper.did.logout")
}

struct SettingsView: View {
    var onConnect: (BeeperAPIClient) -> Void
    @Environment(\.openURL) private var openURL

    @State private var token: String = ""
    @State private var isConnecting = false
    @State private var isAuthorizing = false
    @State private var isCheckingAPI = false
    @State private var isAPIAvailable = false
    @State private var connectionInfo: ConnectInfoResponse?
    @State private var error: String?
    @State private var hasExistingToken = false
    @State private var showAdvanced = false
    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis.ascending")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Deeper")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Messaging stats powered by Beeper Desktop API")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // MARK: - Auth Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect Beeper Desktop")
                        .font(.headline)
                    Text("Deeper will connect to Beeper Desktop securely. Your data never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isCheckingAPI {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking Beeper Desktop API availability…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !isAPIAvailable {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Turn on Beeper Desktop API first", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("1. Open Beeper Desktop")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("2. Go to Settings → Developers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("3. Turn on Beeper Desktop API")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button("Open Beeper Setup") {
                                    if let url = URL(string: "beeper://connect") {
                                        openURL(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Check Again") {
                                    Task { await refreshAPIAvailability() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: authorizeWithBeeper) {
                        if isAuthorizing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Connect Beeper Desktop API", systemImage: "link")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAuthorizing || isConnecting || isCheckingAPI || !isAPIAvailable)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAdvanced = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isTokenFieldFocused = true
                        }
                    } label: {
                        HStack {
                            Text("Advanced: Connect with token")
                                .font(.caption)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showAdvanced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use this only if one-tap connection does not work.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SecureField("Paste access token", text: $token)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isTokenFieldFocused)
                                    .onSubmit { connect() }

                                Button(action: connect) {
                                    if isConnecting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Connect")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(token.isEmpty || isConnecting || isAuthorizing || isCheckingAPI || !isAPIAvailable)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Link("Need help? Open setup guide", destination: URL(string: "https://developers.beeper.com/desktop-api")!)
                        .font(.caption)

                    if let error {
                        Label("Couldn’t connect: \(error)", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .frame(maxWidth: 500)

                // MARK: - Connection Info
                if let info = connectionInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)

                        Divider()

                        InfoRow(label: "App", value: "\(info.app.name) v\(info.app.version)")
                        InfoRow(label: "Platform", value: "\(info.platform.os) (\(info.platform.arch))")
                        InfoRow(label: "Server", value: info.server.base_url)
                        InfoRow(label: "Status", value: info.server.status)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .frame(maxWidth: 500)
                }

                // MARK: - Disconnect
                if hasExistingToken {
                    Button(role: .destructive) {
                        disconnect()
                    } label: {
                        Label("Disconnect & Clear Token", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Settings")
        .onAppear {
            Task {
                await refreshAPIAvailability()
                if let saved = KeychainHelper.loadToken() {
                    token = saved
                    hasExistingToken = true
                    testConnection(token: saved)
                }
            }
        }
    }

    private func connect() {
        guard !token.isEmpty else { return }
        isConnecting = true
        error = nil

        Task {
            do {
                let client = BeeperAPIClient(token: token)
                let info = try await validateConnection(token: token)
                connectionInfo = info
                KeychainHelper.saveToken(token)
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
                let client = BeeperAPIClient(token: token)
                let info = try await validateConnection(token: token)
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
                let oauth = BeeperOAuthService()
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
            let oauth = BeeperOAuthService()
            _ = try await oauth.fetchInfo()
            isAPIAvailable = true
        } catch {
            isAPIAvailable = false
        }
    }

    private func validateConnection(token: String) async throws -> ConnectInfoResponse {
        let client = BeeperAPIClient(token: token)
        _ = try await client.getAccounts()
        return try await client.getInfo()
    }

    private func disconnect() {
        KeychainHelper.deleteToken()
        token = ""
        connectionInfo = nil
        hasExistingToken = false
        NotificationCenter.default.post(name: .deeperDidLogout, object: nil)
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
