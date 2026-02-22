//
//  DataStore.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import Foundation

@Observable
final class DataStore {
    // MARK: - Raw data
    var accounts: [BeeperAccount] = []
    var allChats: [BeeperChat] = []
    var chatBreakdowns: [String: PersonMerger.ChatMessageBreakdown] = [:]

    // MARK: - Computed / derived
    var mergedPeople: [MergedPerson] = []
    var twoWayPeople: [MergedPerson] = []
    var theyGhostPeople: [MergedPerson] = []
    var iGhostPeople: [MergedPerson] = []
    var platformStats: [PlatformStats] = []
    var hourlyActivity: [HourlyActivityPoint] = []

    // MARK: - Groups
    var groupStats: [PlatformGroupStats] = []
    var mostActiveGroups: [GroupInfo] = []

    // MARK: - Reels
    var reelEntries: [ReelShareEntry] = []
    var totalReelsSent: Int = 0
    var totalReelsReceived: Int = 0
    var hasInstagram = false

    // MARK: - Summary
    var totalChats: Int = 0
    var totalUnread: Int = 0
    var messagesSentToday: Int = 0
    var messagesReceivedToday: Int = 0

    // MARK: - Time Range Stats
    var todayStats: TimeRangeStats?
    var lastWeekStats: TimeRangeStats?
    var isFetchingToday = false
    var isFetchingLastWeek = false

    // MARK: - State
    var isLoading = false
    var loadingProgress: String?
    var error: String?
    var lastSyncDate: Date?
    var isCached: Bool { lastSyncDate != nil }

    let api: BeeperAPIClient?

    init(api: BeeperAPIClient) {
        self.api = api
    }

    // MARK: - Full sync

    func loadIfNeeded() async {
        guard !isCached && !isLoading else { return }
        await sync()
    }

