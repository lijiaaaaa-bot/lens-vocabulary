import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var store = VocabularyStore()
    @State private var focusWindow = FocusWindow()
    @State private var selectedHint: VocabularyHint?
    @State private var selectedTab = 0

    private let engine = VocabularyEngine()

    var body: some View {
        TabView(selection: $selectedTab) {
            ReaderView(
                camera: camera,
                store: store,
                focusWindow: $focusWindow,
                selectedHint: $selectedHint,
                engine: engine
            )
            .tabItem {
                Label("Lens", systemImage: "camera.viewfinder")
            }
            .tag(0)

            CardsView(store: store)
                .tabItem {
                    Label("Cards", systemImage: "rectangle.stack")
                }
                .tag(1)
        }
        .tint(.mint)
    }
}

struct ReaderView: View {
    @ObservedObject var camera: CameraManager
    @ObservedObject var store: VocabularyStore
    @Binding var focusWindow: FocusWindow
    @Binding var selectedHint: VocabularyHint?

    let engine: VocabularyEngine

    var body: some View {
        ZStack {
            CameraSurface(camera: camera, focusWindow: $focusWindow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                StatusBar(camera: camera)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer()

                HintPanel(
                    hint: selectedHint,
                    recognizedText: camera.stableText,
                    saveAction: saveHint
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .background(Color.black)
        .task {
            camera.checkAuthorization()
            if camera.authorizationState == .authorized {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: focusWindow) { newValue in
            camera.updateFocusWindow(newValue)
        }
        .onChange(of: camera.stableText) { text in
            selectedHint = engine.bestHint(in: text, existingCards: store.cards)
        }
    }

    private func saveHint() {
        guard let selectedHint else { return }
        store.save(selectedHint)
    }
}

struct CameraSurface: View {
    @ObservedObject var camera: CameraManager
    @Binding var focusWindow: FocusWindow

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch camera.authorizationState {
                case .authorized:
                    CameraPreview(session: camera.session)
                case .unknown:
                    PermissionView(action: camera.requestAccess)
                case .denied:
                    UnavailableView(
                        title: "Camera access is off",
                        message: "Enable camera permission in Settings to read text from another screen."
                    )
                case .unavailable:
                    UnavailableView(
                        title: "Camera unavailable",
                        message: "Use a physical iPhone or iPad with a working camera."
                    )
                }

                dimmedOverlay(in: proxy.size)
                FocusWindowView(focusWindow: $focusWindow, size: proxy.size)
            }
        }
    }

    private func dimmedOverlay(in size: CGSize) -> some View {
        let rect = CGRect(
            x: focusWindow.x * size.width,
            y: focusWindow.y * size.height,
            width: focusWindow.width * size.width,
            height: focusWindow.height * size.height
        )

        return Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: 10, height: 10))
        }
        .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}

struct FocusWindowView: View {
    @Binding var focusWindow: FocusWindow
    let size: CGSize

    @State private var dragStart = FocusWindow()
    @State private var resizeStart = FocusWindow()

    var body: some View {
        let rect = CGRect(
            x: focusWindow.x * size.width,
            y: focusWindow.y * size.height,
            width: focusWindow.width * size.width,
            height: focusWindow.height * size.height
        )

        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.mint, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clear)
                )
                .overlay(alignment: .topLeading) {
                    Label("Text zone", systemImage: "text.viewfinder")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.62), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(8)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            var next = dragStart
                            next.move(by: value.translation, in: size)
                            focusWindow = next
                        }
                        .onEnded { _ in
                            dragStart = focusWindow
                        }
                )

            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(.mint, in: Circle())
                .padding(8)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            var next = resizeStart
                            next.resize(by: value.translation, in: size)
                            focusWindow = next
                        }
                        .onEnded { _ in
                            resizeStart = focusWindow
                        }
                )
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .onAppear {
            dragStart = focusWindow
            resizeStart = focusWindow
        }
    }
}

struct StatusBar: View {
    @ObservedObject var camera: CameraManager

    var body: some View {
        HStack(spacing: 10) {
            Label("On-device OCR", systemImage: "cpu")
            Spacer()
            Text("\(Int(camera.stats.lastLatencyMilliseconds)) ms")
                .monospacedDigit()
            Text("\(camera.stats.processedFrames) frames")
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct HintPanel: View {
    let hint: VocabularyHint?
    let recognizedText: String
    let saveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hint {
                HStack(alignment: .firstTextBaseline) {
                    Text(hint.word)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: saveAction) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .accessibilityLabel("Save card")
                }

                Text(hint.definition)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.86))

                Text(hint.context)
                    .font(.callout)
                    .lineLimit(3)
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                Label("Aim at subtitles or slides", systemImage: "viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(recognizedText.isEmpty ? "Drag the mint window over the text area." : recognizedText)
                    .font(.callout)
                    .lineLimit(3)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PermissionView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 48))
            Text("Use the camera as a learning lens")
                .font(.title2.weight(.bold))
            Button(action: action) {
                Label("Enable Camera", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct UnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42))
            Text(title)
                .font(.title2.weight(.bold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct CardsView: View {
    @ObservedObject var store: VocabularyStore

    var body: some View {
        NavigationStack {
            List {
                if store.cards.isEmpty {
                    ContentUnavailableView(
                        "No cards yet",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Save useful words while reading subtitles or slides.")
                    )
                } else {
                    ForEach(store.cards) { card in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.word)
                                .font(.headline)
                            Text(card.definition)
                                .foregroundStyle(.secondary)
                            Text(card.context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Review Cards")
        }
    }
}

#Preview {
    ContentView()
}
