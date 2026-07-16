import SwiftUI
import UniformTypeIdentifiers

// =============================================
// 🎮 CONTENT VIEW — This is YOUR file to build!
// Type this code yourself in Swift Playgrounds.
// =============================================

// MARK: - 🏠 Main View with Tabs

struct ContentView: View {
    var pool: PoolData
    @State private var selectedTab = AppTab.setup

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Setup", systemImage: "person.3.fill", value: .setup) {
                SetupView(pool: pool)
            }

            Tab("Games", systemImage: "sportscourt.fill", value: .games) {
                GamesView(pool: pool)
            }

            Tab("Bracket", systemImage: "trophy.circle", value: .bracket) {
                BracketView(pool: pool)
            }

            Tab("Scoreboard", systemImage: "trophy.fill", value: .scoreboard) {
                ScoreboardView(pool: pool)
            }
        }
    }
}

// MARK: - ⚙️ Setup View

struct SetupView: View {
    var pool: PoolData
    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<4, id: \.self) { index in
                    PlayerSetupSection(pool: pool, playerIndex: index)
                }
            }
            .navigationTitle("⚙️ Setup Players")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Import", systemImage: "square.and.arrow.down") {
                        showingImport = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: PoolDataFile(url: pool.createExportFile()),
                        preview: SharePreview("World Cup Pool")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImport,
                allowedContentTypes: [.json]
            ) { result in
                if case .success(let url) = result {
                    pool.importData(from: url)
                }
            }
        }
    }
}

// MARK: - ⚽ Games View

struct GamesView: View {
    var pool: PoolData
    @State private var showingAddGame = false

    var body: some View {
        NavigationStack {
            Group {
                if pool.games.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "sportscourt",
                        description: Text("Tap + to record a match result!")
                    )
                } else {
                    List {
                        ForEach(pool.games) { game in
                            GameRow(game: game, pool: pool)
                        }
                        .onDelete { offsets in
                            pool.games.remove(atOffsets: offsets)
                            pool.save()
                        }
                    }
                }
            }
            .navigationTitle("⚽ Games")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Game", systemImage: "plus", action: showAddGame)
                        .disabled(pool.allTeams.count < 2)
                }
            }
            .sheet(isPresented: $showingAddGame) {
                AddGameSheet(pool: pool)
            }
        }
    }

    private func showAddGame() {
        showingAddGame = true
    }
}

// MARK: - 🏆 Bracket View

struct BracketView: View {
    var pool: PoolData

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 16) {
                    BracketColumn(pool: pool, round: .r32,
                                  matchCount: pool.matchCount(for: .r32))
                    BracketColumn(pool: pool, round: .r16,
                                  matchCount: pool.matchCount(for: .r16))
                    BracketColumn(pool: pool, round: .quarter,
                                  matchCount: pool.matchCount(for: .quarter))
                    BracketColumn(pool: pool, round: .semi,
                                  matchCount: pool.matchCount(for: .semi))

                    // Final and 3rd-place share the last column
                    VStack(spacing: 24) {
                        BracketColumn(pool: pool, round: .final,
                                      matchCount: 1)
                        BracketColumn(pool: pool, round: .thirdPlace,
                                      matchCount: 1)
                    }
                }
                .padding()
            }
            .navigationTitle("🏆 Bracket")
        }
    }
}

// MARK: - 📊 Scoreboard View

struct ScoreboardView: View {
    var pool: PoolData

    /// The player indices sorted by most points first
    var rankings: [(index: Int, points: Double)] {
        (0..<4)
            .map { (index: $0, points: pool.points(for: $0)) }
            .sorted { $0.points > $1.points }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Standings") {
                    ForEach(rankings.indices, id: \.self) { rank in
                        let entry = rankings[rank]
                        ScoreRow(
                            rank: rank + 1,
                            playerName: pool.playerNames[entry.index],
                            points: entry.points,
                            record: pool.record(for: entry.index),
                            color: playerColors[entry.index]
                        )
                    }
                }

                Section("Team Details") {
                    ForEach(0..<4, id: \.self) { index in
                        PlayerDetailRow(pool: pool, playerIndex: index)
                    }
                }
            }
            .navigationTitle("🏆 Scoreboard")
        }
    }
}
