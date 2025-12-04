import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAPIKeySetup = false

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordView()
                .tabItem {
                    Label("录制", systemImage: "video.fill")
                }
                .tag(0)

            VideoListView()
                .tabItem {
                    Label("视频", systemImage: "play.rectangle.fill")
                }
                .tag(1)

            SettingsView(showAPIKeySetup: $showAPIKeySetup)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .sheet(isPresented: $showAPIKeySetup) {
            APIKeySetupView()
        }
        .onAppear {
            // Show API key setup if not configured
            if !Constants.API.hasAPIKey {
                showAPIKeySetup = true
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var showAPIKeySetup: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("API Configuration") {
                    Button {
                        showAPIKeySetup = true
                    } label: {
                        HStack {
                            Label("Gemini API Key", systemImage: "key.fill")
                            Spacer()
                            if Constants.API.hasAPIKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Set")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "mailto:leemingee1995@gmail.com")!) {
                        HStack {
                            Label("Contact Developer", systemImage: "envelope.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Link(destination: URL(string: "https://github.com/leemingee/TennisCoach")!) {
                        HStack {
                            Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                Section {
                    Text("TennisCoach is open source. Contributions are welcome!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Video.self, Conversation.self, Message.self], inMemory: true)
}
