import Foundation
import SwiftUI

/// SwiftUI view whose API mirrors `AsyncImage` but routes loading, decoding,
/// and caching through `ImageGradientAndStoreBloc`.
///
/// Identify the image by the same `(id, size)` pair the bloc consumes
/// (`id` is the path handed to `MediaConfig.logoURL`). The trailing closure
/// receives a standard `AsyncImagePhase` so existing call sites that already
/// switch on `.empty` / `.success` / `.failure` can drop this in unchanged.
struct BlocAsyncImage<Content: View>: View {
    private let id: String
    private let size: String
    private var content: (AsyncImagePhase) -> Content
    private let setGradientFromImage: Bool

    @State private var phase: AsyncImagePhase = .empty

    /// Phase-based initializer — the analog of
    /// `AsyncImage(url:scale:transaction:content:)`.
    init(
        id: String,
        size: String,
        setGradientFromImage: Bool = false,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.id = id
        self.size = size
        self.setGradientFromImage = setGradientFromImage
        self.content = content
    }

    /// Convenience initializer that mirrors
    /// `AsyncImage(url:scale:content:placeholder:)`. The placeholder is shown
    /// both while loading and on failure, matching `AsyncImage`.
    init<I: View, P: View>(
        id: String,
        size: String,
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(id: id, size: size) { phase in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }

    var body: some View {
        content(phase)
            .task(id: taskKey) {
                await load()
            }
    }

    private var taskKey: String {
        "\(id)|\(size)"
    }

    @MainActor
    private func load() async {
        guard !id.isEmpty else {
            phase = .failure(BlocAsyncImageError(message: "Empty image id"))
            return
        }

        phase = .empty

        do {
            try await ImageGradientAndStoreBloc.bloc.fetchAndStoreImage(
                id: id,
                size: size
            ) { update in
                switch update {
                case .loading:
                    phase = .empty
                case let .loaded(cgImage):
                    if setGradientFromImage {
                        ImageGradientAndStoreBloc.bloc.setGradientFromImage(from: cgImage, id: id)
                    }

                    phase = .success(
                        Image(decorative: cgImage, scale: 1, orientation: .up)
                    )
                case let .error(message):
                    phase = .failure(BlocAsyncImageError(message: message))
                }
            }
        } catch {
            phase = .failure(error)
        }
    }
}

private struct BlocAsyncImageError: LocalizedError {
    let message: String
    var errorDescription: String? {
        message
    }
}
