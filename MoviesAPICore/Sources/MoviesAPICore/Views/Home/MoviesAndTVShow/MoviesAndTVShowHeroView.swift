//
//  MoviesAndTVShowHeroView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/5/26.
//

import SwiftUI

struct MoviesAndTVShowHeroView<Media: MediaListItem>: View {

    @Environment(TMDBManager.self) var tmdbManager
    let contents: [Media]

    @State private var activeIndex: Int = 0
    @Namespace private var nm

    private let maxDots = 6

    private var visibleRange: Range<Int> {
        let count = contents.count
        guard count > maxDots else { return 0..<count }
        let start = min(max(activeIndex - maxDots / 2, 0), count - maxDots)
        return start..<(start + maxDots)
    }

    var displayName: String {
        if contents.isEmpty { return "" }
        return contents[activeIndex].displayName
    }

    var displayType: String {
        if contents.isEmpty { return "" }
        return contents[activeIndex].mediaType == .tv ? "TV Show" : "Movie"
    }

    var genres: String {
        if contents.isEmpty { return "" }
        return contents[activeIndex].genresTypes.map( { $0 }).joined(separator: " · ")
    }

    var description: String {
        if contents.isEmpty { return "" }
        return displayType + " · " + genres
    }

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingMedia: Media?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false
    @State private var selectedIndex: Int?

    var body: some View {
        ZStack {
            CarouselView(selectedIndex: $selectedIndex) {
                ForEach(contents, id: \.id) { result in
                    if let path = result.heroPosterPath,
                       let url = URL(string: "https://image.tmdb.org/t/p/original\(path)") {
                        AsyncImage(url: url) { image in
                            GeometryReader { geometry in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(
                                        width: geometry.size.width,
                                        height: geometry.size.height,
                                        alignment: .center
                                    )
                                    .clipped()
                            }
                            .overlay {
                                if resolvingMedia?.id == result.id && resolvingMedia?.mediaType == result.mediaType {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(.black.opacity(0.1))
                                }
                            }
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    } else if let path = result.backdropPath,
                              let url = URL(string: "https://image.tmdb.org/t/p/original\(path)") {
                        AsyncImage(url: url) { image in
                            GeometryReader { geometry in
                                ZStack {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .blur(radius: 35)
                                        .overlay(Color.black.opacity(0.3))

                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width)
                                        .mask {
                                            LinearGradient(
                                                stops: [
                                                    .init(color: .clear, location: 0),
                                                    .init(color: .black, location: 0.15),
                                                    .init(color: .black, location: 0.85),
                                                    .init(color: .clear, location: 1)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        }
                                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                            }
                            .overlay {
                                if resolvingMedia?.id == result.id && resolvingMedia?.mediaType == result.mediaType {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(.black.opacity(0.1))
                                }
                            }
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    }
                }
            } scrollProgress: { progress in
                guard !contents.isEmpty, progress.isFinite else { return }
                let newIndex = min(max(Int(progress.rounded()), 0), contents.count - 1)
                guard newIndex != activeIndex else { return }
                activeIndex = newIndex
            }
            .frame(height: 700)
            .visualEffect { content, proxy in
                let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                let stretch = max(minY, 0)

                return content
                    .scaleEffect(
                        x: 1 + stretch / proxy.size.width,
                        y: 1 + stretch / proxy.size.height,
                        anchor: .top
                    )
                    .offset(y: -stretch)
            }
            .overlay(alignment: .bottom) {
                ZStack {
                    // blur that ramps in toward the bottom
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // fade into the page background
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.5), location: 0.5),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: 350)
                .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                VStack {
                    Text(displayName.uppercased())
                        .font(.system(size: 44, weight: .heavy))
                        .fontWidth(.condensed)
                        .tracking(6)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Button {
                        if contents.indices.contains(activeIndex) {
                            let media = contents[activeIndex]
                            resolve(media)
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .foregroundStyle(.black)
                            .padding(12)
                            .padding(.horizontal, 32)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    HStack(spacing: 6) {
                        ForEach(Array(visibleRange), id: \.self) { index in

                            let isFirstVisible = index == visibleRange.lowerBound
                            let isLastVisible  = index == visibleRange.upperBound - 1
                            let showSmall = (isFirstVisible || isLastVisible) && index != activeIndex

                            Capsule()
                                .fill(.gray.opacity(0.8))
                                .frame(
                                    width: activeIndex == index ? 20 : (showSmall ? 8 : 10),
                                    height: activeIndex == index ? 10 : (showSmall ? 8 : 10)
                                )
                                .overlay(alignment: .leading) {
                                    if activeIndex == index {
                                        TimelineView(.animation) { timeline in
                                            let elapsed = timeline.date.timeIntervalSince(heroStartDate)
                                            let progress = min(max(elapsed / heroDuration, 0), 1)

                                            Capsule()
                                                .fill(.white)
                                                .frame(width: 10 + (progress * 10), height: 10)
                                        }
                                    }
                                }
                                .clipShape(Capsule())
                                .animation(.smooth(duration: 0.35), value: activeIndex)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .allowsTightening(false)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
        .onDisappear {
            nextHeroTask?.cancel()
        }
        .onChange(of: selectedIndex) { _, newValue in
            nextHeroView()
        }
        .onChange(of: contents) { _, newValue in
            guard !contents.isEmpty else { return }
            selectedIndex = 0
        }
    }

    @State private var nextHeroTask: Task<Void, Never>?
    @State private var heroStartDate = Date()
    @State private var heroDuration: TimeInterval = 10

    private func nextHeroView() {
        nextHeroTask?.cancel()

        heroStartDate = .now

        nextHeroTask = Task {
            try? await Task.sleep(for: .seconds(10))

            guard !Task.isCancelled,
                  let selectedIndex,
                  !contents.isEmpty else { return }

            withAnimation(.spring) {
                self.selectedIndex = (selectedIndex + 1) % contents.count
            }
        }
    }

    private func resolve(_ result: Media) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingMedia = result
            isResolving = true
            defer {
                isResolving = false
                resolvingMedia = nil
            }

            do {
                try await tmdbManager.search(result.displayName)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == result.id }) {
                        self.searchResult = result
                        self.goToDetail = true
                    }
                    /// Clear once we finish
                    tmdbManager.clearSearchResults()
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
