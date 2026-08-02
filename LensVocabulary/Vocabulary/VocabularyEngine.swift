import Foundation
import NaturalLanguage

struct VocabularyEngine {
    private let definitions: [String: String] = [
        "abrupt": "sudden and unexpected; 突然的",
        "ambiguous": "having more than one possible meaning; 模棱两可的",
        "approximate": "close to the exact value; 近似的",
        "assume": "to accept something as true for reasoning; 假设",
        "constraint": "a rule or limit; 约束",
        "derive": "to obtain from reasoning or calculation; 推导",
        "distort": "to twist out of shape or meaning; 扭曲",
        "equivalent": "equal in value or meaning; 等价的",
        "evidence": "facts that support a belief; 证据",
        "explicit": "clear and directly stated; 明确的",
        "implicit": "suggested but not directly stated; 隐含的",
        "infer": "to conclude from evidence; 推断",
        "interpret": "to explain the meaning of something; 解释",
        "justify": "to show a good reason for something; 证明合理",
        "linear": "following a straight-line relationship; 线性的",
        "notion": "an idea or concept; 概念",
        "precise": "exact and careful; 精确的",
        "reluctant": "unwilling or hesitant; 不情愿的",
        "significant": "important or large enough to matter; 显著的",
        "subtle": "not obvious; 微妙的",
        "sufficient": "enough for a purpose; 充分的",
        "variable": "a quantity that can change; 变量",
        "verify": "to check that something is true; 验证"
    ]

    private let commonWords: Set<String> = [
        "the", "and", "you", "that", "was", "for", "are", "with", "his", "they",
        "this", "have", "from", "one", "had", "word", "but", "not", "what", "all",
        "were", "when", "your", "can", "said", "there", "use", "each", "which",
        "she", "how", "their", "will", "other", "about", "out", "many", "then",
        "them", "these", "would", "write", "like", "time", "could", "make", "than",
        "first", "been", "call", "who", "its", "now", "find", "long", "down", "day"
    ]

    func bestHint(in text: String, existingCards: [VocabularyCard]) -> VocabularyHint? {
        let normalizedContext = text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedContext.count >= 8 else { return nil }

        let saved = Set(existingCards.map { $0.word.lowercased() })
        let words = extractWords(from: normalizedContext)

        let candidates = words.compactMap { original -> VocabularyHint? in
            let word = lemma(for: original).lowercased()
            guard word.count >= 5, commonWords.contains(word) == false, saved.contains(word) == false else {
                return nil
            }

            let definition = definitions[word] ?? fallbackDefinition(for: word)
            let score = candidateScore(word: word, isKnownTerm: definitions[word] != nil)
            return VocabularyHint(word: word, definition: definition, context: normalizedContext, score: score)
        }

        return candidates.sorted { $0.score > $1.score }.first
    }

    private func extractWords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var words: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            guard tag == .noun || tag == .verb || tag == .adjective || tag == .adverb else {
                return true
            }

            let token = String(text[range])
                .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

            if token.range(of: #"^[A-Za-z][A-Za-z'-]+$"#, options: .regularExpression) != nil {
                words.append(token)
            }

            return true
        }

        return words
    }

    private func lemma(for word: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word
        let range = word.startIndex..<word.endIndex
        return tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0?.rawValue ?? String(word[range])
    }

    private func candidateScore(word: String, isKnownTerm: Bool) -> Int {
        var score = word.count
        if isKnownTerm { score += 10 }
        if word.count >= 9 { score += 4 }
        if word.contains("-") { score += 2 }
        return score
    }

    private func fallbackDefinition(for word: String) -> String {
        "Look up \"\(word)\" later. 暂未内置释义，已记录语境。"
    }
}
