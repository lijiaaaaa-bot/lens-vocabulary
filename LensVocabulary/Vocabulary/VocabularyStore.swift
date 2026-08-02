import Foundation

final class VocabularyStore: ObservableObject {
    @Published private(set) var cards: [VocabularyCard] = []

    private let storageKey = "lens-vocabulary.cards"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func save(_ hint: VocabularyHint) {
        guard cards.contains(where: { $0.word.caseInsensitiveCompare(hint.word) == .orderedSame }) == false else {
            return
        }

        let card = VocabularyCard(word: hint.word, definition: hint.definition, context: hint.context)
        cards.insert(card, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        cards.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([VocabularyCard].self, from: data) else {
            return
        }

        cards = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
