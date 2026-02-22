//
//  TimeRangeView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 23.02.2026.
//

import SwiftUI
import Charts

struct TimeRangeView: View {
    let title: String
    let store: DataStore
    let stats: TimeRangeStats?
    let isFetching: Bool
    let showDaily: Bool
    let onRefresh: () async -> Void

    var body: some View {
        ScrollView {
            if isFetching && stats == nil {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else if let stats {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Summary Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        StatCard(title: "Sent", value: "\(stats.totalSent)", icon: "paperplane.fill", color: .blue)
                        StatCard(title: "Received", value: "\(stats.totalReceived)", icon: "tray.fill", color: .green)
                        StatCard(title: "Total", value: "\(stats.totalMessages)", icon: "bubble.left.and.bubble.right.fill", color: .purple)
                        StatCard(title: "Active Chats", value: "\(stats.activeChats)", icon: "text.bubble.fill", color: .orange)
                    }

                    // MARK: - Charts Row
                    HStack(alignment: .top, spacing: 16) {
                        // Platform breakdown
                        if !stats.platformBreakdowns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("By Platform", systemImage: "app.connected.to.app.below.fill")
                                    .font(.headline)

                                Chart(stats.platformBreakdowns) { item in
                                    BarMark(
                                        x: .value("Sent", item.sent),
                                        y: .value("Platform", item.platform.displayName)
                                    )
                                    .foregroundStyle(item.platform.color.opacity(0.8))

                                    BarMark(
                                        x: .value("Received", item.received),
                                        y: .value("Platform", item.platform.displayName)
                                    )
                                    .foregroundStyle(item.platform.color.opacity(0.4))
                                }
                                .chartXAxisLabel("Messages")
                                .frame(height: CGFloat(max(stats.platformBreakdowns.count, 1)) * 32 + 20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        }

                        // Hourly activity
                        if !stats.hourlyPoints.isEmpty && stats.hourlyPoints.contains(where: { $0.count > 0 }) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Hourly Activity", systemImage: "clock.fill")
                                    .font(.headline)

                                Chart(stats.hourlyPoints) { point in
                                    AreaMark(
                                        x: .value("Hour", point.hour),
                                        y: .value("Messages", point.count)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.blue.opacity(0.15))

                                    LineMark(
                                        x: .value("Hour", point.hour),
                                        y: .value("Messages", point.count)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                .chartXAxis {
                                    AxisMarks(values: Array(stride(from: 0, through: 23, by: 3))) { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let hour = value.as(Int.self) {
                                                let h = hour % 12 == 0 ? 12 : hour % 12
                                                let suffix = hour < 12 ? "a" : "p"
                                                Text("\(h)\(suffix)")
                                            }
                                        }
                                    }
                                }
                                .frame(height: CGFloat(max(stats.platformBreakdowns.count, 1)) * 32 + 20)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        }
                    }

                    // MARK: - Daily Volume (week only)
                    if showDaily && !stats.dailyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Daily Volume", systemImage: "chart.bar.fill")
                                .font(.headline)

                            Chart(stats.dailyPoints) { point in
                                BarMark(
                                    x: .value("Date", point.date, unit: .day),
                                    y: .value("Messages", point.count)
                                )
                                .foregroundStyle(.purple.gradient)
                                .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { value in
                                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                    AxisGridLine()
                                }
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    }

                    // MARK: - Ghosts
                    HStack(alignment: .top, spacing: 16) {
                        ghostCard(
                            title: "They Ghost Me",
                            icon: "eye.slash.fill",
                            color: .orange,
                            entries: stats.theyGhostMe,
                            sentLabel: true
                        )
                        ghostCard(
                            title: "I Ghost Them",
                            icon: "moon.zzz.fill",
                            color: .purple,
                            entries: stats.iGhostThem,
                            sentLabel: false
                        )
                    }

                    // MARK: - Footer
                    HStack {
                        Spacer()
                        if isFetching {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button {
                            Task { await onRefresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        Text("Updated \(stats.fetchedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(24)
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            }
        }
        .navigationTitle(title)
    }

    @ViewBuilder
    private func ghostCard(
        title: String,
        icon: String,
        color: Color,
        entries: [TimeRangeStats.GhostEntry],
        sentLabel: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            if entries.isEmpty {
                Text("No ghosts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(entries.prefix(8)) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: entry.platform.iconName)
                            .font(.caption)
                            .foregroundStyle(entry.platform.color)
                            .frame(width: 18)
                        Text(entry.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.messageCount) msg\(entry.messageCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                if entries.count > 8 {
                    Text("+\(entries.count - 8) more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}
