import SwiftUI
import AVKit
import Photos

/// A reusable video player component with playback controls
struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showFullScreen = false
    @State private var isSavingToPhotos = false
    @State private var saveError: String?
    @State private var showSaveSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Video player
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            showFullScreen = true
                        }
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }

                // Fullscreen button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showFullScreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            }

            // Action buttons
            HStack(spacing: 20) {
                // Play/Pause button
                Button {
                    togglePlayPause()
                } label: {
                    HStack {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        Text(isPlaying ? "暂停" : "播放")
                    }
                }
                .buttonStyle(.bordered)

                // Save to Photos button
                Button {
                    Task {
                        await saveToPhotosLibrary()
                    }
                } label: {
                    HStack {
                        if isSavingToPhotos {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("保存到相册")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSavingToPhotos)
            }
            .padding(.top, 12)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenVideoPlayer(videoURL: videoURL, isPresented: $showFullScreen)
        }
        .alert("保存失败", isPresented: .constant(saveError != nil)) {
            Button("确定") {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("确定") {}
        } message: {
            Text("视频已保存到相册")
        }
    }

    private func setupPlayer() {
        player = AVPlayer(url: videoURL)
    }

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            // If at the end, restart from beginning
            if let duration = player.currentItem?.duration,
               let currentTime = player.currentItem?.currentTime(),
               CMTimeCompare(currentTime, duration) >= 0 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    private func saveToPhotosLibrary() async {
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        do {
            // Request authorization
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saveError = "请在设置中允许访问相册"
                return
            }

            // Save video to Photos Library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(
                    with: .video,
                    fileURL: videoURL,
                    options: nil
                )
            }

            showSaveSuccess = true
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Full Screen Video Player

struct FullScreenVideoPlayer: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            // Close button
            VStack {
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()

                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}

// MARK: - Video Preview Header (Compact version for ChatView)

struct VideoPreviewHeader: View {
    let video: Video
    @State private var showPlayer = false

    var body: some View {
        Button {
            showPlayer = true
        } label: {
            ZStack {
                // Thumbnail or placeholder
                if let thumbnailData = video.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 180)
                        .overlay {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                }

                // Play button overlay
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }

                // Duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(video.formattedDuration)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(8)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPlayer) {
            if let url = video.localURL {
                NavigationStack {
                    VideoPlayerView(videoURL: url)
                        .padding()
                        .navigationTitle("视频播放")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完成") {
                                    showPlayer = false
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview("Video Player") {
    VideoPlayerView(videoURL: URL(fileURLWithPath: "/test.mp4"))
        .padding()
}

#Preview("Video Preview Header") {
    VideoPreviewHeader(video: Video(localPath: "/test.mp4", duration: 90))
        .padding()
}
