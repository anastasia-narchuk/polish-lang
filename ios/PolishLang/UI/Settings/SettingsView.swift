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
        group("Claude API", footer: "Ключ хранится только на этом устройстве, в Keychain, и отправляется только в Anthropic. Создать ключ: console.anthropic.com → API Keys.") {
            if ai.hasKey {
                InfoRow(icon: "checkmark.seal.fill", title: "Ключ сохранён", subtitle: "в Keychain этого устройства")
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
                        ai.deleteKey()
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
                    SecureField("sk-ant-…", text: $keyDraft)
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

    private var advancedGroup: some View {
        @Bindable var settings = settings
        return group("Для опытных", footer: "По умолчанию \(AIConfiguration.defaultModel) и \(AIConfiguration.defaultBaseURL.absoluteString). Адрес можно заменить на свой прокси, совместимый с Messages API. Резервная модель: если Claude откажется отвечать из-за правил безопасности, запрос повторит другая модель (бета-функция API).") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledTextField(title: "Модель", text: $settings.model, polish: false)
                LabeledTextField(title: "Адрес API", text: $settings.baseURLString, polish: false, keyboard: .URL)
            }
            .padding(.vertical, 20)
            Hairline()
            toggleRow("Резервная модель при отказе", isOn: $settings.refusalFallback)
            Hairline()
            Button("Вернуть по умолчанию") {
                settings.resetConnection()
            }
            .buttonStyle(.pill(.secondary, size: .medium))
            .padding(.vertical, 16)
        }
    }

    private var dataGroup: some View {
        group("Данные", footer: "Всё хранится на устройстве. Экспорт — резервная копия карточек, текстов и ошибок.") {
            ValueRow(title: "Карточек", value: "\(cards.cards.count)")
            Hairline()
            ValueRow(title: "Текстов в истории", value: "\(readings.texts.count)")
            Hairline()
            ValueRow(title: "Записей в банке ошибок", value: "\(mistakes.mistakes.count)")
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
        Backup(exported: Date(), cards: cards.cards, texts: readings.texts, mistakes: mistakes.mistakes)
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
