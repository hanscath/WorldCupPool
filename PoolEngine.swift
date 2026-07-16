import SwiftUI
import UniformTypeIdentifiers

// =============================================
// 🏗️ POOL ENGINE — Just copy this whole file!
// It has all the behind-the-scenes stuff.
// =============================================

// MARK: - 📦 Data Models

// MARK: - 🗓️ Bracket Types (for Phase 2)

/// The rounds in the knockout stage
enum BracketRound: String, Codable, CaseIterable {
    case r32        = "Round of 32"
    case r16        = "Round of 16"
    case quarter    = "Quarter-Final"
    case semi       = "Semi-Final"
    case thirdPlace = "3rd Place"
    case final      = "Final"
}

/// Where a game sits in the bracket — round + match number
struct BracketSlot: Codable, Equatable {
    var round: BracketRound
    var matchNumber: Int  // e.g. 1–16 for R32, 1–8 for R16, etc.
}

// MARK: - 🏟️ Venues

/// A World Cup host city
struct Venue: Hashable {
    let city: String
    let country: String

    /// How it shows up in the app, like "Atlanta, USA"
    var displayName: String { "\(city), \(country)" }
}

/// All 16 host cities for the 2026 FIFA World Cup
let worldCupVenues: [Venue] = [
    // 🇺🇸 United States (11 cities)
    Venue(city: "Atlanta", country: "USA"),
    Venue(city: "Boston", country: "USA"),
    Venue(city: "Dallas", country: "USA"),
    Venue(city: "Houston", country: "USA"),
    Venue(city: "Kansas City", country: "USA"),
    Venue(city: "Los Angeles", country: "USA"),
    Venue(city: "Miami", country: "USA"),
    Venue(city: "New York/New Jersey", country: "USA"),
    Venue(city: "Philadelphia", country: "USA"),
    Venue(city: "San Francisco Bay Area", country: "USA"),
    Venue(city: "Seattle", country: "USA"),
    // 🇲🇽 Mexico (3 cities)
    Venue(city: "Guadalajara", country: "Mexico"),
    Venue(city: "Mexico City", country: "Mexico"),
    Venue(city: "Monterrey", country: "Mexico"),
    // 🇨🇦 Canada (2 cities)
    Venue(city: "Toronto", country: "Canada"),
    Venue(city: "Vancouver", country: "Canada"),
]

// MARK: - ⚽ Game Data

/// One match result — which two teams played and the score
/// "Codable" means Swift can turn this into JSON text and back!
struct GameResult: Identifiable, Codable {
    let id: UUID
    var team1: String
    var team2: String
    var goals1: Int
    var goals2: Int

    // New optional fields — nil won't break old saved data!
    var date: Date?
    var location: String?         // e.g. "Atlanta, USA"
    var bracketSlot: BracketSlot? // nil = group stage game

    init(
        team1: String,
        team2: String,
        goals1: Int,
        goals2: Int,
        date: Date? = nil,
        location: String? = nil,
        bracketSlot: BracketSlot? = nil
    ) {
        self.id = UUID()
        self.team1 = team1
        self.team2 = team2
        self.goals1 = goals1
        self.goals2 = goals2
        self.date = date
        self.location = location
        self.bracketSlot = bracketSlot
    }

    /// Has this game actually been played?
    /// Group stage: always yes (0-0 ties are real results).
    /// Bracket: only when at least one team scored (since penalties
    /// are counted as goals, a real knockout result is never 0-0).
    var hasBeenPlayed: Bool {
        if bracketSlot == nil { return true }
        return goals1 > 0 || goals2 > 0
    }
}

/// A snapshot of all pool data, packed up for saving to a file
struct SavedPool: Codable {
    var playerNames: [String]
    var playerTeams: [[String]]
    var games: [GameResult]
}

/// A file wrapper that lets ShareLink send our pool data as a .json file
/// via AirDrop, Messages, email, and more!
struct PoolDataFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(file.url)
        }
    }
}

/// All the data for our pool: players, teams, and game results
@Observable @MainActor
class PoolData {

    // The four player names
    var playerNames = ["Player 1", "Player 2", "Player 3", "Player 4"]

