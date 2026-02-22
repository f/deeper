//
//  PeopleView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI

struct PeopleView: View {
    var store: DataStore
    @State private var searchText = ""
    @State private var selectedPerson: MergedPerson?
    @State private var selectedCategory: ConnectionType? = nil

    var activePeople: [MergedPerson] {
        switch selectedCategory {
        case .twoWay: store.twoWayPeople
        case .theyGhost: store.theyGhostPeople
        case .iGhost: store.iGhostPeople
        case .inactive: store.mergedPeople.filter { $0.connectionType == .inactive }
        case nil: store.mergedPeople
        }
    }

    var filteredPeople: [MergedPerson] {
        if searchText.isEmpty { return activePeople }
        return activePeople.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            // MARK: - People List
            VStack(spacing: 0) {
                // Category picker
                HStack(spacing: 6) {
                    CategoryPill(label: "All", icon: "person.3.fill", color: .primary, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    CategoryPill(label: "Two-Way", icon: "arrow.left.arrow.right", color: .green, isSelected: selectedCategory == .twoWay) {
                        selectedCategory = .twoWay
                    }
                    CategoryPill(label: "They Ghost", icon: "eye.slash.fill", color: .orange, isSelected: selectedCategory == .theyGhost) {
                        selectedCategory = .theyGhost
                    }
                    CategoryPill(label: "I Ghost", icon: "moon.zzz.fill", color: .purple, isSelected: selectedCategory == .iGhost) {
                        selectedCategory = .iGhost
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                if store.isLoading && !store.isCached {
                    VStack(spacing: 12) {
                        ProgressView()
                        if let progress = store.loadingProgress {
                            Text(progress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPeople.isEmpty {
                    ContentUnavailableView(
                        "No People Found",
                        systemImage: "person.slash.fill",
                        description: Text(searchText.isEmpty ? "No people in this category" : "No results for \"\(searchText)\"")
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 40)
                } else {
                    List(Array(filteredPeople.enumerated()), id: \.element.id, selection: $selectedPerson) { index, person in
                        PersonRow(person: person, rank: index + 1)
                            .tag(person)
                    }
                }
            }
            .frame(minWidth: 380)
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("People")

            // MARK: - Detail
            if let person = selectedPerson {
                PersonDetailView(person: person, store: store)
                    .frame(minWidth: 300)
            } else {
                Text("Select a person")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct CategoryPill: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? color.opacity(0.15) : .clear, in: Capsule())
                .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct PersonRow: View {
    let person: MergedPerson
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(person.platforms.first?.color.gradient ?? Color.gray.gradient)
                    .frame(width: 40, height: 40)
                Text(String(person.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                FlowLayout(spacing: 4) {
                    ForEach(person.platforms) { platform in
                        HStack(spacing: 2) {
                            Image(systemName: platform.iconName)
                                .font(.system(size: 9))
                            Text(platform.displayName)
                                .font(.system(size: 10))
                        }
                        .fixedSize()
                        .foregroundStyle(platform.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(platform.color.opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if person.totalMessageCount > 0 {
                    HStack(spacing: 6) {
                        Label("\(person.messagesSent)", systemImage: "arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Label("\(person.messagesReceived)", systemImage: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: person.connectionType.icon)
                        .font(.system(size: 8))
                    Text(person.connectionType.rawValue)
                        .font(.system(size: 9))
                }
                .foregroundStyle(connectionColor(for: person.connectionType))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(connectionColor(for: person.connectionType).opacity(0.1), in: Capsule())

                if let date = person.lastActivity {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    func connectionColor(for type: ConnectionType) -> Color {
        switch type {
        case .twoWay: .green
        case .theyGhost: .orange
        case .iGhost: .purple
        case .inactive: .gray
        }
    }
}
