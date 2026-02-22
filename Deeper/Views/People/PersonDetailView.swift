//
//  PersonDetailView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI
import Charts
import FoundationModels

struct PersonDetailView: View {
    let person: MergedPerson
    var store: DataStore

    @State private var conversationSummary: String?
    @State private var isSummarizing = false
    @State private var summaryError: String?
    private var model: SystemLanguageModel { .default }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(person.platforms.first?.color.gradient ?? Color.gray.gradient)
                            .frame(width: 64, height: 64)
                        Text(String(person.displayName.prefix(1)).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("\(person.platformCount) platform\(person.platformCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if person.totalMessageCount > 0 {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("\(person.totalMessageCount)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("messages")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                Label("\(person.messagesSent)", systemImage: "arrow.up")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Label("\(person.messagesReceived)", systemImage: "arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

                // MARK: - Connection Type
                HStack(spacing: 12) {
                    Image(systemName: person.connectionType.icon)
                        .font(.title2)
                        .foregroundStyle(connectionColor(for: person.connectionType))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.connectionType.label)
                            .font(.headline)
                            .foregroundStyle(connectionColor(for: person.connectionType))
                        Text(connectionDescription(for: person))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if person.totalMessageCount > 0 {
                        Text("\(Int(person.reciprocityScore * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(connectionColor(for: person.connectionType))
                        Text("reciprocity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

                // MARK: - Response Time
                responseTimeSection

                // MARK: - Platform Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Platform Breakdown")
                        .font(.headline)

                    if person.presences.count > 1 {
                        Chart(person.presences) { presence in
                            SectorMark(
                                angle: .value("Messages", max(presence.messageCount, 1)),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(presence.platform.color)
                            .cornerRadius(4)
                        }
                        .frame(height: 180)
                    }

                    ForEach(person.presences) { presence in
                        HStack(spacing: 12) {
                            Image(systemName: presence.platform.iconName)
                                .font(.title3)
                                .foregroundStyle(presence.platform.color)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(presence.platform.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("\(presence.chatIDs.count) chat\(presence.chatIDs.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if presence.messageCount > 0 {
                                HStack(spacing: 8) {
                                    Label("\(presence.messagesSent)", systemImage: "arrow.up")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    Label("\(presence.messagesReceived)", systemImage: "arrow.down")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            if let date = presence.lastActivity {
                                Text(date, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

                // MARK: - Language Session
                languageSessionSection

                // MARK: - Per-Person Phrases
                personPhrasesSection
            }
            .padding(24)
        }
        .onAppear {
            summarizeConversation()
        }
        .onChange(of: person) {
            conversationSummary = nil
            summaryError = nil
            summarizeConversation()
        }
    }

    // MARK: - Response Time Section

    private var responseTimeSection: some View {
        let times = store.responseTimesForPerson(person)
        return Group {
            if times.myAvg != nil || times.theirAvg != nil {
                HStack(spacing: 16) {
                    if let my = times.myAvg {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text(Self.formatResponseTime(my))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Your avg reply")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let their = times.theirAvg {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text(Self.formatResponseTime(their))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("\(person.displayName)'s avg reply")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private static func formatResponseTime(_ seconds: Double) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return String(format: "%.1fh", seconds / 3600) }
        return String(format: "%.1fd", seconds / 86400)
    }

    // MARK: - Language Session Section

    @State private var glowStops: [Gradient.Stop] = Self.randomGlowStops()

    private static func randomGlowStops() -> [Gradient.Stop] {
        [
            Color(red: 188/255, green: 130/255, blue: 243/255),
            Color(red: 245/255, green: 185/255, blue: 234/255),
            Color(red: 141/255, green: 159/255, blue: 255/255),
            Color(red: 255/255, green: 103/255, blue: 120/255),
            Color(red: 255/255, green: 186/255, blue: 113/255),
            Color(red: 198/255, green: 134/255, blue: 255/255),
        ]
        .map { Gradient.Stop(color: $0, location: Double.random(in: 0...1)) }
        .sorted { $0.location < $1.location }
    }

    private var languageSessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Conversation Summary", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if isSummarizing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("Summarized on-device with Apple Intelligence")
                .font(.caption2)
                .foregroundStyle(.secondary)

            switch model.availability {
            case .available:
                if let summary = conversationSummary {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                } else if let error = summaryError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button("Retry") { summarizeConversation() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                } else if isSummarizing {
                    Text("Summarizing your conversation…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No messages to summarize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .unavailable(.deviceNotEligible):
                Label("This device doesn't support Apple Intelligence", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unavailable(.appleIntelligenceNotEnabled):
                Label("Enable Apple Intelligence in System Settings → Apple Intelligence & Siri", systemImage: "gear")
                    .font(.caption)
                    .foregroundStyle(.orange)
            case .unavailable(.modelNotReady):
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Apple Intelligence models are downloading…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .unavailable(_):
                Label("Apple Intelligence is currently unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: glowStops), center: .center),
                    lineWidth: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: glowStops), center: .center),
                    lineWidth: 4
                )
                .blur(radius: 6)
        )
        .animation(.easeInOut(duration: 0.8), value: glowStops)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                glowStops = Self.randomGlowStops()
            }
        }
    }

    // MARK: - Per-Person Phrases

    private var personPhrasesSection: some View {
        let stats = store.phraseStatsForPerson(person)
        return Group {
            if !stats.topWords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Words with \(person.displayName)")
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(stats.totalWords)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("words sent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(stats.uniqueWords)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("unique")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.0f", stats.averageMessageLength))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("avg length")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 4)

                    let maxCount = Double(stats.topWords.first?.count ?? 1)
                    FlowLayout(spacing: 6) {
                        ForEach(Array(stats.topWords.prefix(30))) { word in
                            let ratio = Double(word.count) / maxCount
                            let fontSize = max(10, min(20, 10 + ratio * 10))
                            HStack(spacing: 3) {
                                Text(word.word)
                                    .font(.system(size: fontSize, weight: .medium))
                                Text("\(word.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.blue.opacity(ratio * 0.15 + 0.05), in: Capsule())
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - LLM Summarization

    private func summarizeConversation() {
        guard case .available = model.availability else { return }
        let recentMsgs = store.recentConversation(person, limit: 50)
        guard !recentMsgs.isEmpty else { return }

        isSummarizing = true
        summaryError = nil

        Task {
            do {
                // Detect system language for response
                let systemLang = Locale.current.language
                let langCode = systemLang.languageCode?.identifier ?? "en"
                let langName = Locale.current.localizedString(forIdentifier: langCode) ?? "English"

                let session = LanguageModelSession(
                    instructions: """
                    You MUST respond in \(langName). \
                    Never use markdown formatting. Never use bullet points, numbered lists, or any kind of list. \
                    Write only plain flowing prose, as if you're casually telling a friend about this conversation. \
                    Keep it short and natural.
                    """
                )

                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short

                var conversationText = ""
                for msg in recentMsgs {
                    let sender = msg.isSender ? "Me" : person.displayName
                    let time = formatter.string(from: msg.timestamp)
                    conversationText += "[\(time)] \(sender): \(msg.text)\n"
                }

                let prompt = """
                Here is a recent conversation between me and \(person.displayName). \
                In 2-3 short sentences, describe what we've been talking about and what the vibe is like. \
                Mention any key topics naturally. Do not use any formatting, lists, or headers.

                \(conversationText)
                """

                let response = try await session.respond(to: prompt)
                conversationSummary = response.content
                isSummarizing = false
            } catch {
                summaryError = "Apple Intelligence: \(error.localizedDescription)"
                isSummarizing = false
            }
        }
    }

    func connectionColor(for type: ConnectionType) -> Color {
        switch type {
        case .twoWay: .green
        case .theyGhost: .orange
        case .iGhost: .purple
        case .inactive: .gray
        }
    }

    func connectionDescription(for person: MergedPerson) -> String {
        switch person.connectionType {
        case .twoWay:
            "You both actively message each other"
        case .theyGhost:
            "You sent \(person.messagesSent) but only got \(person.messagesReceived) back"
        case .iGhost:
            "They sent \(person.messagesReceived) but you only sent \(person.messagesSent)"
        case .inactive:
            "No recent message activity"
        }
    }
}
