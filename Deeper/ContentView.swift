//
//  ContentView.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case today = "Today"
    case thisWeek = "This Week"
    case people = "People"
    case groups = "Groups"
    case platforms = "Platforms"
    case reels = "Reels"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .today: "sun.max.fill"
        case .thisWeek: "calendar"
        case .people: "person.3.fill"
        case .groups: "person.3.sequence.fill"
        case .platforms: "app.connected.to.app.below.fill"
        case .reels: "play.rectangle.fill"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @State var api: BeeperAPIClient?
    @State var store: DataStore?
    @State private var hasInitialized = false

    var body: some View {
        Group {
            if let store {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail(store: store)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if store.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 24, height: 24)
                        } else {
                            Button {
                                Task { await store.sync() }
                            } label: {
                                Label("Sync", systemImage: "arrow.clockwise")
                            }
                            .keyboardShortcut("r", modifiers: .command)
                        }
                    }
                }
            } else {
                WelcomeView(onConnect: { client in
                    self.api = client
                    let newStore = DataStore(api: client)
                    self.store = newStore
                    Task { await newStore.sync() }
                })
            }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            guard let token = KeychainHelper.loadToken() else { return }
            let baseURL = KeychainHelper.loadBaseURL() ?? "http://localhost:23373"
            let client = BeeperAPIClient(baseURL: baseURL, token: token)
            self.api = client
            let newStore = DataStore(api: client)
            self.store = newStore
            Task { await newStore.sync() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deeperDidLogout)) { _ in
            self.api = nil
            self.store = nil
            self.hasInitialized = false
        }
    }

    private var sidebar: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .navigationTitle("Deeper")
    }

    @ViewBuilder
    private func detail(store: DataStore) -> some View {
        switch selection {
        case .dashboard:
            DashboardView(store: store)
        case .today:
            TimeRangeView(
                title: "Today",
                store: store,
                stats: store.todayStats,
                isFetching: store.isFetchingToday,
                showDaily: false,
                onRefresh: { await store.fetchTodayStats() }
            )
        case .thisWeek:
            TimeRangeView(
                title: "This Week",
                store: store,
                stats: store.lastWeekStats,
                isFetching: store.isFetchingLastWeek,
                showDaily: true,
                onRefresh: { await store.fetchLastWeekStats() }
            )
        case .people:
            PeopleView(store: store)
        case .groups:
            GroupsView(store: store)
        case .platforms:
            PlatformsView(store: store)
        case .reels:
            ReelsView(store: store)
        case nil:
            Text("Select an item from the sidebar")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
