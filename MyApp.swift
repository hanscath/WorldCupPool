import SwiftUI
import UniformTypeIdentifiers

// =============================================
// 🎮 CONTENT VIEW — This is YOUR file to build!
// Type this code yourself in Swift Playgrounds.
// =============================================

// MARK: - 🚀 App Entry Point

@main
struct WorldCupPoolApp: App {
    @State private var pool = PoolData()

    var body: some Scene {
        WindowGroup {
            ContentView(pool: pool)
        }
    }
}