    // Each player's list of countries (up to 12 each)
    var playerTeams: [[String]] = [[], [], [], []]

    // All the games we've recorded
    var games: [GameResult] = []

    // When the app starts, load any saved data from last time
    init() {
        load()
    }

    // MARK: - 💾 Saving & Loading

    /// The file where we save our JSON data on the iPad
    private var saveFileURL: URL {
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        return docs.appendingPathComponent("pool-data.json")
    }

    /// Pack up all our data and write it to a JSON file
    func save() {
        let snapshot = SavedPool(
            playerNames: playerNames,
            playerTeams: playerTeams,
            games: games
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: saveFileURL)
        } catch {
            print("⚠️ Could not save: \(error)")
        }
    }

    /// Read the JSON file and restore our data
    func load() {
        guard FileManager.default.fileExists(atPath: saveFileURL.path) else {
            return  // No save file yet — that's fine, first launch!
        }
        do {
            let data = try Data(contentsOf: saveFileURL)
            let snapshot = try JSONDecoder().decode(SavedPool.self, from: data)
            playerNames = snapshot.playerNames
            playerTeams = snapshot.playerTeams
            games = snapshot.games
        } catch {
            print("⚠️ Could not load: \(error)")
        }
    }

    // MARK: - 📤 Sharing

    /// Create a temporary .json file ready to share via AirDrop, Messages, etc.
    func createExportFile() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorldCupPool.json")
        let snapshot = SavedPool(
            playerNames: playerNames,
            playerTeams: playerTeams,
            games: games
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: tempURL)
        } catch {
            print("⚠️ Export failed: \(error)")
        }
        return tempURL
    }

    /// Load pool data from a shared .json file
    func importData(from url: URL) {
        // Ask iOS for permission to read the file
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(SavedPool.self, from: data)
            playerNames = snapshot.playerNames
            playerTeams = snapshot.playerTeams
            games = snapshot.games
            save()
        } catch {
            print("⚠️ Import failed: \(error)")
        }
    }

    // A sorted list of every country in the pool
    var allTeams: [String] {
        playerTeams.flatMap { $0 }.sorted()
    }

    // Find which player (0–3) owns a country
    func ownerIndex(of team: String) -> Int? {
        for i in 0..<4 {
            if playerTeams[i].contains(team) {
                return i
            }
        }
        return nil
    }

    // Add up the points for one player
    // Win = 1 point, Tie = 0.5 points, Loss = 0 points
    func points(for playerIndex: Int) -> Double {
        var total = 0.0
        let myTeams = playerTeams[playerIndex]

        for game in games {
            guard game.hasBeenPlayed else { continue }

            if myTeams.contains(game.team1) {
                if game.goals1 > game.goals2 {
                    total += 1.0   // Win!
                } else if game.goals1 == game.goals2 {
                    total += 0.5   // Tie
                }
            }

            if myTeams.contains(game.team2) {
                if game.goals2 > game.goals1 {
                    total += 1.0   // Win!
                } else if game.goals2 == game.goals1 {
                    total += 0.5   // Tie
                }
            }
        }

        return total
    }

    // Count wins, ties, and losses for one player
    func record(for playerIndex: Int) -> (wins: Int, ties: Int, losses: Int) {
        var wins = 0
        var ties = 0
        var losses = 0
        let myTeams = playerTeams[playerIndex]

        for game in games {
            guard game.hasBeenPlayed else { continue }

            if myTeams.contains(game.team1) {
                if game.goals1 > game.goals2 { wins += 1 }
                else if game.goals1 == game.goals2 { ties += 1 }
                else { losses += 1 }
            }
            if myTeams.contains(game.team2) {
                if game.goals2 > game.goals1 { wins += 1 }
                else if game.goals2 == game.goals1 { ties += 1 }
                else { losses += 1 }
            }
        }

        return (wins, ties, losses)
    }

    // MARK: - 🏆 Bracket Logic

    /// How many matches in each round
    func matchCount(for round: BracketRound) -> Int {
        switch round {
        case .r32: return 16
        case .r16: return 8
        case .quarter: return 4
        case .semi: return 2
        case .final: return 1
        case .thirdPlace: return 1
        }
    }

    /// Find the game result for a bracket slot (if one has been entered)
    func bracketGame(for slot: BracketSlot) -> GameResult? {
        games.first { $0.bracketSlot == slot }
    }

    /// Figure out which team plays in a given position of a bracket match.
    /// For R32, teams come from the saved game. For later rounds,
    /// teams come from the WINNERS of the feeder matches.
    func bracketTeam(slot: BracketSlot, position: Int) -> String? {
        // If this match already has a game result, use its stored teams
        if let game = bracketGame(for: slot) {
            let team = position == 1 ? game.team1 : game.team2
            return team.isEmpty ? nil : team
        }

        // R32 matches without a game don't have teams yet
        if slot.round == .r32 { return nil }

        // For later rounds, look at the feeder match result
        let feeder = feederSlot(for: slot, position: position)
        guard let feederGame = bracketGame(for: feeder) else { return nil }

        // 3rd-place match gets the LOSERS of the semi-finals
        if slot.round == .thirdPlace {
            return loser(of: feederGame)
        }
        // Everything else gets the WINNER
        return winner(of: feederGame)
    }

    /// Which match from the previous round feeds into this slot?
    /// position 1 = top team, position 2 = bottom team
    func feederSlot(for slot: BracketSlot, position: Int) -> BracketSlot {
        let prevRound: BracketRound
        switch slot.round {
        case .r16: prevRound = .r32
        case .quarter: prevRound = .r16
        case .semi: prevRound = .quarter
        case .final, .thirdPlace: prevRound = .semi
        case .r32: fatalError("R32 has no feeder round")
        }

        if slot.round == .final || slot.round == .thirdPlace {
            // Final/3rd-place: position 1 comes from SF match 1, position 2 from SF match 2
            return BracketSlot(round: prevRound, matchNumber: position)
        }

        // Standard bracket wiring: match N gets winners from matches (2N-1) and (2N)
        let feederMatch = (slot.matchNumber - 1) * 2 + position
        return BracketSlot(round: prevRound, matchNumber: feederMatch)
    }

    /// Get the winning team of a game (nil if tied or no result)
    func winner(of game: GameResult) -> String? {
        if game.goals1 > game.goals2 { return game.team1 }
        if game.goals2 > game.goals1 { return game.team2 }
        return nil
    }

    /// Get the losing team of a game (nil if tied or no result)
    func loser(of game: GameResult) -> String? {
        if game.goals1 > game.goals2 { return game.team2 }
        if game.goals2 > game.goals1 { return game.team1 }
        return nil
    }

    /// Save (or update) a bracket game result
    func saveBracketGame(slot: BracketSlot, team1: String, team2: String,
                         goals1: Int, goals2: Int, date: Date?, location: String?) {
        // Remove any existing game for this slot
        games.removeAll { $0.bracketSlot == slot }

        let game = GameResult(
            team1: team1, team2: team2,
            goals1: goals1, goals2: goals2,
            date: date, location: location,
            bracketSlot: slot
        )
        games.append(game)
        save()
    }

    /// Countries available for R32 assignment (not already used in other R32 matches)
    func availableForBracket(slot: BracketSlot, excluding otherTeam: String) -> [String] {
        let otherR32Games = games.filter {
            $0.bracketSlot?.round == .r32 && $0.bracketSlot != slot
        }
        let usedSet = Set(otherR32Games.flatMap { [$0.team1, $0.team2] }.filter { !$0.isEmpty })

        return allWorldCupCountries.filter { country in
            !usedSet.contains(country) && country != otherTeam
        }.sorted()
    }
}

