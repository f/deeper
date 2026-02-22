<p align="center">
  <img src="icon.svg" width="128" height="128" alt="Deeper icon">
</p>

<h1 align="center">Deeper</h1>

<p align="center">
  <strong>A macOS messaging analytics app for Beeper — visualize your conversations across every platform, with on-device AI.</strong>
</p>

<p align="center">
  See who you talk to most, discover your active hours, find ghosting patterns, explore group dynamics, and get AI-powered conversation summaries.
</p>

<p align="center">
  <a href="#download">Download</a> · <a href="#features">Features</a> · <a href="#how-it-works">How It Works</a> · <a href="#building-from-source">Build</a>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="800" alt="Deeper screenshot">
</p>

---

## What is Deeper?

Deeper connects to your local [Beeper](https://beeper.com) Desktop app and turns your messaging data into beautiful, interactive analytics. It merges contacts across platforms (iMessage, WhatsApp, Instagram, Telegram, Signal, X/Twitter, and more), analyzes sent vs received message patterns, and visualizes everything with native macOS charts and Liquid Glass effects.

Deeper uses **Apple Intelligence (on-device)** to summarize your conversations — no cloud, no API keys, no data leaves your Mac. The Foundation Models framework runs entirely on your Apple Silicon, keeping everything private by design.

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
- **Per-person response time** — average reply time for you and the other person
- **Apple Intelligence summary** — on-device AI conversation summary with animated glow border
- **Per-person phrase analytics** — word cloud and stats for words you use with each person

### Groups
- **Most active groups** — ranked by message volume with sent/received counts
- **Largest groups** — bar chart by member count
- **Per-platform breakdown** — collapsible group lists with member counts, unread badges, muted/pinned indicators
- **Group distribution** — donut chart of groups across platforms

### Platforms
- **Chat distribution** — donut chart across all platforms
- **Groups vs DMs** — grouped bar chart per platform
- **Platform detail cards** — chat count, unread, DMs, groups, top contacts per platform

### Phrases
- **Word frequency analysis** — top words and phrases you use most
- **Word cloud** — visual representation of your most-used words
- **Stats** — total words, unique words, average message length
- **Date range filtering** — filter by week, month, quarter, or all time

### Response Time
- **Response time leaderboard** — see who responds fastest and who keeps you waiting
- **Your response times** — average time you take to reply per person
- **Their response times** — average time others take to reply to you
- **Date range filtering** — filter by week, month, quarter, or all time

### Reels
- **Instagram Reels leaderboard** — who you share the most Reels with
- **Sent vs received chart** — horizontal bar chart of Reels exchanges
- **Summary stats** — total Reels sent, received, unique people
- **Date range filtering** — filter by week, month, quarter, or all time

### Apple Intelligence (On-Device)
- **On-device conversation summary** — summarizes your recent messages with each person using Apple's Foundation Models, running entirely on your Apple Silicon — nothing leaves your Mac
- **System language detection** — responds in your macOS system language automatically
- **Animated glow border** — Apple Intelligence-style rainbow gradient animation
- **Graceful availability handling** — shows specific status for downloading, not enabled, or unsupported devices
- **No API keys needed** — uses the built-in on-device LLM, no cloud services or subscriptions required

### General
- **Grouped sidebar** — organized into Overview, Contacts, and Analytics sections
- **Data caching** — split into multiple cache files for efficient memory usage
- **Sync button** — ⌘R to refetch all data
- **Secure auth** — Bearer token stored in macOS Keychain
- **Liquid Glass UI** — native macOS 26 design with `.glassEffect()`
- **Date range filtering** — week, month, quarter, or all time across analytics views

## Getting Your API Token

Deeper requires a Beeper Desktop API token to access your messaging data. Here's how to set it up:

1. Open **Beeper Desktop** and go to **Settings**
2. Navigate to the **Developers** tab in the sidebar
3. Toggle **Beeper Desktop API** to **On** (this enables the local API on port `23373`)
4. Enable **Start on launch** so the API is always available
5. Scroll down to the **Approved Connections** section
6. Click the **+** button on the right to generate a new API token
7. Copy the generated token — you'll paste it into Deeper on first launch

> The API runs entirely on your local machine at `http://localhost:23373`. No data leaves your computer.

## How It Works

1. **Open Beeper Desktop** — Deeper connects to Beeper's local API at `localhost:23373`.
2. **Enter your token** — Paste your Beeper auth token on first launch. It's stored securely in Keychain.
3. **Explore your data** — Deeper fetches all your chats, merges contacts, analyzes messages, and presents interactive dashboards.

| Tab | What you'll see |
|---|---|
| **Dashboard** | Stats overview, connection categories, hourly activity chart, platform ranking |
| **Today / This Week** | Time-scoped message stats |
| **People** | All contacts ranked by message volume, filterable by connection type, AI summaries |
| **Groups** | Most active groups, largest groups, per-platform group lists |
| **Platforms** | Chat distribution, groups vs DMs breakdown, platform detail cards |
| **Phrases** | Word frequency analysis and word cloud with date range filter |
| **Response Time** | Response time leaderboard with date range filter |
| **Reels** | Instagram Reels sharing leaderboard with date range filter |

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
    │   ├── AnalyticsModels.swift         # Phrase, response time, timestamped data models
    │   ├── BeeperModels.swift            # API response types (Chat, Message, User)
    │   ├── MergedPerson.swift            # Cross-platform person model
    │   ├── PlatformInfo.swift            # Platform enum, bridge detection
    │   └── GroupStats.swift              # Group analytics models
    │
    ├── Services/
    │   ├── BeeperAPIClient.swift         # REST API client with pagination
    │   ├── BeeperOAuthService.swift      # OAuth authentication service
    │   ├── DataStore.swift               # Central data cache + sync engine
    │   ├── PersonMerger.swift            # Cross-platform contact merging
    │   ├── ReelsAnalyzer.swift           # Instagram Reels analysis
    │   ├── WebSocketManager.swift        # Live WebSocket feed
    │   └── KeychainHelper.swift          # Secure token storage
    │
    ├── ViewModels/
    │   ├── DashboardViewModel.swift      # HourlyActivityPoint model
    │   ├── PeopleViewModel.swift         # People view model
    │   ├── PlatformsViewModel.swift      # Platforms view model
    │   └── ReelsViewModel.swift          # Reels view model
    │
    └── Views/
        ├── Dashboard/
        │   ├── DashboardView.swift       # Main dashboard with charts
        │   ├── DashboardPeopleCard.swift # Connection category cards
        │   ├── StatCard.swift            # Stat card component
        │   └── FlowLayout.swift          # Wrapping layout for tags
        ├── People/
        │   ├── PeopleView.swift          # People list with category filters
        │   └── PersonDetailView.swift    # Person detail, AI summary, response times
        ├── Groups/
        │   └── GroupsView.swift          # Group analytics and leaderboard
        ├── Platforms/
        │   └── PlatformsView.swift       # Platform distribution charts
        ├── Phrases/
        │   └── PhrasesView.swift         # Word frequency analytics + word cloud
        ├── ResponseTime/
        │   └── ResponseTimeView.swift    # Response time leaderboard
        ├── Reels/
        │   └── ReelsView.swift           # Instagram Reels leaderboard
        ├── TimeRange/
        │   └── TimeRangeView.swift       # Today / This Week stats
        ├── Welcome/
        │   └── WelcomeView.swift         # Welcome / onboarding screen
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
- **On-device AI** — conversation summaries run on Apple Silicon via Foundation Models, never sent to the cloud
- **No telemetry** — no analytics, no tracking, no external requests
- **Token in Keychain** — your Beeper auth token is stored in macOS Keychain, not in plaintext
- **Open source** — audit the code yourself

## License

MIT License. See [LICENSE](LICENSE) for details.
