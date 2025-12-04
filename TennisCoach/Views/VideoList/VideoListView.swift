import SwiftUI
import SwiftData

struct VideoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Video.createdAt, order: .reverse) private var videos: [Video]

    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    EmptyVideoListView()
                } else {
                    List {
                        ForEach(videos) { video in
                            NavigationLink(value: video) {
                                VideoRowView(video: video)
                            }
                        }
                        .onDelete(perform: deleteVideos)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("我的视频")
            .navigationDestination(for: Video.self) { video in
                ChatView(video: video)
            }
        }
    }

    private func deleteVideos(at offsets: IndexSet) {
        for index in offsets {
            let video = videos[index]

            // Delete local file
            if let url = video.localURL {
                try? FileManager.default.removeItem(at: url)
            }

            modelContext.delete(video)
        }
    }
}

// MARK: - Video Row

struct VideoRowView: View {
    let video: Video

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailData = video.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 60)
                    .overlay {
                        Image(systemName: "video.fill")
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(video.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(video.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if video.geminiFileUri != nil {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("已分析")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyVideoListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("还没有录制视频")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("点击下方「录制」开始录制你的网球视频")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    VideoListView()
        .modelContainer(for: [Video.self, Conversation.self, Message.self], inMemory: true)
}