// MARK: - 🎨 Constants

/// The colors we use for each player (so you can tell them apart)
let playerColors: [Color] = [.blue, .red, .green, .orange]

/// The emoji dots for each player slot
let playerEmojis = ["🔵", "🔴", "🟢", "🟠"]

/// Which tab is selected
enum AppTab {
    case setup, games, bracket, scoreboard
}

/// All 48 countries in the 2026 FIFA World Cup 🏆
let allWorldCupCountries: [String] = [
    // Group A
    "Mexico", "South Africa", "South Korea", "Czechia",
    // Group B
    "Portugal", "Norway", "Iraq", "Curaçao",
    // Group C
    "Netherlands", "Senegal", "Ecuador", "Ivory Coast",
    // Group D
    "Brazil", "Colombia", "Bosnia and Herzegovina", "Cape Verde",
    // Group E
    "Argentina", "Haiti", "Algeria", "Uzbekistan",
    // Group F
    "Spain", "Paraguay", "United States", "DR Congo",
    // Group G
    "Croatia", "Scotland", "Panama", "Jordan",
    // Group H
    "England", "Saudi Arabia", "Tunisia", "Ghana",
    // Group I
    "France", "Canada", "Morocco", "Australia",
    // Group J
    "Germany", "Uruguay", "Sweden", "Japan",
    // Group K
    "Belgium", "Iran", "Egypt", "New Zealand",
    // Group L
    "Switzerland", "Türkiye", "Austria", "Qatar",
]

