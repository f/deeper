//
//  WelcomeView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 23.02.2026.
//

import AppKit
import SwiftUI

struct WelcomeView: View {
    var onConnect: (BeeperAPIClient) -> Void

    @Environment(\.openURL) private var openURL
    @State private var isAuthorizing = false
    @State private var isCheckingAPI = false
    @State private var isAPIAvailable = false
    @State private var isConnecting = false
    @State private var token: String = ""
    @State private var baseURL: String = KeychainHelper.loadBaseURL() ?? "http://localhost:23373"
    @State private var error: String?
    @State private var showAdvanced = false
    @State private var showAdvancedSheet = false
    @State private var arrowPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Connection Diagram
            HStack(spacing: 24) {
                // Beeper icon
                VStack(spacing: 8) {
                    BeeperLogoShape()
                        .fill(Color.blue, style: FillStyle(eoFill: true))
                        .aspectRatio(25.5 / 32.0, contentMode: .fit)
                        .frame(height: 44)
                        .frame(width: 80, height: 80)
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    Text("Beeper")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Desktop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Animated arrows
                VStack(spacing: 4) {
                    arrowLine(leftToRight: true)
                    arrowLine(leftToRight: false)
                }
                .frame(width: 100)

                // Deeper icon
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                    Text("Deeper")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Analytics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 32)

            // MARK: - Title
            Text("Connect to Beeper Desktop")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 6)

            Text("Deeper reads your local Beeper data to show messaging analytics.\nYour data never leaves your device.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .padding(.bottom, 24)

            // MARK: - Status
            if isCheckingAPI {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking Beeper Desktop API…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)
            } else if !isAPIAvailable {
                VStack(spacing: 8) {
                    Label("Enable Beeper Desktop API first", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Open Beeper Desktop → Settings")
                        Text("2. Go to the Developers tab")
                        Text("3. Toggle Beeper Desktop API to On")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Open Beeper") {
                            if let url = URL(string: "beeper://connect") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Refresh") {
                            Task { await refreshAPIAvailability() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 12)
            }

            // MARK: - Connect Button
            Button(action: authorizeWithBeeper) {
                if isAuthorizing || isConnecting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting…")
                    }
                    .frame(width: 200)
                } else {
                    Text("Connect")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthorizing || isConnecting || isCheckingAPI || !isAPIAvailable)
            .padding(.bottom, 12)

            // MARK: - Error
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            // MARK: - Advanced
            Button {
                showAdvancedSheet = true
            } label: {
                Text("Advanced…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await refreshAPIAvailability() }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                arrowPhase = 1
            }
        }
        .sheet(isPresented: $showAdvancedSheet) {
            AdvancedConnectView(initialBaseURL: baseURL, initialToken: token) { testedBaseURL, testedToken, testedInfo in
                connectWithVerifiedCredentials(baseURL: testedBaseURL, token: testedToken, info: testedInfo)
                showAdvancedSheet = false
            }
        }
    }

    // MARK: - Arrow Line

    @ViewBuilder
    private func arrowLine(leftToRight: Bool) -> some View {
        Canvas { context, size in
            let y = size.height / 2
            let startX: CGFloat = 4
            let endX = size.width - 4

            // Dashes
            let dashLen: CGFloat = 6
            let gap: CGFloat = 5
            let total = dashLen + gap
            let offset = arrowPhase * total * (leftToRight ? 1 : -1)

            var path = Path()
            var x = startX + offset.truncatingRemainder(dividingBy: total)
            if x < startX { x += total }
            while x < endX - dashLen {
                let segEnd = min(x + dashLen, endX - 8)
                if segEnd > startX {
                    path.move(to: CGPoint(x: max(x, startX), y: y))
                    path.addLine(to: CGPoint(x: segEnd, y: y))
                }
                x += total
            }

            context.stroke(path, with: .color(leftToRight ? .blue.opacity(0.6) : .purple.opacity(0.6)), lineWidth: 2)

            // Arrow head
            var arrow = Path()
            if leftToRight {
                arrow.move(to: CGPoint(x: endX - 6, y: y - 4))
                arrow.addLine(to: CGPoint(x: endX, y: y))
                arrow.addLine(to: CGPoint(x: endX - 6, y: y + 4))
            } else {
                arrow.move(to: CGPoint(x: startX + 6, y: y - 4))
                arrow.addLine(to: CGPoint(x: startX, y: y))
                arrow.addLine(to: CGPoint(x: startX + 6, y: y + 4))
            }
            context.stroke(arrow, with: .color(leftToRight ? .blue.opacity(0.6) : .purple.opacity(0.6)), lineWidth: 2)
        }
        .frame(height: 14)
    }

