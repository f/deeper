<p align="center">
  <img src="icon.svg" width="128" height="128" alt="Deeper icon">
</p>

<h1 align="center">Deeper</h1>

<p align="center">
  <strong>A macOS messaging analytics app for Beeper — visualize your conversations across every platform.</strong>
</p>

<p align="center">
  See who you talk to most, discover your active hours, find ghosting patterns, and explore group dynamics.
</p>

<p align="center">
  <a href="#download">Download</a> · <a href="#features">Features</a> · <a href="#how-it-works">How It Works</a> · <a href="#building-from-source">Build</a>
</p>

---

## What is Deeper?

Deeper connects to your local [Beeper](https://beeper.com) Desktop app and turns your messaging data into beautiful, interactive analytics. It merges contacts across platforms (iMessage, WhatsApp, Instagram, Telegram, Signal, X/Twitter, and more), analyzes sent vs received message patterns, and visualizes everything with native macOS charts and Liquid Glass effects.

All data stays on your machine. Deeper talks only to your local Beeper Desktop instance — nothing is sent to any server.

## Download

**[Download the latest .dmg from Releases](https://github.com/f/deeper/releases/latest)**

Or install with Homebrew:

```bash
brew install f/tap/deeper
```

> Requires **macOS 26 Tahoe** or later. Beeper Desktop must be running.

## Features

### Dashboard
- **At-a-glance stats** — accounts, total chats, unread count, messages sent today
- **Connection categories** — two-way connected, they ghost me, I ghost them
- **Most Active Hours** — interactive line chart per platform with toggleable filters
- **Platform ranking** — bar chart of chat distribution across platforms

### People
- **Cross-platform merging** — contacts with the same name on different platforms are merged into a single profile
- **Smart deduplication** — different users with the same name on the same platform stay separate
- **Sent/received breakdown** — see message reciprocity per person
- **Connection type badges** — two-way, they ghost, I ghost, inactive
- **Category filters** — filter by connection type
- **Detail view** — per-person platform breakdown, reciprocity percentage, connection analysis

### Groups
- **Most active groups** — ranked by message volume with sent/received counts
- **Largest groups** — bar chart by member count
- **Per-platform breakdown** — collapsible group lists with member counts, unread badges, muted/pinned indicators
- **Group distribution** — donut chart of groups across platforms

### Platforms
- **Chat distribution** — donut chart across all platforms
- **Groups vs DMs** — grouped bar chart per platform
- **Platform detail cards** — chat count, unread, DMs, groups, top contacts per platform

### Reels
- **Instagram Reels leaderboard** — who you share the most Reels with
- **Sent vs received chart** — horizontal bar chart of Reels exchanges
- **Summary stats** — total Reels sent, received, unique people

### Live Feed
- **Real-time WebSocket** — see new messages, reactions, and read receipts as they happen

### General
- **Data caching** — fetches everything once, instant tab switching
- **Sync button** — ⌘R to refetch all data
- **Secure auth** — Bearer token stored in macOS Keychain
- **Liquid Glass UI** — native macOS 26 design with `.glassEffect()`

## How It Works

1. **Open Beeper Desktop** — Deeper connects to Beeper's local API at `localhost:23373`.
2. **Enter your token** — Paste your Beeper auth token on first launch. It's stored securely in Keychain.
3. **Explore your data** — Deeper fetches all your chats, merges contacts, analyzes messages, and presents interactive dashboards.

| Tab | What you'll see |
|---|---|
| **Dashboard** | Stats overview, connection categories, hourly activity chart, platform ranking |
| **People** | All contacts ranked by message volume, filterable by connection type |
| **Groups** | Most active groups, largest groups, per-platform group lists |
| **Platforms** | Chat distribution, groups vs DMs breakdown, platform detail cards |
| **Reels** | Instagram Reels sharing leaderboard |
| **Live Feed** | Real-time message stream via WebSocket |

## Building from Source

### Requirements
- macOS 26+
- Xcode 26+
- Swift 6.0+
- Beeper Desktop running locally

### Build

```bash
git clone https://github.com/f/deeper.git
cd deeper/Deeper
open Deeper.xcodeproj
```

Build and run with ⌘R in Xcode.

### Build DMG

```bash
cd deeper/Deeper
chmod +x build.sh
./build.sh
```

The DMG will be at `build/release/Deeper.dmg`.

### Project Structure

```
Deeper/
├── Deeper.xcodeproj
├── build.sh                              # Universal build + DMG script
└── Deeper/
    ├── DeeperApp.swift                   # App entry point, Settings scene
    ├── ContentView.swift                 # Sidebar navigation, DataStore wiring
    │
    ├── Models/
    │   ├── BeeperModels.swift            # API response types (Chat, Message, User)
    │   ├── MergedPerson.swift            # Cross-platform person model
    │   ├── PlatformInfo.swift            # Platform enum, bridge detection
    │   └── GroupStats.swift              # Group analytics models
    │
    ├── Services/
    │   ├── BeeperAPIClient.swift         # REST API client with pagination
    │   ├── DataStore.swift               # Central data cache + sync engine
    │   ├── PersonMerger.swift            # Cross-platform contact merging
    │   ├── ReelsAnalyzer.swift           # Instagram Reels analysis
    │   ├── WebSocketManager.swift        # Live feed WebSocket connection
    │   └── KeychainHelper.swift          # Secure token storage
    │
    ├── ViewModels/
    │   └── DashboardViewModel.swift      # HourlyActivityPoint model
    │
    └── Views/
        ├── Dashboard/
        │   ├── DashboardView.swift       # Main dashboard with charts
        │   ├── DashboardPeopleCard.swift # Connection category cards
        │   ├── StatCard.swift            # Stat card component
        │   └── FlowLayout.swift          # Wrapping layout for tags
        ├── People/
        │   ├── PeopleView.swift          # People list with category filters
        │   └── PersonDetailView.swift    # Person detail with platform breakdown
        ├── Groups/
        │   └── GroupsView.swift          # Group analytics and leaderboard
        ├── Platforms/
        │   └── PlatformsView.swift       # Platform distribution charts
        ├── Reels/
        │   └── ReelsView.swift           # Instagram Reels leaderboard
        ├── Live/
        │   └── LiveFeedView.swift        # Real-time WebSocket feed
        └── Settings/
            └── SettingsView.swift        # Token input and connection setup
```

## Supported Platforms

Deeper detects platforms from Beeper bridge account IDs:

| Platform | Bridge Keywords |
|---|---|
| iMessage | `imessage`, `imessagecloud` |
| WhatsApp | `whatsapp` |
| Instagram | `instagram` |
| Telegram | `telegram` |
| Signal | `signal` |
| X (Twitter) | `twitter` |
| Facebook Messenger | `facebook`, `messenger` |
| Discord | `discord` |
| Slack | `slack` |
| LinkedIn | `linkedin` |
| Google Messages | `gmessages`, `googlechat` |
| SMS | `androidsms` |

## Privacy

- **100% local** — Deeper only connects to `localhost:23373` (Beeper Desktop)
- **No telemetry** — no analytics, no tracking, no external requests
- **Token in Keychain** — your Beeper auth token is stored in macOS Keychain, not in plaintext
- **Open source** — audit the code yourself

## License

MIT License. See [LICENSE](LICENSE) for details.
