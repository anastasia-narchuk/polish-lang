import Foundation

/// Result of a batch translation: rows in input order, plus the error that stopped the batch, if any.
struct EnrichOutcome: Sendable {
    var results: [EnrichResult?]
    var failure: AIError?
}

/// The app's AI operations: prompt, schema, effort and parsing for each of them.
struct PolishAI: Sendable {
    /// Rows per translation request (TZ 1, section 2.2).
    static let enrichBatchSize = 40
    /// Photos per recognition request (TZ 1, section 2.3).
    static let maxPhotos = 3

    var client: any AIBackend = AnthropicClient()
    var config: AIConfiguration

    /// TZ 1, 4.1, in batches of 40. A failed batch leaves its rows empty and stops the rest.
    func enrich(_ inputs: [EnrichInput]) async -> EnrichOutcome {
        var results: [EnrichResult?] = []
        var failure: AIError?
        var start = 0
        while start < inputs.count {
            let batch = Array(inputs[start..<min(start + Self.enrichBatchSize, inputs.count)])
            start += batch.count
            if failure == nil {
                do {
                    let response = try await client.send(
                        AIRequest(prompt: Prompts.enrich(batch), maxTokens: 16_000, effort: .low, schema: Schemas.enrich),
                        config: config
                    )
                    results += try ResponseParser.enrichResults(from: response.text, count: batch.count)
                    continue
                } catch let error as AIError {
                    failure = error
                } catch {
                    failure = .network(error.localizedDescription)
                }
            }
            results += Array(repeating: nil, count: batch.count)
        }
        return EnrichOutcome(results: results, failure: failure)
    }

    /// TZ 1, 4.2.
    func recognize(images: [AIImage], mode: PhotoMode) async throws -> [PhotoItem] {
        let response = try await client.send(
            AIRequest(
                prompt: Prompts.photo(mode: mode),
                images: Array(images.prefix(Self.maxPhotos)),
                maxTokens: 16_000,
                effort: .medium,
                schema: Schemas.photo
            ),
            config: config
        )
        return try ResponseParser.photoItems(from: response.text)
    }

    /// TZ 2, 4.1.
    func generate(topic: String, kind: TextKind, level: CEFRLevel, myWords: [String]) async throws -> GeneratedText {
        let response = try await client.send(
            AIRequest(
                prompt: Prompts.generate(topic: topic, kind: kind, level: level, myWords: myWords),
                maxTokens: 16_000,
                effort: .medium,
                schema: Schemas.generatedText
            ),
            config: config
        )
        return try ResponseParser.generatedText(from: response.text)
    }

    /// TZ 3, 7.1 (or "Свой текст"): a task from a prepared prompt.
    func writingTask(prompt: String) async throws -> WritingTask {
        let response = try await client.send(
            AIRequest(prompt: prompt, maxTokens: 16_000, effort: .medium, schema: WritingPrompts.taskSchema),
            config: config
        )
        return try WritingParser.task(from: response.text)
    }

    /// TZ 3, 7.2: the handwritten text word for word, as plain text.
    func transcribe(images: [AIImage]) async throws -> String {
        let response = try await client.send(
            AIRequest(prompt: WritingPrompts.transcribe, images: Array(images.prefix(Self.maxPhotos)), maxTokens: 16_000, effort: .medium),
            config: config
        )
        let text = response.text.trimmed
        guard !text.isEmpty else { throw AIError.invalidResponse }
        return text
    }

    /// TZ 3, 7.4: the full check of a text.
    func checkText(task: WritingTask, text: String) async throws -> TextCheck {
        let response = try await client.send(
            AIRequest(prompt: WritingPrompts.check(task: task, text: text), maxTokens: 24_000, effort: .medium, schema: WritingPrompts.checkSchema),
            config: config
        )
        return try WritingParser.check(from: response.text)
    }

    /// TZ 2, 4.2.
    func translate(selection: String, sentence: String, title: String) async throws -> WordTranslation {
        let response = try await client.send(
            AIRequest(
                prompt: Prompts.translate(selection: selection, sentence: sentence, title: title),
                maxTokens: 4_000,
                effort: .low,
                schema: Schemas.translation
            ),
            config: config
        )
        return try ResponseParser.translation(from: response.text)
    }
}
