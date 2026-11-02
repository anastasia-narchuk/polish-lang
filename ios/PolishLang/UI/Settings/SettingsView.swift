import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum CheckState: Equatable {
        case idle, checking, ok
        case failed(String)
    }

    @Environment(AIService.self) private var ai
    @Environment(AppSettings.self) private var settings
    @Environment(CardStore.self) private var cards
    @Environment(ReadingStore.self) private var readings
    @Environment(MistakeStore.self) private var mistakes
    @Environment(WritingStore.self) private var writingTexts
    @Environment(TextErrorStore.self) private var textErrors
    @State private var keyDraft = ""
    @State private var check: CheckState = .idle
    @State private var deleteKeyArmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.section) {
                    apiGroup
                    readingGroup
                    cardsGroup
                    writingGroup
                    advancedGroup
                    dataGroup
                    ValueRow(title: "Версия", value: appVersion)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, Theme.Space.screen)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: Theme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Настройки")
        }
    }

    private var apiGroup: some View {
        @Bindable var settings = settings
        let provider = settings.provider
        return group("AI", footer: keyFooter(provider)) {
            SegmentedPills(items: AIProvider.allCases, title: { $0.title }, selection: $settings.provider)
                .padding(.vertical, 16)
            Hairline()
            if ai.hasKey(for: provider) {
                InfoRow(icon: "checkmark.seal.fill", title: "Ключ \(provider.title) сохранён", subtitle: "в Keychain этого устройства")
                Hairline()
                Button {
                    Task { await runCheck() }
                } label: {
                    HStack {
                        Text("Проверить подключение")
                            .font(.ui(.headline))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        checkIndicator
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(check == .checking)
                Hairline()
                Button(role: .destructive) {
                    if deleteKeyArmed {
                        ai.deleteKey(for: provider)
                        deleteKeyArmed = false
                        check = .idle
                    } else {
                        deleteKeyArmed = true
                    }
                } label: {
                    Text(deleteKeyArmed ? "Точно удалить ключ?" : "Удалить ключ")
                        .font(.ui(.headline))
                        .foregroundStyle(Theme.negative)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField(provider == .claude ? "sk-ant-…" : "Ключ Gemini (AQ.… или AIza…)", text: $keyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(saveKey)
                        .fieldBackground()
                    Button(action: saveKey) {
                        Text("Сохранить ключ")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pill(.primary))
                    .disabled(keyDraft.trimmed.isEmpty)
                }
                .padding(.vertical, 20)
            }
            if case .failed(let message) = check {
                Banner(text: message, style: .error)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: settings.provider) { _, _ in
            check = .idle
            deleteKeyArmed = false
            keyDraft = ""
        }
    }

    private func keyFooter(_ provider: AIProvider) -> String {
        switch provider {
        case .claude:
            return "Ключ хранится только на этом устройстве, в Keychain, и отправляется только в Anthropic. Создать ключ: console.anthropic.com → API Keys."
        case .gemini:
            return "Ключ хранится только на этом устройстве, в Keychain, и отправляется только в Google. Создать ключ: aistudio.google.com → API keys. Бесплатный тариф есть только у проекта без привязанного биллинга; на нём Google может использовать запросы для улучшения своих моделей. Проверка подключения тратит 1 запрос из дневного лимита."
        }
    }

    private var readingGroup: some View {
        @Bindable var settings = settings
        return group("Чтение") {
            toggleRow("Сохранять каждый текст в историю", isOn: $settings.autosaveTexts)
        }
    }

    private var cardsGroup: some View {
        @Bindable var settings = settings
        return group("Карточки", footer: "AI добавляет начальную форму, грамматическую пометку и чередование даже к словам с готовым переводом.") {
            toggleRow("Определять начальную форму", isOn: $settings.wantBaseForms)
        }
    }

    /// TZ 3, sections 2 and 10: numbers that are not confirmed; they apply to new tasks at once.
    private var writingGroup: some View {
        @Bindable var settings = settings
        return group("Письмо", footer: "Число слов, баллы и время не подтверждены официально — сверь с пробным тестом: certyfikatpolski.pl → «Przykładowe testy». Изменения сразу действуют на новые задания.") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Уровень экзамена")
                    .font(.ui(.headline))
                SegmentedPills(items: ExamLevel.allCases, title: { $0.rawValue }, selection: $settings.writing.examLevel)
            }
            .padding(.vertical, 16)
            Hairline()
            stepperRow("B1, короткая форма", value: $settings.writing.wordsB1.short, range: 20...400, step: 10, unit: "слов")
            Hairline()
            stepperRow("B1, длинная форма", value: $settings.writing.wordsB1.long, range: 20...600, step: 10, unit: "слов")
            Hairline()
            stepperRow("B2, короткая форма", value: $settings.writing.wordsB2.short, range: 20...400, step: 10, unit: "слов")
            Hairline()
            stepperRow("B2, длинная форма", value: $settings.writing.wordsB2.long, range: 20...600, step: 10, unit: "слов")
            Hairline()
            stepperRow("Баллы за короткую форму", value: $settings.writing.points.short, range: 1...30, step: 1, unit: "из 30")
            Hairline()
            stepperRow("Баллы за длинную форму", value: $settings.writing.points.long, range: 1...30, step: 1, unit: "из 30")
            Hairline()
            stepperRow("Время на модуль B1", value: $settings.writing.minutesB1, range: 10...240, step: 5, unit: "мин")
            Hairline()
            stepperRow("Время на модуль B2", value: $settings.writing.minutesB2, range: 10...240, step: 5, unit: "мин")
            Hairline()
            toggleRow("Панель польских букв ą…ż", isOn: $settings.writing.lettersBar)
        }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ui(.headline))
                Text("\(value.wrappedValue) \(unit)")
                    .font(.ui(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(minHeight: 64)
    }

    private var advancedGroup: some View {
        @Bindable var settings = settings
        return group("Для опытных", footer: "По умолчанию: Claude — \(AIConfiguration.defaultModel) и \(AIConfiguration.defaultBaseURL.absoluteString), Gemini — \(GeminiClient.defaultModel). Адрес Claude можно заменить на свой прокси, совместимый с Messages API. Резервная модель (только для Claude): если Claude откажется отвечать из-за правил безопасности, запрос повторит другая модель (бета-функция API). Gemini на бесплатном тарифе часто перегружен (503): тогда запрос один раз повторит облегчённая модель — она быстрее, но чаще ошибается.") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledTextField(title: "Модель Claude", text: $settings.model, polish: false)
                LabeledTextField(title: "Адрес API Claude", text: $settings.baseURLString, polish: false, keyboard: .URL)
                LabeledTextField(title: "Модель Gemini", text: $settings.geminiModel, polish: false)
            }
            .padding(.vertical, 20)
            Hairline()
            toggleRow("Резервная модель Claude при отказе", isOn: $settings.refusalFallback)
            Hairline()
            toggleRow("Gemini: при перегрузке — \(GeminiClient.fallbackModel)", isOn: $settings.geminiFallback)
            Hairline()
            Button("Вернуть по умолчанию") {
                settings.resetConnection()
            }
            .buttonStyle(.pill(.secondary, size: .medium))
            .padding(.vertical, 16)
        }
    }

    private var dataGroup: some View {
        group("Данные", footer: "Всё хранится на устройстве. Экспорт — резервная копия карточек, текстов, письменных работ и ошибок.") {
            ValueRow(title: "Карточек", value: "\(cards.cards.count)")
            Hairline()
            ValueRow(title: "Текстов в истории", value: "\(readings.texts.count)")
            Hairline()
            ValueRow(title: "Записей в банке ошибок", value: "\(mistakes.mistakes.count)")
            Hairline()
            ValueRow(title: "Проверенных текстов (письмо)", value: "\(writingTexts.texts.count)")
            Hairline()
            ShareLink(item: backup, preview: SharePreview("Резервная копия Po polsku")) {
                Label("Экспорт в JSON", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.pill(.secondary, size: .medium))
            .padding(.vertical, 16)
            if let error = cards.saveError {
                Banner(text: "Не удалось сохранить карточки: " + error, style: .error)
                    .padding(.bottom, 16)
            }
        }
    }

    /// A titled card of rows with an optional note under it.
    private func group<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            if let footer {
                Text(footer)
                    .font(.ui(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.ui(.headline))
        }
        .frame(minHeight: 64)
    }

    @ViewBuilder
    private var checkIndicator: some View {
        switch check {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .tint(Theme.ink)
        case .ok:
            Tag(text: "Работает", style: .positive)
        case .failed:
            Tag(text: "Ошибка", style: .negative)
        }
    }

    private var backup: Backup {
        Backup(exported: Date(), cards: cards.cards, texts: readings.texts, mistakes: mistakes.mistakes, writing: writingTexts.texts, textErrors: textErrors.entries)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func saveKey() {
        guard !keyDraft.trimmed.isEmpty else { return }
        ai.saveKey(keyDraft)
        keyDraft = ""
        Task { await runCheck() }
    }

    @MainActor
    private func runCheck() async {
        check = .checking
        do {
            try await ai.checkConnection()
            check = .ok
        } catch let error as AIError {
            check = .failed(error.userMessage)
        } catch {
            check = .failed(error.localizedDescription)
        }
    }
}

extension Backup: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { backup in
            SentTransferredFile(try backup.write())
        }
    }
}
