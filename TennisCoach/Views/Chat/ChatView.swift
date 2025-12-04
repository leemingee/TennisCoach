import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    let video: Video

    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: ChatViewModel(video: video))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Video preview header
            VideoPreviewHeader(video: video)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Streaming response
                        if !viewModel.streamingText.isEmpty {
                            StreamingMessageBubble(text: viewModel.streamingText)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("输入问题...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .lineLimit(1...5)

                Button {
                    Task {
                        await viewModel.sendMessage(modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.canSend ? .blue : .gray)
                }
                .disabled(!viewModel.canSend)
            }
            .padding()
        }
        .navigationTitle("AI 分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadConversation(modelContext: modelContext)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if !viewModel.streamingText.isEmpty {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.75
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Streaming Message Bubble

struct StreamingMessageBubble: View {
    let text: String
    @State private var cursorVisible = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(text)
                    if cursorVisible {
                        Text("|")
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.75
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                cursorVisible.toggle()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(video: Video(localPath: "test.mp4", duration: 60))
    }
    .modelContainer(for: [Video.self, Conversation.self, Message.self], inMemory: true)
}