/// Flag emojis for every country in the tournament
let countryFlags: [String: String] = [
    "Mexico": "🇲🇽", "South Africa": "🇿🇦", "South Korea": "🇰🇷", "Czechia": "🇨🇿",
    "Portugal": "🇵🇹", "Norway": "🇳🇴", "Iraq": "🇮🇶", "Curaçao": "🇨🇼",
    "Netherlands": "🇳🇱", "Senegal": "🇸🇳", "Ecuador": "🇪🇨", "Ivory Coast": "🇨🇮",
    "Brazil": "🇧🇷", "Colombia": "🇨🇴", "Bosnia and Herzegovina": "🇧🇦", "Cape Verde": "🇨🇻",
    "Argentina": "🇦🇷", "Haiti": "🇭🇹", "Algeria": "🇩🇿", "Uzbekistan": "🇺🇿",
    "Spain": "🇪🇸", "Paraguay": "🇵🇾", "United States": "🇺🇸", "DR Congo": "🇨🇩",
    "Croatia": "🇭🇷", "Scotland": "🏴󠁧󠁢󠁳󠁣󠁴󠁿", "Panama": "🇵🇦", "Jordan": "🇯🇴",
    "England": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "Saudi Arabia": "🇸🇦", "Tunisia": "🇹🇳", "Ghana": "🇬🇭",
    "France": "🇫🇷", "Canada": "🇨🇦", "Morocco": "🇲🇦", "Australia": "🇦🇺",
    "Germany": "🇩🇪", "Uruguay": "🇺🇾", "Sweden": "🇸🇪", "Japan": "🇯🇵",
    "Belgium": "🇧🇪", "Iran": "🇮🇷", "Egypt": "🇪🇬", "New Zealand": "🇳🇿",
    "Switzerland": "🇨🇭", "Türkiye": "🇹🇷", "Austria": "🇦🇹", "Qatar": "🇶🇦",
]

/// Look up a country's flag emoji (returns 🏳️ if not found)
func flag(for country: String) -> String {
    countryFlags[country] ?? "🏳️"
}

// MARK: - 🧩 Helper Views
// These are the smaller building-block views.
// Your ContentView.swift will use these!

/// One player's setup section — their name + their list of countries
struct PlayerSetupSection: View {
    var pool: PoolData
    let playerIndex: Int
    @State private var selectedCountry = ""

    /// Countries not yet assigned to any player
    var availableCountries: [String] {
        allWorldCupCountries.filter { country in
            !pool.allTeams.contains(country)
        }.sorted()
    }

    var body: some View {
        Section {
            TextField(
                "Player name",
                text: Bindable(pool).playerNames[playerIndex]
            )
            .font(.headline)
            .foregroundStyle(playerColors[playerIndex])

            Text("\(pool.playerTeams[playerIndex].count) of 12 teams assigned")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Pick a country from the list + Add button
            HStack {
                Picker("Country", selection: $selectedCountry) {
                    Text("Pick a country…").tag("")
                    ForEach(availableCountries, id: \.self) { country in
                        Text("\(flag(for: country)) \(country)").tag(country)
                    }
                }

                Button("Add", action: addCountry)
                    .disabled(selectedCountry.isEmpty || pool.playerTeams[playerIndex].count >= 12)
                    .buttonStyle(.borderedProminent)
                    .tint(playerColors[playerIndex])
            }

            // List of this player's countries (swipe to delete)
            ForEach(pool.playerTeams[playerIndex], id: \.self) { country in
                Text("\(flag(for: country)) \(country)")
            }
            .onDelete { offsets in
                pool.playerTeams[playerIndex].remove(atOffsets: offsets)
                pool.save()
            }
        } header: {
            Text("\(playerEmojis[playerIndex]) \(pool.playerNames[playerIndex])")
        }
        // Save whenever the player's name changes
        .onChange(of: pool.playerNames[playerIndex]) {
            pool.save()
        }
    }