    // MARK: - Auth Logic

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

    private func connect() {
        guard !token.isEmpty else { return }
        isConnecting = true
        error = nil

        Task {
            do {
                let client = BeeperAPIClient(baseURL: baseURL, token: token)
                _ = try await client.getAccounts()
                _ = try await client.getInfo()
                KeychainHelper.saveToken(token)
                KeychainHelper.saveBaseURL(baseURL)
                onConnect(client)
            } catch {
                self.error = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func connectWithVerifiedCredentials(baseURL: String, token: String, info: ConnectInfoResponse) {
        self.baseURL = baseURL
        self.token = token
        self.error = nil
        KeychainHelper.saveBaseURL(baseURL)
        KeychainHelper.saveToken(token)
        let client = BeeperAPIClient(baseURL: baseURL, token: token)
        onConnect(client)
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
}

// MARK: - Beeper Logo Shape

struct BeeperLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let sx = w / 25.5
        let sy = h / 32.0

        var path = Path()

        // Outer shape
        path.move(to: CGPoint(x: 0, y: 9 * sy))
        path.addCurve(
            to: CGPoint(x: 9.02 * sx, y: 0),
            control1: CGPoint(x: 0, y: 4.06 * sy),
            control2: CGPoint(x: 3.98 * sx, y: 0)
        )
        path.addLine(to: CGPoint(x: 16.48 * sx, y: 0))
        path.addCurve(
            to: CGPoint(x: 25.5 * sx, y: 9 * sy),
            control1: CGPoint(x: 21.46 * sx, y: 0),
            control2: CGPoint(x: 25.5 * sx, y: 4.02 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 22.69 * sx, y: 15.53 * sy),
            control1: CGPoint(x: 25.49 * sx, y: 11.68 * sy),
            control2: CGPoint(x: 24.32 * sx, y: 13.99 * sy)
        )
        path.addLine(to: CGPoint(x: 20.98 * sx, y: 17.23 * sy))
        path.addCurve(
            to: CGPoint(x: 25.48 * sx, y: 24.05 * sy),
            control1: CGPoint(x: 23.47 * sx, y: 18.69 * sy),
            control2: CGPoint(x: 25.48 * sx, y: 20.96 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 17.10 * sx, y: 32 * sy),
            control1: CGPoint(x: 25.48 * sx, y: 28.68 * sy),
            control2: CGPoint(x: 21.73 * sx, y: 32 * sy)
        )
        path.addLine(to: CGPoint(x: 4.5 * sx, y: 32 * sy))
        path.addLine(to: CGPoint(x: 4.5 * sx, y: 16.80 * sy))
        path.addCurve(
            to: CGPoint(x: 0, y: 9 * sy),
            control1: CGPoint(x: 1.84 * sx, y: 15.24 * sy),
            control2: CGPoint(x: 0, y: 12.33 * sy)
        )
        path.closeSubpath()

        // Inner cutout (even-odd)
        path.move(to: CGPoint(x: 9.02 * sx, y: 2.5 * sy))
        path.addCurve(
            to: CGPoint(x: 2.5 * sx, y: 9 * sy),
            control1: CGPoint(x: 5.375 * sx, y: 2.5 * sy),
            control2: CGPoint(x: 2.5 * sx, y: 5.43 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.02 * sx, y: 15.5 * sy),
            control1: CGPoint(x: 2.5 * sx, y: 12.57 * sy),
            control2: CGPoint(x: 5.375 * sx, y: 15.5 * sy)
        )
        path.addLine(to: CGPoint(x: 12.13 * sx, y: 15.5 * sy))
        path.addLine(to: CGPoint(x: 10.40 * sx, y: 24.23 * sy))
        path.addLine(to: CGPoint(x: 20.94 * sx, y: 13.75 * sy))
        path.addCurve(
            to: CGPoint(x: 23 * sx, y: 9 * sy),
            control1: CGPoint(x: 22.14 * sx, y: 12.63 * sy),
            control2: CGPoint(x: 23 * sx, y: 10.93 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 16.48 * sx, y: 2.5 * sy),
            control1: CGPoint(x: 23 * sx, y: 5.375 * sy),
            control2: CGPoint(x: 20.03 * sx, y: 2.46 * sy)
        )
        path.addLine(to: CGPoint(x: 9.02 * sx, y: 2.5 * sy))
        path.closeSubpath()

        return path
    }
}
