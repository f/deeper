//
//  AnalyticsModels.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 23.02.2026.
//

import Foundation

// MARK: - Date Range

enum AnalyticsDateRange: String, CaseIterable, Identifiable, Codable {
    case week = "7 Days"
    case month = "30 Days"
    case quarter = "90 Days"
    case all = "All Time"

    var id: String { rawValue }

    var cutoffDate: Date? {
        switch self {
        case .week: Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .quarter: Calendar.current.date(byAdding: .day, value: -90, to: Date())
        case .all: nil
        }
    }
}

// MARK: - Raw timestamped data for on-demand filtering

struct TimestampedText: Codable {
    let text: String
    let timestamp: Date
    let chatID: String
    let isSender: Bool
}

struct TimestampedResponse: Identifiable, Codable {
    let personName: String
    let platform: Platform
    let isMine: Bool
    let responseTimeSec: Double
    let timestamp: Date
    var id: String { "\(personName)_\(platform.rawValue)_\(timestamp.timeIntervalSince1970)_\(isMine)" }
}

// MARK: - Phrase Analytics

struct WordFrequency: Identifiable, Codable {
    let word: String
    var count: Int
    var id: String { word }
}

struct PhraseStats: Codable {
    var topWords: [WordFrequency] = []
    var topBigrams: [WordFrequency] = []
    var totalWords: Int = 0
    var uniqueWords: Int = 0
    var averageMessageLength: Double = 0
}

// MARK: - Response Time

struct PersonResponseTime: Identifiable, Codable {
    let personName: String
    let platform: Platform
    var myAvgResponseSec: Double
    var theirAvgResponseSec: Double
    var myResponseCount: Int
    var theirResponseCount: Int

    var id: String { "\(personName)_\(platform.rawValue)" }

    var myAvgFormatted: String {
        Self.format(seconds: myAvgResponseSec)
    }

    var theirAvgFormatted: String {
        Self.format(seconds: theirAvgResponseSec)
    }

    static func format(seconds: Double) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return String(format: "%.1fh", seconds / 3600) }
        return String(format: "%.1fd", seconds / 86400)
    }
}

struct ResponseTimeStats: Codable {
    var perPerson: [PersonResponseTime] = []
    var overallMyAvgSec: Double = 0
    var overallTheirAvgSec: Double = 0
    var totalMyResponses: Int = 0
    var totalTheirResponses: Int = 0

    var myAvgFormatted: String {
        PersonResponseTime.format(seconds: overallMyAvgSec)
    }

    var theirAvgFormatted: String {
        PersonResponseTime.format(seconds: overallTheirAvgSec)
    }
}
