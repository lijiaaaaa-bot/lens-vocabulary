import Foundation

struct VocabularyCard: Identifiable, Codable, Equatable {
    let id: UUID
    let word: String
    let definition: String
    let context: String
    let createdAt: Date

    init(id: UUID = UUID(), word: String, definition: String, context: String, createdAt: Date = Date()) {
        self.id = id
        self.word = word
        self.definition = definition
        self.context = context
        self.createdAt = createdAt
    }
}