    private func addCountry() {
        guard !selectedCountry.isEmpty else { return }
        guard pool.playerTeams[playerIndex].count < 12 else { return }
        guard !pool.allTeams.contains(selectedCountry) else { return }

        pool.playerTeams[playerIndex].append(selectedCountry)
        selectedCountry = ""
        pool.save()
    }
}

/// Shows one game result in a list row
struct GameRow: View {
    let game: GameResult
    let pool: PoolData

    var body: some View {
        VStack(spacing: 6) {
            // Date, location, and round info on top
            if game.date != nil || game.location != nil || game.bracketSlot != nil {
                HStack {
                    if let date = game.date {
                        Text(date, style: .date)
                    }
                    if let location = game.location {
                        if game.date != nil {
                            Text("·")
                        }
                        Text(location)
                    }
                    Spacer()
                    if let slot = game.bracketSlot {
                        Text(slot.round.rawValue)
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // The score row
            HStack {
                VStack(alignment: .trailing) {
                    Text("\(game.team1) \(flag(for: game.team1))")
                        .font(.headline)
                    ownerLabel(for: game.team1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text("\(game.goals1) – \(game.goals2)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading) {
                    Text("\(flag(for: game.team2)) \(game.team2)")
                        .font(.headline)
                    ownerLabel(for: game.team2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func ownerLabel(for team: String) -> some View {
        Group {
            if let ownerIdx = pool.ownerIndex(of: team) {
                Text(pool.playerNames[ownerIdx])
                    .font(.caption)
                    .foregroundStyle(playerColors[ownerIdx])
            }
        }
    }
}

/// The sheet that pops up to add a new game
struct AddGameSheet: View {
    var pool: PoolData
    @Environment(\.dismiss) private var dismiss

    @State private var team1 = ""
    @State private var team2 = ""
    @State private var goals1 = 0
    @State private var goals2 = 0
    @State private var matchDate = Date()
    @State private var includeDate = false
    @State private var selectedVenue = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Teams") {
                    Picker("Home Team", selection: $team1) {
                        Text("Choose…").tag("")
                        ForEach(pool.allTeams, id: \.self) { country in
                            Text("\(flag(for: country)) \(country)").tag(country)
                        }
                    }

                    Picker("Away Team", selection: $team2) {
                        Text("Choose…").tag("")
                        ForEach(pool.allTeams, id: \.self) { country in
                            Text("\(flag(for: country)) \(country)").tag(country)
                        }
                    }
                }

                Section("Score") {
                    Stepper(
                        "\(team1.isEmpty ? "Home" : "\(flag(for: team1)) \(team1)"): \(goals1)",
                        value: $goals1, in: 0...20
                    )
                    Stepper(
                        "\(team2.isEmpty ? "Away" : "\(flag(for: team2)) \(team2)"): \(goals2)",
                        value: $goals2, in: 0...20
                    )
                }

                Section("Date & Location") {
                    Toggle("Include Date", isOn: $includeDate)
                    if includeDate {
                        DatePicker(
                            "Match Date",
                            selection: $matchDate,
                            displayedComponents: .date
                        )
                    }

                    Picker("Venue", selection: $selectedVenue) {
                        Text("None").tag("")
                        ForEach(worldCupVenues, id: \.self) { venue in
                            Text(venue.displayName).tag(venue.displayName)
                        }
                    }
                }
            }
            .navigationTitle("Add Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancelAdd)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveGame)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !team1.isEmpty && !team2.isEmpty && team1 != team2
    }

    private func cancelAdd() {
        dismiss()
    }

    private func saveGame() {
        let result = GameResult(
            team1: team1,
            team2: team2,
            goals1: goals1,
            goals2: goals2,
            date: includeDate ? matchDate : nil,
            location: selectedVenue.isEmpty ? nil : selectedVenue
        )
        pool.games.append(result)
        pool.save()
        dismiss()
    }
}

/// One row in the scoreboard showing rank, name, and points
struct ScoreRow: View {
    let rank: Int
    let playerName: String
    let points: Double
    let record: (wins: Int, ties: Int, losses: Int)
    let color: Color

    var rankDisplay: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "4️⃣"
        }
    }

    var body: some View {
        HStack {
            Text(rankDisplay)
                .font(.title)

            VStack(alignment: .leading) {
                Text(playerName)
                    .font(.headline)
                    .foregroundStyle(color)
                Text("\(record.wins)W  \(record.ties)T  \(record.losses)L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(pointsText)
                .font(.title.bold())
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }

    var pointsText: String {
        if points == Double(Int(points)) {
            return "\(Int(points)) pts"
        } else {
            return String(format: "%.1f pts", points)
        }
    }
}

/// Shows one player's team list and how each team did
struct PlayerDetailRow: View {
    let pool: PoolData
    let playerIndex: Int

    var body: some View {
        DisclosureGroup {
            if pool.playerTeams[playerIndex].isEmpty {
                Text("No teams assigned yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pool.playerTeams[playerIndex], id: \.self) { team in
                    HStack {
                        Text("\(flag(for: team)) \(team)")
                        Spacer()
                        Text(teamRecord(team))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            HStack {
                Text("\(playerEmojis[playerIndex]) \(pool.playerNames[playerIndex])")
                    .font(.headline)
                    .foregroundStyle(playerColors[playerIndex])
                Spacer()
                Text("\(pool.playerTeams[playerIndex].count) teams")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func teamRecord(_ team: String) -> String {
        var wins = 0, ties = 0, losses = 0

        for game in pool.games {
            guard game.hasBeenPlayed else { continue }

            if game.team1 == team {
                if game.goals1 > game.goals2 { wins += 1 }
                else if game.goals1 == game.goals2 { ties += 1 }
                else { losses += 1 }
            } else if game.team2 == team {
                if game.goals2 > game.goals1 { wins += 1 }
                else if game.goals2 == game.goals1 { ties += 1 }
                else { losses += 1 }
            }
        }

        let total = wins + ties + losses
        if total == 0 { return "No games yet" }
        return "\(wins)W \(ties)T \(losses)L"
    }
}
// MARK: - 🏆 Bracket Views

/// One column in the bracket (one round's worth of matches)
struct BracketColumn: View {
    var pool: PoolData
    let round: BracketRound
    let matchCount: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(round.rawValue)
                .font(.subheadline.bold())
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            ForEach(1...matchCount, id: \.self) { num in
                BracketMatchCard(
                    pool: pool,
                    slot: BracketSlot(round: round, matchNumber: num)
                )
            }
        }
        .frame(width: 200)
    }
}

/// One match card in the bracket — tap to edit
struct BracketMatchCard: View {
    var pool: PoolData
    let slot: BracketSlot
    @State private var showingEdit = false

    private var team1: String? { pool.bracketTeam(slot: slot, position: 1) }
    private var team2: String? { pool.bracketTeam(slot: slot, position: 2) }
    private var game: GameResult? { pool.bracketGame(for: slot) }

    private var isTeam1Winner: Bool {
        guard let g = game else { return false }
        return g.goals1 > g.goals2
    }

    private var isTeam2Winner: Bool {
        guard let g = game else { return false }
        return g.goals2 > g.goals1
    }

    var body: some View {
        Button { showingEdit = true } label: {
            VStack(spacing: 0) {
                teamRow(name: team1, goals: game?.goals1, isWinner: isTeam1Winner)
                Divider()
                teamRow(name: team2, goals: game?.goals2, isWinner: isTeam2Winner)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(game != nil ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEdit) {
            EditBracketGameSheet(pool: pool, slot: slot)
        }
    }

    private func teamRow(name: String?, goals: Int?, isWinner: Bool) -> some View {
        HStack {
            if let name {
                Text("\(flag(for: name)) \(name)")
                    .font(.caption)
                    .fontWeight(isWinner ? .bold : .regular)
                    .lineLimit(1)
            } else {
                Text("TBD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let g = goals, team1 != nil, team2 != nil {
                Text("\(g)")
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(isWinner ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isWinner ? Color.green.opacity(0.1) : .clear)
    }
}

/// Sheet for editing a bracket match — pick teams (R32) or enter score (later rounds)
struct EditBracketGameSheet: View {
    var pool: PoolData
    let slot: BracketSlot
    @Environment(\.dismiss) private var dismiss

    @State private var team1 = ""
    @State private var team2 = ""
    @State private var goals1 = 0
    @State private var goals2 = 0
    @State private var matchDate = Date()
    @State private var includeDate = false
    @State private var selectedVenue = ""

    private var isR32: Bool { slot.round == .r32 }

    var body: some View {
        NavigationStack {
            Form {
                // Teams section
                Section(slot.round.rawValue + " — Match \(slot.matchNumber)") {
                    if isR32 {
                        // R32: pick teams from the country list
                        Picker("Team 1", selection: $team1) {
                            Text("Choose…").tag("")
                            ForEach(pool.availableForBracket(slot: slot, excluding: team2), id: \.self) { c in
                                Text("\(flag(for: c)) \(c)").tag(c)
                            }
                        }
                        Picker("Team 2", selection: $team2) {
                            Text("Choose…").tag("")
                            ForEach(pool.availableForBracket(slot: slot, excluding: team1), id: \.self) { c in
                                Text("\(flag(for: c)) \(c)").tag(c)
                            }
                        }
                    } else {
                        // Later rounds: teams are auto-determined
                        HStack {
                            Text("Team 1")
                            Spacer()
                            if team1.isEmpty {
                                Text("TBD").foregroundStyle(.secondary)
                            } else {
                                Text("\(flag(for: team1)) \(team1)")
                            }
                        }
                        HStack {
                            Text("Team 2")
                            Spacer()
                            if team2.isEmpty {
                                Text("TBD").foregroundStyle(.secondary)
                            } else {
                                Text("\(flag(for: team2)) \(team2)")
                            }
                        }
                    }
                }

                // Score — only show when both teams are known
                if !team1.isEmpty && !team2.isEmpty {
                    Section("Score") {
                        Stepper(
                            "\(flag(for: team1)) \(team1): \(goals1)",
                            value: $goals1, in: 0...20
                        )
                        Stepper(
                            "\(flag(for: team2)) \(team2): \(goals2)",
                            value: $goals2, in: 0...20
                        )
                    }

                    Section("Date & Location") {
                        Toggle("Include Date", isOn: $includeDate)
                        if includeDate {
                            DatePicker(
                                "Match Date",
                                selection: $matchDate,
                                displayedComponents: .date
                            )
                        }
                        Picker("Venue", selection: $selectedVenue) {
                            Text("None").tag("")
                            ForEach(worldCupVenues, id: \.self) { venue in
                                Text(venue.displayName).tag(venue.displayName)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveGame)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var canSave: Bool {
        !team1.isEmpty && !team2.isEmpty && team1 != team2
    }

    private func loadExisting() {
        // If editing an existing game, pre-fill everything
        if let existing = pool.bracketGame(for: slot) {
            team1 = existing.team1
            team2 = existing.team2
            goals1 = existing.goals1
            goals2 = existing.goals2
            if let d = existing.date {
                matchDate = d
                includeDate = true
            }
            selectedVenue = existing.location ?? ""
        } else if !isR32 {
            // Auto-fill teams from previous round winners
            team1 = pool.bracketTeam(slot: slot, position: 1) ?? ""
            team2 = pool.bracketTeam(slot: slot, position: 2) ?? ""
        }
    }

    private func saveGame() {
        pool.saveBracketGame(
            slot: slot,
            team1: team1,
            team2: team2,
            goals1: goals1,
            goals2: goals2,
            date: includeDate ? matchDate : nil,
            location: selectedVenue.isEmpty ? nil : selectedVenue
        )
        dismiss()
    }
}
