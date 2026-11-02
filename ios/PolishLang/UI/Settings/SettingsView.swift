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
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    if ai.hasKey {
                        Label("Ключ сохранён в Keychain", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.green)
                        Button {
                            Task { await runCheck() }
                        } label: {
                            HStack {
                                Text("Проверить подключение")
                                Spacer()
                                checkIndicator
                            }
                        }
                        .disabled(check == .checking)
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
                        }
                    } else {
                        SecureField("sk-ant-…", text: $keyDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(saveKey)
                        Button("Сохранить ключ", action: saveKey)
                            .disabled(keyDraft.trimmed.isEmpty)
                    }
                    if case .failed(let message) = check {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                    }
                } header: {
                    Text("Claude API")
                } footer: {
                    Text("Ключ хранится только на этом устройстве, в Keychain, и отправляется только в Anthropic. Создать ключ: console.anthropic.com → API Keys.")
                }

                Section("Чтение") {
                    Toggle("Сохранять каждый текст в историю", isOn: $settings.autosaveTexts)
                }

                Section {
                    Toggle("Определять начальную форму", isOn: $settings.wantBaseForms)
                } header: {
                    Text("Карточки")
                } footer: {
                    Text("AI добавляет начальную форму, грамматическую пометку и чередование даже к словам с готовым переводом.")
                }

                Section {
                    LabeledTextField(title: "Модель", text: $settings.model, polish: false)
                    LabeledTextField(title: "Адрес API", text: $settings.baseURLString, polish: false, keyboard: .URL)
                    Toggle("Резервная модель при отказе", isOn: $settings.refusalFallback)
                    Button("Вернуть по умолчанию") {
                        settings.resetConnection()
                    }
                } header: {
                    Text("Для опытных")
                } footer: {
                    Text("По умолчанию \(AIConfiguration.defaultModel) и \(AIConfiguration.defaultBaseURL.absoluteString). Адрес можно заменить на свой прокси, совместимый с Messages API. Резервная модель: если Claude откажется отвечать из-за правил безопасности, запрос повторит другая модель (бета-функция API).")
                }

                Section {
                    LabeledContent("Карточек", value: "\(cards.cards.count)")
                    LabeledContent("Текстов в истории", value: "\(readings.texts.count)")
                    LabeledContent("Записей в банке ошибок", value: "\(mistakes.mistakes.count)")
                    ShareLink(item: backup, preview: SharePreview("Резервная копия Po polsku")) {
                        Label("Экспорт в JSON", systemImage: "square.and.arrow.up")
                    }
                    if let error = cards.saveError {
                        Text("Не удалось сохранить карточки: " + error)
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                    }
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Всё хранится на устройстве. Экспорт — резервная копия карточек, текстов и ошибок.")
                }

                Section {
                    LabeledContent("Версия", value: appVersion)
                }
            }
            .navigationTitle("Настройки")
        }
    }

    @ViewBuilder
    private var checkIndicator: some View {
        switch check {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
        case .ok:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.red)
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