    func sync() async {
        guard let api else { return }
        isLoading = true
        error = nil
        loadingProgress = "Fetching accounts..."

        do {
            // 1. Accounts
            let fetchedAccounts = try await api.getAccounts()
            accounts = fetchedAccounts

            // 2. All chats
            loadingProgress = "Fetching all chats..."
            let fetchedChats = try await api.fetchAllChats { count in
                self.loadingProgress = "Fetching chats (\(count))..."
            }
            allChats = fetchedChats
            totalChats = fetchedChats.count
            totalUnread = fetchedChats.reduce(0) { $0 + $1.unreadCount }

            // 3. Platform stats
            loadingProgress = "Computing platform stats..."
            platformStats = PersonMerger.computePlatformStats(chats: fetchedChats)

            // 4. Group stats + message analysis
            loadingProgress = "Analyzing groups..."
            let groupChats = fetchedChats.filter { $0.type == .group }
            var groupInfos: [GroupInfo] = []

            for (index, chat) in groupChats.enumerated() {
                loadingProgress = "Analyzing groups (\(index + 1)/\(groupChats.count))..."
                var info = GroupInfo(
                    id: chat.id,
                    title: chat.title,
                    platform: chat.platform,
                    memberCount: chat.participants.total,
                    unreadCount: chat.unreadCount,
                    lastActivity: chat.lastActivity,
                    isMuted: chat.isMuted ?? false,
                    isPinned: chat.isPinned ?? false
                )
                do {
                    let response = try await api.listMessages(chatID: chat.id)
                    var sent = 0
                    var received = 0
                    for msg in response.items {
                        if msg.isSender == true {
                            sent += 1
                        } else {
                            received += 1
                        }
                    }
                    info.messagesSent = sent
                    info.messagesReceived = received
                    info.messageCount = sent + received
                } catch {
                    // keep zeros
                }
                groupInfos.append(info)
            }

            var groupMap: [Platform: [GroupInfo]] = [:]
            for info in groupInfos {
                groupMap[info.platform, default: []].append(info)
            }
            groupStats = groupMap.map { platform, groups in
                PlatformGroupStats(
                    platform: platform,
                    groups: groups.sorted { $0.messageCount > $1.messageCount }
                )
            }.sorted { $0.totalGroups > $1.totalGroups }
            mostActiveGroups = groupInfos
                .sorted { $0.messageCount > $1.messageCount }

            // 5. Merge people
            loadingProgress = "Merging people..."
            var merged = PersonMerger.merge(chats: fetchedChats)

            // 5. Analyze DMs: sent/received + hourly
            let dmChats = fetchedChats.filter { $0.type == .single }
            var breakdowns: [String: PersonMerger.ChatMessageBreakdown] = [:]
            let calendar = Calendar.current
            var hourlyMap: [Platform: [Int: Int]] = [:]

            for (index, chat) in dmChats.enumerated() {
                loadingProgress = "Analyzing conversations (\(index + 1)/\(dmChats.count))..."
                let platform = Platform.from(accountID: chat.accountID)
                do {
                    let response = try await api.listMessages(chatID: chat.id)
                    var bd = PersonMerger.ChatMessageBreakdown()
                    for msg in response.items {
                        if msg.isSender == true {
                            bd.sent += 1
                        } else {
                            bd.received += 1
                        }
                        let hour = calendar.component(.hour, from: msg.timestamp)
                        hourlyMap[platform, default: [:]][hour, default: 0] += 1
                    }
                    breakdowns[chat.id] = bd
                } catch {
                    breakdowns[chat.id] = PersonMerger.ChatMessageBreakdown()
                }
            }

            chatBreakdowns = breakdowns

            // 6. Hourly activity
            var points: [HourlyActivityPoint] = []
            for (platform, hours) in hourlyMap {
                for hour in 0..<24 {
                    points.append(HourlyActivityPoint(
                        hour: hour,
                        platform: platform,
                        count: hours[hour] ?? 0
                    ))
                }
            }
            hourlyActivity = points

            // 7. People categories
            PersonMerger.updateMessageCounts(persons: &merged, chatBreakdowns: breakdowns)
            mergedPeople = merged

            let categorized = PersonMerger.categorize(merged)
            twoWayPeople = categorized.twoWay
            theyGhostPeople = categorized.theyGhost
            iGhostPeople = categorized.iGhost

            // 8. Platform top contacts
            for i in platformStats.indices {
                let platform = platformStats[i].platform
                let contactsOnPlatform = merged.filter { person in
                    person.presences.contains { $0.platform == platform }
                }
                platformStats[i].topContacts = Array(contactsOnPlatform.prefix(10))
            }

            // 9. Today's messages
            loadingProgress = "Counting today's messages..."
            let startOfDay = calendar.startOfDay(for: Date())

            async let sentTask = api.searchMessages(
                sender: "me",
                dateAfter: startOfDay,
                limit: 1
            )
            async let receivedTask = api.searchMessages(
                sender: "others",
                dateAfter: startOfDay,
                limit: 1
            )

            let (sentResponse, receivedResponse) = try await (sentTask, receivedTask)
            messagesSentToday = sentResponse.items.count > 0 ? max(sentResponse.items.count, 1) : 0
            messagesReceivedToday = receivedResponse.items.count > 0 ? max(receivedResponse.items.count, 1) : 0

            // 10. Reels
            loadingProgress = "Analyzing Reels..."
            let instagramAccounts = fetchedAccounts.filter { $0.platform == .instagram }
            if !instagramAccounts.isEmpty {
                hasInstagram = true
                let instagramIDs = instagramAccounts.map(\.accountID)

                let igChats = fetchedChats.filter { instagramIDs.contains($0.accountID) }
                let chatMap = Dictionary(uniqueKeysWithValues: igChats.map { ($0.id, $0) })

                var allMessages: [BeeperMessage] = []
                var cursor: String? = nil

                while true {
                    loadingProgress = "Searching for Reels (\(allMessages.count) found)..."
                    let response = try await api.searchMessages(
                        accountIDs: instagramIDs,
                        mediaTypes: ["video", "image"],
                        limit: 20,
                        cursor: cursor,
                        direction: cursor != nil ? "before" : nil,
                        includeMuted: true
                    )
                    allMessages.append(contentsOf: response.items)
                    guard response.hasMore, let next = response.oldestCursor else { break }
                    cursor = next
                }

                reelEntries = ReelsAnalyzer.analyzeReels(messages: allMessages, chats: chatMap)
                totalReelsSent = reelEntries.reduce(0) { $0 + $1.reelsSent }
                totalReelsReceived = reelEntries.reduce(0) { $0 + $1.reelsReceived }
            } else {
                hasInstagram = false
            }

            lastSyncDate = Date()

        } catch {
            self.error = error.localizedDescription
        }

        loadingProgress = nil
        isLoading = false

        // Fetch time range stats after main sync completes
        await fetchTodayStats()
        await fetchLastWeekStats()
    }

    // MARK: - Time Range Fetching

