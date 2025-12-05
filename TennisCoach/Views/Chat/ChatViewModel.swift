import SwiftUI
import SwiftData
import Combine

/// ViewModel for the AI chat interface.
///
/// ## Purpose
/// Manages the conversation between user and Gemini AI about a recorded tennis video.
/// Handles video upload, initial analysis, and follow-up Q&A.
///
/// ## Data Flow
/// 1. View appears → loadConversation() checks for existing conversation
/// 2. If new video → uploads to Gemini → runs initial analysis
/// 3. User sends message → chat() API → streaming response
/// 4. All messages persisted to SwiftData for history
///
/// ## Streaming UI
/// - `streamingText` holds partial AI response during streaming
/// - `messages` array contains completed messages
/// - UI shows streaming bubble with cursor animation during response
///
/// ## Threading
/// - @MainActor for all @Published property updates
/// - GeminiService handles its own threading internally
/// - AsyncThrowingStream consumed on MainActor via for-await
@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Completed messages in the conversation (user + assistant)
    @Published var messages: [Message] = []
    /// Current text in the input field
    @Published var inputText = ""
    /// Partial AI response during streaming (for real-time typing effect)
    @Published var streamingText = ""
    /// True when waiting for API response (shows spinner, disables input)
    @Published var isLoading = false
    /// Triggers error alert when true
    @Published var showError = false
    /// Error message to display in alert
    @Published var errorMessage = ""

    // MARK: - Properties

    private let video: Video
    private var conversation: Conversation?
    private let geminiService: GeminiServicing

    /// Current streaming task - stored for cancellation when view disappears
    private var currentStreamingTask: Task<Void, Never>?

    /// Determines if send button should be enabled
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Initialization

    /// Initialize with a video and optional custom service (for testing).
    init(video: Video, geminiService: GeminiServicing = GeminiService()) {
        self.video = video
        self.geminiService = geminiService
    }

    // MARK: - Cleanup

    /// Cancel any ongoing streaming task.
    /// Called when the view disappears to prevent memory leaks and wasted network.
    func cancelStreaming() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        if isLoading {
            isLoading = false
            streamingText = ""
        }
    }

    // MARK: - Load Conversation

    /// Load existing conversation or create new one and start analysis.
    ///
    /// Called when the ChatView appears. If the video already has a conversation
    /// (user opened this video before), we load the history. Otherwise, we create
    /// a new conversation and trigger the initial AI analysis.
    func loadConversation(modelContext: ModelContext) async {
        // Check if video already has a conversation (user viewed this video before)
        if let existingConversation = video.conversations.first {
            self.conversation = existingConversation
            self.messages = existingConversation.sortedMessages
            return
        }

        // First time viewing this video - create conversation and start analysis
        let newConversation = Conversation(video: video, title: "Analysis \(Date().formatted())")
        modelContext.insert(newConversation)
        video.conversations.append(newConversation)
        self.conversation = newConversation

        // Trigger automatic analysis (uploads video if needed, then gets AI response)
        await startInitialAnalysis(modelContext: modelContext)
    }

    // MARK: - Initial Analysis

    /// Upload video (if needed) and request initial tennis technique analysis.
    ///
    /// Flow:
    /// 1. Upload video to Gemini File API (or reuse existing fileUri)
    /// 2. Add user message "请分析这段网球视频" (Please analyze this tennis video)
    /// 3. Stream AI response and display in real-time
    /// 4. Save completed response to SwiftData
    ///
    /// Supports cancellation via Task.checkCancellation() and stores task for cleanup.
    ///
    /// - Note: Uses Prompts.initialAnalysis which contains detailed tennis analysis instructions
    private func startInitialAnalysis(modelContext: ModelContext) async {
        isLoading = true
        streamingText = ""

        // Store task reference for potential cancellation
        currentStreamingTask = Task {
            do {
                // Check for cancellation before starting expensive operations
                try Task.checkCancellation()

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

                try Task.checkCancellation()

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
                    // Check cancellation during streaming
                    try Task.checkCancellation()
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

            } catch is CancellationError {
                // Task was cancelled - clean up silently
                isLoading = false
                streamingText = ""
            } catch {
                isLoading = false
                streamingText = ""
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        // Wait for task to complete
        await currentStreamingTask?.value
        currentStreamingTask = nil
    }

    // MARK: - Send Message

    /// Send a follow-up message to continue the conversation.
    ///
    /// Uses the Gemini chat() API which includes:
    /// - The video context (fileUri)
    /// - Full conversation history for context
    /// - The new user message
    ///
    /// The response streams in real-time for a responsive UX.
    /// Supports cancellation via cancelStreaming() when user navigates away.
    func sendMessage(modelContext: ModelContext) async {
        let userText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        // Clear input immediately for responsive feel
        inputText = ""
        isLoading = true
        streamingText = ""

        // Add user message to UI immediately (optimistic update)
        let userMessage = Message(
            conversation: conversation,
            role: .user,
            content: userText
        )
        modelContext.insert(userMessage)
        messages.append(userMessage)

        // Store task reference for potential cancellation
        currentStreamingTask = Task {
            do {
                try Task.checkCancellation()

                guard let fileUri = video.geminiFileUri else {
                    throw GeminiError.uploadFailed("Video not uploaded")
                }

                // Pass conversation history (excluding the message we just added)
                // Gemini uses this to maintain context across the conversation
                let history = messages.dropLast()

                let stream = try await geminiService.chat(
                    fileUri: fileUri,
                    history: Array(history),
                    userMessage: userText
                )

                // Stream response for real-time typing effect
                var fullResponse = ""
                for try await chunk in stream {
                    // Check cancellation during streaming
                    try Task.checkCancellation()
                    fullResponse += chunk
                    streamingText = fullResponse  // Update UI with each chunk
                }

                // Save completed assistant message to SwiftData
                let assistantMessage = Message(
                    conversation: conversation,
                    role: .assistant,
                    content: fullResponse
                )
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                streamingText = ""
                isLoading = false

            } catch is CancellationError {
                // Task was cancelled - clean up silently
                isLoading = false
                streamingText = ""
            } catch {
                isLoading = false
                streamingText = ""
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        // Wait for task to complete
        await currentStreamingTask?.value
        currentStreamingTask = nil
    }
}
