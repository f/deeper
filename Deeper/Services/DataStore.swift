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

    // MARK: - Analytics
    var phraseStats: PhraseStats = PhraseStats()
    var responseTimeStats: ResponseTimeStats = ResponseTimeStats()
    var rawSentTexts: [TimestampedText] = []
    var rawResponses: [TimestampedResponse] = []

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

    var messageLimit: Int {
        let stored = UserDefaults.standard.integer(forKey: "messageLimit")
        if stored == 0 { return Int.max }
        return stored > 0 ? stored : 200
    }

    init(api: BeeperAPIClient) {
        self.api = api
        loadCache()
    }

    // MARK: - Cache (split into multiple files)

    private static var cacheDir: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("deeper_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheDir)
        // Also remove legacy single file
        let legacy = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("deeper_data_cache.json")
        try? FileManager.default.removeItem(at: legacy)
    }

    struct CacheCore: Codable {
        let accounts: [BeeperAccount]
        let totalChats: Int
        let totalUnread: Int
        let messagesSentToday: Int
        let messagesReceivedToday: Int
        let hasInstagram: Bool
        let lastSyncDate: Date?
    }

    struct CachePeople: Codable {
        let mergedPeople: [MergedPerson]
        let twoWayPeople: [MergedPerson]
        let theyGhostPeople: [MergedPerson]
        let iGhostPeople: [MergedPerson]
        let chatBreakdowns: [String: PersonMerger.ChatMessageBreakdown]
    }

    struct CacheChats: Codable {
        let allChats: [BeeperChat]
    }

    struct CachePlatforms: Codable {
        let platformStats: [PlatformStats]
        let hourlyActivity: [HourlyActivityPoint]
    }

    struct CacheGroups: Codable {
        let groupStats: [PlatformGroupStats]
        let mostActiveGroups: [GroupInfo]
    }

    struct CacheReels: Codable {
        let reelEntries: [ReelShareEntry]
        let totalReelsSent: Int
        let totalReelsReceived: Int
    }

    struct CacheAnalytics: Codable {
        let phraseStats: PhraseStats
        let responseTimeStats: ResponseTimeStats
        let rawSentTexts: [TimestampedText]
        let rawResponses: [TimestampedResponse]
    }

    private func saveCacheFile<T: Encodable>(_ value: T, name: String) {
        let url = Self.cacheDir.appendingPathComponent(name)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url)
        }
    }

    private func loadCacheFile<T: Decodable>(_ type: T.Type, name: String) -> T? {
        let url = Self.cacheDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func saveCache() {
        saveCacheFile(CacheCore(
            accounts: accounts, totalChats: totalChats, totalUnread: totalUnread,
            messagesSentToday: messagesSentToday, messagesReceivedToday: messagesReceivedToday,
            hasInstagram: hasInstagram, lastSyncDate: lastSyncDate
        ), name: "core.json")

        saveCacheFile(CachePeople(
            mergedPeople: mergedPeople, twoWayPeople: twoWayPeople,
            theyGhostPeople: theyGhostPeople, iGhostPeople: iGhostPeople,
            chatBreakdowns: chatBreakdowns
        ), name: "people.json")

        saveCacheFile(CacheChats(allChats: allChats), name: "chats.json")

        saveCacheFile(CachePlatforms(
            platformStats: platformStats, hourlyActivity: hourlyActivity
        ), name: "platforms.json")

        saveCacheFile(CacheGroups(
            groupStats: groupStats, mostActiveGroups: mostActiveGroups
        ), name: "groups.json")

        saveCacheFile(CacheReels(
            reelEntries: reelEntries, totalReelsSent: totalReelsSent,
            totalReelsReceived: totalReelsReceived
        ), name: "reels.json")

        saveCacheFile(CacheAnalytics(
            phraseStats: phraseStats, responseTimeStats: responseTimeStats,
            rawSentTexts: rawSentTexts, rawResponses: rawResponses
        ), name: "analytics.json")
    }

    func loadCache() {
        guard let core = loadCacheFile(CacheCore.self, name: "core.json") else { return }
        accounts = core.accounts
        totalChats = core.totalChats
        totalUnread = core.totalUnread
        messagesSentToday = core.messagesSentToday
        messagesReceivedToday = core.messagesReceivedToday
        hasInstagram = core.hasInstagram
        lastSyncDate = core.lastSyncDate

        if let people = loadCacheFile(CachePeople.self, name: "people.json") {
            mergedPeople = people.mergedPeople
            twoWayPeople = people.twoWayPeople
            theyGhostPeople = people.theyGhostPeople
            iGhostPeople = people.iGhostPeople
            chatBreakdowns = people.chatBreakdowns
        }
        if let chats = loadCacheFile(CacheChats.self, name: "chats.json") {
            allChats = chats.allChats
        }
        if let plat = loadCacheFile(CachePlatforms.self, name: "platforms.json") {
            platformStats = plat.platformStats
            hourlyActivity = plat.hourlyActivity
        }
        if let grp = loadCacheFile(CacheGroups.self, name: "groups.json") {
            groupStats = grp.groupStats
            mostActiveGroups = grp.mostActiveGroups
        }
        if let reels = loadCacheFile(CacheReels.self, name: "reels.json") {
            reelEntries = reels.reelEntries
            totalReelsSent = reels.totalReelsSent
            totalReelsReceived = reels.totalReelsReceived
        }
        if let analytics = loadCacheFile(CacheAnalytics.self, name: "analytics.json") {
            phraseStats = analytics.phraseStats
            responseTimeStats = analytics.responseTimeStats
            rawSentTexts = analytics.rawSentTexts
            rawResponses = analytics.rawResponses
        }
    }

    // MARK: - Date-filtered analytics

    private static let phraseStopWords: Set<String> = ["the", "a", "an", "is", "it", "to", "in", "for", "of", "and", "or", "on", "at", "i", "me", "my", "you", "your", "we", "he", "she", "they", "that", "this", "but", "not", "so", "do", "be", "have", "has", "had", "was", "were", "been", "am", "are", "will", "can", "just", "no", "yes", "ok", "ya", "oh", "if", "with", "from", "as", "by", "de", "bir", "bu", "da", "ve", "ben", "sen", "o", "ne", "var", "bir", "mi", "mu", "mı", "http", "https", "www", "com", "org", "net", "io", "co", "html", "php", "instagram", "facebook", "twitter", "youtube", "tiktok", "reddit", "linkedin", "whatsapp", "telegram", "signal", "stories", "reel", "reels", "story", "their", "mentioned"]

    func phraseStats(for range: AnalyticsDateRange) -> PhraseStats {
        if range == .all { return phraseStats }
        guard let cutoff = range.cutoffDate else { return phraseStats }
        let filtered = rawSentTexts.filter { $0.timestamp >= cutoff }
        return Self.computePhraseStats(from: filtered.map(\.text))
    }

    static func computePhraseStats(from texts: [String]) -> PhraseStats {
        let urlPattern = try? NSRegularExpression(pattern: "https?://\\S+|www\\.\\S+", options: .caseInsensitive)
        var wordCounts: [String: Int] = [:]
        var bigramCounts: [String: Int] = [:]
        var totalWords = 0
        var totalLen = 0
        for text in texts {
            let cleaned = urlPattern?.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "") ?? text
            let words = cleaned.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 1 && !phraseStopWords.contains($0) }
            totalWords += words.count
            totalLen += text.count
            for word in words { wordCounts[word, default: 0] += 1 }
            for i in 0..<max(0, words.count - 1) {
                bigramCounts["\(words[i]) \(words[i + 1])", default: 0] += 1
            }
        }
        return PhraseStats(
            topWords: wordCounts.sorted { $0.value > $1.value }.prefix(50).map { WordFrequency(word: $0.key, count: $0.value) },
            topBigrams: bigramCounts.sorted { $0.value > $1.value }.prefix(30).map { WordFrequency(word: $0.key, count: $0.value) },
            totalWords: totalWords,
            uniqueWords: wordCounts.count,
            averageMessageLength: texts.isEmpty ? 0 : Double(totalLen) / Double(texts.count)
        )
    }

    func responseTimeStats(for range: AnalyticsDateRange) -> ResponseTimeStats {
        if range == .all { return responseTimeStats }
        guard let cutoff = range.cutoffDate else { return responseTimeStats }
        let filtered = rawResponses.filter { $0.timestamp >= cutoff }
        return Self.computeResponseTimeStats(from: filtered)
    }

    static func computeResponseTimeStats(from responses: [TimestampedResponse]) -> ResponseTimeStats {
        var personMap: [String: (myTotal: Double, myCount: Int, theirTotal: Double, theirCount: Int, platform: Platform)] = [:]
        for r in responses {
            let key = "\(r.personName)_\(r.platform.rawValue)"
            var entry = personMap[key] ?? (0, 0, 0, 0, r.platform)
            if r.isMine {
                entry.myTotal += r.responseTimeSec
                entry.myCount += 1
            } else {
                entry.theirTotal += r.responseTimeSec
                entry.theirCount += 1
            }
            personMap[key] = entry
        }
        var perPerson: [PersonResponseTime] = []
        var overallMySec: Double = 0, overallMyCount = 0
        var overallTheirSec: Double = 0, overallTheirCount = 0
        for (key, val) in personMap {
            let name = String(key.prefix(while: { $0 != "_" }))
            // Extract person name properly — everything before last _platform
            let parts = key.components(separatedBy: "_")
            let pName = parts.dropLast().joined(separator: "_")
            perPerson.append(PersonResponseTime(
                personName: pName,
                platform: val.platform,
                myAvgResponseSec: val.myCount > 0 ? val.myTotal / Double(val.myCount) : 0,
                theirAvgResponseSec: val.theirCount > 0 ? val.theirTotal / Double(val.theirCount) : 0,
                myResponseCount: val.myCount,
                theirResponseCount: val.theirCount
            ))
            overallMySec += val.myTotal
            overallMyCount += val.myCount
            overallTheirSec += val.theirTotal
            overallTheirCount += val.theirCount
        }
        perPerson.sort { $0.myAvgResponseSec < $1.myAvgResponseSec }
        return ResponseTimeStats(
            perPerson: perPerson,
            overallMyAvgSec: overallMyCount > 0 ? overallMySec / Double(overallMyCount) : 0,
            overallTheirAvgSec: overallTheirCount > 0 ? overallTheirSec / Double(overallTheirCount) : 0,
            totalMyResponses: overallMyCount,
            totalTheirResponses: overallTheirCount
        )
    }

    // MARK: - Per-person analytics

    func messagesForPerson(_ person: MergedPerson) -> [TimestampedText] {
        let chatIDs = Set(person.presences.flatMap(\.chatIDs))
        return rawSentTexts.filter { chatIDs.contains($0.chatID) }
    }

    func phraseStatsForPerson(_ person: MergedPerson) -> PhraseStats {
        let msgs = messagesForPerson(person).filter(\.isSender)
        return Self.computePhraseStats(from: msgs.map(\.text))
    }

    func responseTimesForPerson(_ person: MergedPerson) -> (myAvg: Double?, theirAvg: Double?) {
        let name = person.displayName
        let personResponses = rawResponses.filter { $0.personName == name }
        let mine = personResponses.filter { $0.isMine }
        let theirs = personResponses.filter { !$0.isMine }
        let myAvg = mine.isEmpty ? nil : mine.map(\.responseTimeSec).reduce(0, +) / Double(mine.count)
        let theirAvg = theirs.isEmpty ? nil : theirs.map(\.responseTimeSec).reduce(0, +) / Double(theirs.count)
        return (myAvg, theirAvg)
    }

    func recentConversation(_ person: MergedPerson, limit: Int = 50) -> [TimestampedText] {
        let msgs = messagesForPerson(person)
        return msgs.sorted { $0.timestamp < $1.timestamp }.suffix(limit).map { $0 }
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
                    var sent = 0
                    var received = 0
                    var cursor: String? = nil
                    var total = 0
                    let limit = messageLimit
                    while total < limit {
                        let response = try await api.listMessages(chatID: chat.id, cursor: cursor, direction: cursor != nil ? "before" : nil)
                        for msg in response.items {
                            if msg.isSender == true {
                                sent += 1
                            } else {
                                received += 1
                            }
                            total += 1
                            if total >= limit { break }
                        }
                        guard total < limit, response.hasMore, let lastMsg = response.items.last else { break }
                        cursor = lastMsg.sortKey
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

            // 5. Analyze DMs: sent/received + hourly + phrases + response times
            let dmChats = fetchedChats.filter { $0.type == .single }
            var breakdowns: [String: PersonMerger.ChatMessageBreakdown] = [:]
            let calendar = Calendar.current
            var hourlyMap: [Platform: [Int: Int]] = [:]
            var allSentTexts: [String] = []
            var timestampedTexts: [TimestampedText] = []
            var totalMessageLengths: Int = 0
            var sentMessageCount: Int = 0
            var timestampedResponses: [TimestampedResponse] = []
            var chatResponseTimes: [(chatID: String, platform: Platform, personName: String, myTotals: Double, myCount: Int, theirTotals: Double, theirCount: Int)] = []

            for (index, chat) in dmChats.enumerated() {
                loadingProgress = "Analyzing conversations (\(index + 1)/\(dmChats.count))..."
                let platform = Platform.from(accountID: chat.accountID)
                do {
                    var bd = PersonMerger.ChatMessageBreakdown()
                    var cursor: String? = nil
                    var total = 0
                    let limit = messageLimit
                    var chatMessages: [BeeperMessage] = []
                    while total < limit {
                        let response = try await api.listMessages(chatID: chat.id, cursor: cursor, direction: cursor != nil ? "before" : nil)
                        for msg in response.items {
                            if msg.isSender == true {
                                bd.sent += 1
                                if let text = msg.text, !text.isEmpty {
                                    allSentTexts.append(text)
                                    timestampedTexts.append(TimestampedText(text: text, timestamp: msg.timestamp, chatID: chat.id, isSender: true))
                                    totalMessageLengths += text.count
                                    sentMessageCount += 1
                                }
                            } else {
                                bd.received += 1
                                if let text = msg.text, !text.isEmpty {
                                    timestampedTexts.append(TimestampedText(text: text, timestamp: msg.timestamp, chatID: chat.id, isSender: false))
                                }
                            }
                            let hour = calendar.component(.hour, from: msg.timestamp)
                            hourlyMap[platform, default: [:]][hour, default: 0] += 1
                            chatMessages.append(msg)
                            total += 1
                            if total >= limit { break }
                        }
                        guard total < limit, response.hasMore, let lastMsg = response.items.last else { break }
                        cursor = lastMsg.sortKey
                    }
                    breakdowns[chat.id] = bd

                    // Response time calculation
                    let sorted = chatMessages.sorted { $0.timestamp < $1.timestamp }
                    var myTotal: Double = 0
                    var myCount = 0
                    var theirTotal: Double = 0
                    var theirCount = 0
                    for i in 1..<max(1, sorted.count) where sorted.count > 1 {
                        let prev = sorted[i - 1]
                        let curr = sorted[i]
                        let gap = curr.timestamp.timeIntervalSince(prev.timestamp)
                        guard gap > 0, gap < 86400 * 7 else { continue } // ignore >7d gaps
                        let personName = chat.participants.items.first(where: { $0.isSelf != true })?.displayName ?? chat.title
                        if prev.isSender != true && curr.isSender == true {
                            // They sent, I replied
                            myTotal += gap
                            myCount += 1
                            timestampedResponses.append(TimestampedResponse(personName: personName, platform: platform, isMine: true, responseTimeSec: gap, timestamp: curr.timestamp))
                        } else if prev.isSender == true && curr.isSender != true {
                            // I sent, they replied
                            theirTotal += gap
                            theirCount += 1
                            timestampedResponses.append(TimestampedResponse(personName: personName, platform: platform, isMine: false, responseTimeSec: gap, timestamp: curr.timestamp))
                        }
                    }
                    let personName = chat.participants.items.first(where: { $0.isSelf != true })?.displayName ?? chat.title
                    chatResponseTimes.append((chatID: chat.id, platform: platform, personName: personName, myTotals: myTotal, myCount: myCount, theirTotals: theirTotal, theirCount: theirCount))
                } catch {
                    breakdowns[chat.id] = PersonMerger.ChatMessageBreakdown()
                }
            }

            chatBreakdowns = breakdowns

            // Phrase analysis
            loadingProgress = "Analyzing phrases..."
            let stopWords: Set<String> = ["the", "a", "an", "is", "it", "to", "in", "for", "of", "and", "or", "on", "at", "i", "me", "my", "you", "your", "we", "he", "she", "they", "that", "this", "but", "not", "so", "do", "be", "have", "has", "had", "was", "were", "been", "am", "are", "will", "can", "just", "no", "yes", "ok", "ya", "oh", "if", "with", "from", "as", "by", "de", "bir", "bu", "da", "ve", "ben", "sen", "o", "ne", "var", "bir", "mi", "mu", "mı", "http", "https", "www", "com", "org", "net", "io", "co", "html", "php", "instagram", "facebook", "twitter", "youtube", "tiktok", "reddit", "linkedin", "whatsapp", "telegram", "signal", "stories", "reel", "reels", "story", "their", "mentioned"]
            var wordCounts: [String: Int] = [:]
            var bigramCounts: [String: Int] = [:]
            var totalWords = 0
            let urlPattern = try? NSRegularExpression(pattern: "https?://\\S+|www\\.\\S+", options: .caseInsensitive)
            for text in allSentTexts {
                let cleaned = urlPattern?.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "") ?? text
                let words = cleaned.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count > 1 && !stopWords.contains($0) }
                totalWords += words.count
                for word in words {
                    wordCounts[word, default: 0] += 1
                }
                for i in 0..<max(0, words.count - 1) {
                    let bigram = "\(words[i]) \(words[i + 1])"
                    bigramCounts[bigram, default: 0] += 1
                }
            }
            let topWords = wordCounts.sorted { $0.value > $1.value }.prefix(50)
                .map { WordFrequency(word: $0.key, count: $0.value) }
            let topBigrams = bigramCounts.sorted { $0.value > $1.value }.prefix(30)
                .map { WordFrequency(word: $0.key, count: $0.value) }
            phraseStats = PhraseStats(
                topWords: topWords,
                topBigrams: topBigrams,
                totalWords: totalWords,
                uniqueWords: wordCounts.count,
                averageMessageLength: sentMessageCount > 0 ? Double(totalMessageLengths) / Double(sentMessageCount) : 0
            )

            // Response time aggregation
            loadingProgress = "Computing response times..."
            var perPerson: [PersonResponseTime] = []
            var overallMySec: Double = 0
            var overallMyCount = 0
            var overallTheirSec: Double = 0
            var overallTheirCount = 0
            for rt in chatResponseTimes {
                if rt.myCount > 0 || rt.theirCount > 0 {
                    perPerson.append(PersonResponseTime(
                        personName: rt.personName,
                        platform: rt.platform,
                        myAvgResponseSec: rt.myCount > 0 ? rt.myTotals / Double(rt.myCount) : 0,
                        theirAvgResponseSec: rt.theirCount > 0 ? rt.theirTotals / Double(rt.theirCount) : 0,
                        myResponseCount: rt.myCount,
                        theirResponseCount: rt.theirCount
                    ))
                    overallMySec += rt.myTotals
                    overallMyCount += rt.myCount
                    overallTheirSec += rt.theirTotals
                    overallTheirCount += rt.theirCount
                }
            }
            perPerson.sort { $0.myAvgResponseSec < $1.myAvgResponseSec }
            responseTimeStats = ResponseTimeStats(
                perPerson: perPerson,
                overallMyAvgSec: overallMyCount > 0 ? overallMySec / Double(overallMyCount) : 0,
                overallTheirAvgSec: overallTheirCount > 0 ? overallTheirSec / Double(overallTheirCount) : 0,
                totalMyResponses: overallMyCount,
                totalTheirResponses: overallTheirCount
            )

            // Store raw data for date-range filtering
            rawSentTexts = timestampedTexts
            rawResponses = timestampedResponses

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
        saveCache()

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
