import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RecordViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera Preview
                CameraPreviewView(previewLayer: viewModel.previewLayer)
                    .ignoresSafeArea()

                // Overlay controls
                VStack {
                    Spacer()

                    // Recording indicator
                    if viewModel.isRecording {
                        RecordingIndicator(duration: viewModel.recordingDuration)
                            .padding(.bottom, 20)
                    }

                    // Record button
                    RecordButton(
                        isRecording: viewModel.isRecording,
                        isProcessing: viewModel.isProcessing
                    ) {
                        Task {
                            await viewModel.toggleRecording(modelContext: modelContext)
                        }
                    }
                    .padding(.bottom, 40)
                }

                // Error overlay
                if let error = viewModel.error {
                    ErrorOverlay(message: error) {
                        viewModel.dismissError()
                    }
                }

                // Processing overlay
                if viewModel.isProcessing {
                    ProcessingOverlay(message: "正在保存...")
                }
            }
            .navigationTitle("录制")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.setup()
            }
            .navigationDestination(item: $viewModel.savedVideo) { video in
                ChatView(video: video)
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: CALayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
            if previewLayer.superlayer == nil {
                uiView.layer.addSublayer(previewLayer)
            }
        }
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                if isRecording {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                }
            }
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.5 : 1)
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    let duration: TimeInterval
    @State private var isBlinking = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .opacity(isBlinking ? 1 : 0.3)

            Text(formattedDuration)
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                isBlinking = true
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Error Overlay

struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)

            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button("确定") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(32)
    }
}

// MARK: - Processing Overlay

struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text(message)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    RecordView()
        .modelContainer(for: [Video.self, Conversation.self, Message.self], inMemory: true)
}
