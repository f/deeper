//
//  DashboardView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI
import Charts

struct DashboardView: View {
    var store: DataStore
    @State private var activePlatforms: Set<Platform> = []
    @State private var platformsInitialized = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Stat Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    StatCard(
                        title: "Accounts",
                        value: "\(store.accounts.count)",
                        icon: "person.crop.circle.fill",
                        color: .blue
                    )
                    StatCard(
                        title: "Total Chats",
                        value: "\(store.totalChats)",
                        icon: "bubble.left.and.bubble.right.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Unread",
                        value: "\(store.totalUnread)",
                        icon: "envelope.badge.fill",
                        color: .orange
                    )
                    StatCard(
                        title: "Sent Today",
                        value: "\(store.messagesSentToday)",
                        icon: "paperplane.fill",
                        color: .purple
                    )
                }

                // MARK: - People Categories
                HStack(alignment: .top, spacing: 16) {
                    DashboardPeopleCard(
                        title: "Two-Way Connected",
                        icon: "arrow.left.arrow.right",
                        color: .green,
                        people: Array(store.twoWayPeople.prefix(5)),
                        isLoading: store.isLoading,
                        showSentReceived: true
                    )
                    DashboardPeopleCard(
                        title: "They Ghost Me",
                        icon: "eye.slash.fill",
                        color: .orange,
                        people: Array(store.theyGhostPeople.prefix(5)),
                        isLoading: store.isLoading,
                        showSentReceived: true
                    )
                    DashboardPeopleCard(
                        title: "I Ghost Them",
                        icon: "moon.zzz.fill",
                        color: .purple,
                        people: Array(store.iGhostPeople.prefix(5)),
                        isLoading: store.isLoading,
                        showSentReceived: true
                    )
                }

                // MARK: - Hourly Activity
                if !store.hourlyActivity.isEmpty {
                    let allPlatforms = Set(store.hourlyActivity.map(\.platform)).sorted { $0.displayName < $1.displayName }
                    let filteredActivity = store.hourlyActivity.filter { activePlatforms.contains($0.platform) }
                    let visiblePlatforms = allPlatforms.filter { activePlatforms.contains($0) }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Most Active Hours", systemImage: "clock.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(activePlatforms.count) of \(allPlatforms.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Platform toggles
                        FlowLayout(spacing: 6) {
                            ForEach(allPlatforms) { platform in
                                let isOn = activePlatforms.contains(platform)
                                Button {
                                    if isOn {
                                        activePlatforms.remove(platform)
                                    } else {
                                        activePlatforms.insert(platform)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: platform.iconName)
                                            .font(.system(size: 10))
                                        Text(platform.displayName)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isOn ? platform.color.opacity(0.15) : .clear, in: Capsule())
                                    .foregroundStyle(isOn ? platform.color : .secondary.opacity(0.5))
                                    .overlay(
                                        Capsule().strokeBorder(isOn ? platform.color.opacity(0.3) : .secondary.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !filteredActivity.isEmpty {
                            Chart(filteredActivity) { point in
                                LineMark(
                                    x: .value("Hour", point.hour),
                                    y: .value("Messages", point.count)
                                )
                                .foregroundStyle(by: .value("Platform", point.platform.displayName))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))

                                AreaMark(
                                    x: .value("Hour", point.hour),
                                    y: .value("Messages", point.count)
                                )
                                .foregroundStyle(by: .value("Platform", point.platform.displayName))
                                .interpolationMethod(.catmullRom)
                                .opacity(0.1)
                            }
                            .chartForegroundStyleScale(
                                domain: visiblePlatforms.map(\.displayName),
                                range: visiblePlatforms.map(\.color)
                            )
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
                            .chartYAxis {
                                AxisMarks { _ in
                                    AxisGridLine()
                                    AxisValueLabel()
                                }
                            }
                            .chartLegend(.hidden)
                            .frame(height: 220)
                            .animation(.easeInOut(duration: 0.3), value: activePlatforms)
                        } else {
                            Text("Select a platform above")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 220)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .onChange(of: store.hourlyActivity.count) {
                        if !platformsInitialized {
                            activePlatforms = Set(store.hourlyActivity.map(\.platform))
                            platformsInitialized = true
                        }
                    }
                    .onAppear {
                        if !platformsInitialized && !store.hourlyActivity.isEmpty {
                            activePlatforms = Set(store.hourlyActivity.map(\.platform))
                            platformsInitialized = true
                        }
                    }
                }

                // MARK: - Platform Ranking
                VStack(alignment: .leading, spacing: 12) {
                    Label("Platforms", systemImage: "app.connected.to.app.below.fill")
                        .font(.headline)

                    if store.platformStats.isEmpty && !store.isLoading {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 32)
                    } else {
                        Chart(store.platformStats) { stat in
                            BarMark(
                                x: .value("Chats", stat.chatCount),
                                y: .value("Platform", stat.platform.displayName)
                            )
                            .foregroundStyle(stat.platform.color)
                            .cornerRadius(4)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("\(stat.chatCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel()
                            }
                        }
                        .frame(minHeight: 200)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .overlay {
            if store.isLoading && !store.isCached {
                VStack(spacing: 8) {
                    ProgressView()
                    if let progress = store.loadingProgress {
                        Text(progress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

}
