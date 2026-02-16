# NewsBar

A macOS menu bar app that shows a scrolling ticker of top news headlines from BBC News and Hacker News.

## Features

- **Smooth scrolling ticker** — Core Animation-driven text that glides across the menu bar
- **Auto-collapse** — After 2 full scrolls, the ticker collapses to a compact newspaper icon
- **Smart refresh** — Checks for new headlines every 15 minutes; only re-shows the ticker when there are new stories
- **Dropdown menu** — Click the icon to see all headlines grouped by source, each clickable to open in your browser
- **Zero dependencies** — Pure Swift/AppKit with Foundation's XMLParser for RSS and URLSession for JSON
- **No Dock icon** — Runs as a menu bar accessory only

## Data Sources

| Source | API | Headlines |
|--------|-----|-----------|
| BBC News | RSS feed (`feeds.bbci.co.uk/news/rss.xml`) | Top 5 |
| Hacker News | Firebase JSON API (`/v0/topstories.json`) | Top 5 |

Each source fetches independently — if one fails, the other still shows.

## Build & Run

Requires macOS 13+ and Swift 5.9+. No Xcode project needed.

```bash
swift build
swift run NewsBar
```

## How It Works

1. **On launch**, fetches headlines from both sources concurrently
2. **Ticker phase** — Concatenates all headlines into a single string, doubled for seamless wrapping. A `CATextLayer` with `CABasicAnimation` smoothly translates the text at 60px/sec. A `DispatchWorkItem` timer fires after exactly 2 loops
3. **Icon phase** — Ticker collapses to an SF Symbol (`newspaper.fill`) in the menu bar. The dropdown menu remains accessible with all headlines
4. **Refresh** — Every 15 minutes, fetches fresh headlines and compares titles to the previous set. New headlines trigger the ticker again; unchanged headlines stay as the icon

## Project Structure

```
Package.swift
Sources/NewsBar/
  main.swift                  # NSApplication bootstrap (.accessory policy)
  AppDelegate.swift           # Owns StatusBarController
  StatusBarController.swift   # NSStatusItem, menu, ticker/icon switching
  TickerView.swift            # CATextLayer + CABasicAnimation smooth scroll
  NewsService.swift           # Merges BBC + HN with independent failure
  BBCFeedParser.swift         # XMLParserDelegate for RSS
  HackerNewsClient.swift      # Async JSON client using TaskGroup
  Models.swift                # NewsItem, NewsSource, Constants
```

## Configuration

Constants are in `Models.swift`:

| Constant | Default | Description |
|----------|---------|-------------|
| `refreshInterval` | 900s (15 min) | How often to check for new headlines |
| `tickerLoops` | 2 | Number of full scrolls before collapsing |
| `headlinesPerSource` | 5 | Headlines fetched per source |
