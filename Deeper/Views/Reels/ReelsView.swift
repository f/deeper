//
//  ReelsView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI
import Charts

struct ReelsView: View {
    var store: DataStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if store.isLoading && !store.isCached {
                    VStack(spacing: 12) {
                        ProgressView()
                        if let progress = store.loadingProgress {
                            Text(progress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 100)
                } else if !store.hasInstagram {
                    ContentUnavailableView(
                        "No Instagram Account",
                        systemImage: "camera.fill",
                        description: Text("Connect an Instagram account in Beeper to see Reels stats")
                    )
                } else {
                    // MARK: - Summary Cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Reels Sent",
                            value: "\(store.totalReelsSent)",
                            icon: "arrow.up.circle.fill",
                            color: .pink
                        )
                        StatCard(
                            title: "Reels Received",
                            value: "\(store.totalReelsReceived)",
                            icon: "arrow.down.circle.fill",
                            color: .purple
                        )
                        StatCard(
                            title: "People",
                            value: "\(store.reelEntries.count)",
                            icon: "person.2.fill",
                            color: .orange
                        )
                    }

                    // MARK: - Top Reels Chart
                    if !store.reelEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Who Do You Share Reels With?")
                                .font(.headline)

                            let topEntries = Array(store.reelEntries.prefix(10))
                            Chart(topEntries) { entry in
                                BarMark(
                                    x: .value("Reels Sent", entry.reelsSent),
                                    y: .value("Person", entry.personName)
                                )
                                .foregroundStyle(.pink.gradient)
                                .cornerRadius(4)

                                BarMark(
                                    x: .value("Reels Received", entry.reelsReceived),
                                    y: .value("Person", entry.personName)
                                )
                                .foregroundStyle(.purple.gradient)
                                .cornerRadius(4)
                            }
                            .chartForegroundStyleScale([
                                "Sent": .pink,
                                "Received": .purple
                            ])
                            .frame(height: CGFloat(topEntries.count * 40 + 40))
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    }

                    // MARK: - Leaderboard
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reels Leaderboard")
                            .font(.headline)

                        ForEach(Array(store.reelEntries.prefix(50).enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                Circle()
                                    .fill(Color.pink.gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(String(entry.personName.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.personName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    if let date = entry.lastReelDate {
                                        Text("Last: \(date, style: .relative) ago")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up")
                                            .font(.caption2)
                                            .foregroundStyle(.pink)
                                        Text("\(entry.reelsSent)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down")
                                            .font(.caption2)
                                            .foregroundStyle(.purple)
                                        Text("\(entry.reelsReceived)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                .fixedSize()

                                Text("\(entry.totalReels)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .fixedSize()
                                    .frame(minWidth: 40, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                index < 3 ? Color.pink.opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
            .padding(24)
        }
        .navigationTitle("Instagram Reels")
    }
}