    func fetchTodayStats() async {
        guard !isFetchingToday else { return }
        isFetchingToday = true
        defer { isFetchingToday = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        do {
            todayStats = try await fetchTimeRangeStats(after: start, before: Date())
        } catch {
        }
    }

    func fetchLastWeekStats() async {
        guard !isFetchingLastWeek else { return }
        isFetchingLastWeek = true
        defer { isFetchingLastWeek = false }

        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        do {
            lastWeekStats = try await fetchTimeRangeStats(after: weekAgo, before: now)
        } catch {
        }
    }

    private func fetchTimeRangeStats(after: Date, before: Date) async throws -> TimeRangeStats {
        guard let api else { throw BeeperAPIError.invalidResponse }
        let calendar = Calendar.current
        // Fetch messages after start date (paginated), filter by before date locally
        var allMessages: [BeeperMessage] = []
        var cursor: String?
        while true {
            let resp = try await api.searchMessages(
                dateAfter: after,
                limit: 20, cursor: cursor,
                direction: cursor != nil ? "before" : nil
            )
            let filtered = resp.items.filter { $0.timestamp <= before }
            allMessages.append(contentsOf: filtered)
            guard resp.hasMore, let next = resp.oldestCursor else { break }
            cursor = next
        }
        // Categorize sent vs received + per-chat ghost tracking
        var totalSent = 0
        var totalReceived = 0
        var platformSent: [Platform: Int] = [:]
        var platformReceived: [Platform: Int] = [:]
        var hourly: [Int: Int] = [:]
        var daily: [Date: Int] = [:]

        // Per-chat tracking for ghost detection
        struct ChatActivity {
            var chatID: String
            var senderName: String?
            var platform: Platform
            var sent: Int = 0
            var received: Int = 0
        }
        var chatMap: [String: ChatActivity] = [:]

        for msg in allMessages {
            let p = Platform.from(accountID: msg.accountID)
            if msg.isSender == true {
                totalSent += 1
                platformSent[p, default: 0] += 1
            } else {
                totalReceived += 1
                platformReceived[p, default: 0] += 1
            }
            let h = calendar.component(.hour, from: msg.timestamp)
            hourly[h, default: 0] += 1
            let day = calendar.startOfDay(for: msg.timestamp)
            daily[day, default: 0] += 1

            var activity = chatMap[msg.chatID] ?? ChatActivity(chatID: msg.chatID, platform: p)
            if msg.isSender == true {
                activity.sent += 1
            } else {
                activity.received += 1
                if activity.senderName == nil { activity.senderName = msg.senderName }
            }
            chatMap[msg.chatID] = activity
        }

        // Ghost detection: chats with one-way messages
        let theyGhostMe = chatMap.values
            .filter { $0.sent > 0 && $0.received == 0 }
            .sorted { $0.sent > $1.sent }
            .map { TimeRangeStats.GhostEntry(name: $0.senderName ?? $0.chatID, platform: $0.platform, messageCount: $0.sent) }

        let iGhostThem = chatMap.values
            .filter { $0.received > 0 && $0.sent == 0 }
            .sorted { $0.received > $1.received }
            .map { TimeRangeStats.GhostEntry(name: $0.senderName ?? $0.chatID, platform: $0.platform, messageCount: $0.received) }

        // Platform breakdowns
        let allPlatforms = Set(platformSent.keys).union(platformReceived.keys)
        let platformBreakdowns = allPlatforms.map { p in
            TimeRangeStats.PlatformBreakdown(
                platform: p,
                sent: platformSent[p] ?? 0,
                received: platformReceived[p] ?? 0
            )
        }.sorted { $0.total > $1.total }

        let hourlyPoints = (0..<24).map { TimeRangeStats.HourlyPoint(hour: $0, count: hourly[$0] ?? 0) }
        let dailyPoints = daily.map { TimeRangeStats.DailyPoint(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
        let uniqueChats = Set(allMessages.map(\.chatID))

        return TimeRangeStats(
            totalSent: totalSent,
            totalReceived: totalReceived,
            platformBreakdowns: platformBreakdowns,
            hourlyPoints: hourlyPoints,
            dailyPoints: dailyPoints,
            activeChats: uniqueChats.count,
            theyGhostMe: theyGhostMe,
            iGhostThem: iGhostThem,
            fetchedAt: Date()
        )
    }
}

// MARK: - TimeRangeStats

struct TimeRangeStats {
    let totalSent: Int
    let totalReceived: Int
    var totalMessages: Int { totalSent + totalReceived }
    let platformBreakdowns: [PlatformBreakdown]
    let hourlyPoints: [HourlyPoint]
    let dailyPoints: [DailyPoint]
    let activeChats: Int
    let theyGhostMe: [GhostEntry]
    let iGhostThem: [GhostEntry]
    let fetchedAt: Date

    struct PlatformBreakdown: Identifiable {
        let platform: Platform
        let sent: Int
        let received: Int
        var total: Int { sent + received }
        var id: Platform { platform }
    }

    struct HourlyPoint: Identifiable {
        let hour: Int
        let count: Int
        var id: Int { hour }
    }

    struct DailyPoint: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    struct GhostEntry: Identifiable {
        let name: String
        let platform: Platform
        let messageCount: Int
        var id: String { "\(name)-\(platform.rawValue)" }
    }
}
