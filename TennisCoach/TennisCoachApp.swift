import SwiftUI
import SwiftData

@main
struct TennisCoachApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Video.self,
            Conversation.self,
            Message.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the error for debugging
            print("Failed to create persistent ModelContainer: \(error)")

            // Fallback to in-memory storage to prevent crashes
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                // This should rarely happen, but provides a clear error
                preconditionFailure("Failed to create fallback ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
