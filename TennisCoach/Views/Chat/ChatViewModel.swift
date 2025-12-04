import SwiftUI
import SwiftData
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var streamingText = ""
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    // MARK: - Properties

    private let video: Video
    private var conversation: Conversation?
    private let geminiService: GeminiServicing

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Initialization

    init(video: Video, geminiService: GeminiServicing = GeminiService()) {
        self.video = video
        self.geminiService = geminiService
    }

    // MARK: - Load Conversation

    func loadConversation(modelContext: ModelContext) async {
        // Check if video already has a conversation
        if let existingConversation = video.conversations.first {
            self.conversation = existingConversation
            self.messages = existingConversation.sortedMessages
            return
        }

        // Create new conversation and start analysis
        let newConversation = Conversation(video: video, title: "Analysis \(Date().formatted())")
        modelContext.insert(newConversation)
        video.conversations.append(newConversation)
        self.conversation = newConversation

        // Start initial analysis
        await startInitialAnalysis(modelContext: modelContext)
    }

    // MARK: - Initial Analysis

    private func startInitialAnalysis(modelContext: ModelContext) async {
        isLoading = true
        streamingText = ""

        do {
            // Upload video if not already uploaded
            let fileUri: String
            if let existingUri = video.geminiFileUri {
                fileUri = existingUri
            } else {
                guard let localURL = video.localURL else {
                    throw GeminiError.uploadFailed("Invalid video path")
                }
                fileUri = try await geminiService.uploadVideo(localURL: localURL)
                video.geminiFileUri = fileUri
            }

            // Add user message for initial analysis
            let userMessage = Message(
                conversation: conversation,
                role: .user,
                content: "请分析这段网球视频"
            )
            modelContext.insert(userMessage)
            messages.append(userMessage)

            // Stream the analysis
            let stream = try await geminiService.analyzeVideo(
                fileUri: fileUri,
                prompt: Prompts.initialAnalysis
            )

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                streamingText = fullResponse
            }

            // Save assistant message
            let assistantMessage = Message(
                conversation: conversation,
                role: .assistant,
                content: fullResponse
            )
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)

            streamingText = ""
            isLoading = false

        } catch {
            isLoading = false
            streamingText = ""
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Send Message

    func sendMessage(modelContext: ModelContext) async {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        inputText = ""
        isLoading = true
        streamingText = ""

        // Add user message
        let userMessage = Message(
            conversation: conversation,
            role: .user,
            content: userText
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)

        do {
            guard let fileUri = video.geminiFileUri else {
                throw GeminiError.uploadFailed("Video not uploaded")
            }

            // Get conversation history (excluding the message we just added)
            let history = messages.dropLast()

            let stream = try await geminiService.chat(
                fileUri: fileUri,
                history: Array(history),
                userMessage: userText
            )

            var fullResponse = ""
            for try await chunk in stream {
                fullResponse += chunk
                streamingText = fullResponse
            }

            // Save assistant message
            let assistantMessage = Message(
                conversation: conversation,
                role: .assistant,
                content: fullResponse
            )
            modelContext.insert(assistantMessage)
            messages.append(assistantMessage)

            streamingText = ""
            isLoading = false

        } catch {
            isLoading = false
            streamingText = ""
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
