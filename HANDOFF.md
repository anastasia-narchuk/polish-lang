# HANDOFF — состояние на 02.11.2026 (вторая сессия дня)

Это текущее состояние проекта, а не дневник: каждая сессия переписывает файл целиком, история — в «Журнале сессий» внизу и в `git log`. Как начинать и завершать сессию и как писать этот файл — в [CLAUDE.md](CLAUDE.md). Что за проект, стек, структура, запуск — в [README.md](README.md).

- **Рабочая ветка:** `claude/relaxed-noether-l6x8d0` (отведена от `main` = `da78d2a`). По просьбе пользователя 02.11 («Да, открой PR и влей в main») открыт PR в `main` — номер и статус в разд. 8.
- **Последний зелёный CI:** [run #19](https://github.com/anastasia-narchuk/polish-lang/actions/runs/41482095815), коммит `8628eec`: тесты ядра, сборка Xcode со всеми экранами «Письма», 18 скриншотов. Run #18 (`d5437ac`) GitHub снял в очереди — его изменения вошли в #19. Run #20 (`7a4377d`, непрозрачная панель букв и снимок `19-writing-feedback-text`) — **не прошёл проверку: GitHub снял его через 15 минут в очереди** (macOS-раннер не освободился), как и #18. Из сессии перезапуск и `workflow_dispatch` — 403. Перезапустить: [run #20](https://github.com/anastasia-narchuk/polish-lang/actions/runs/41486511743) → «Re-run all jobs», или любой следующий пуш в `ios/**`.

## 1. ТЗ и статусы

| ТЗ | Статус |
|---|---|
| ТЗ 1 «Свои слова во флеш-карточки (текстом и по фото)», [`docs/tz/TZ-1-svoi-slova.md`](docs/tz/TZ-1-svoi-slova.md) | **сделано**; приёмка частично, см. ниже |
| ТЗ 2 «Генерация текста по теме и уровню A1–B2 + читалка», [`docs/tz/TZ-2-generaciya-teksta.md`](docs/tz/TZ-2-generaciya-teksta.md) | **сделано**; приёмка частично, см. ниже |
| ТЗ 3 «Подготовка к письменной части экзамена (Pisanie, B1–B2)», [`docs/tz/TZ-3-pisanie.md`](docs/tz/TZ-3-pisanie.md) | **этап 1 (MVP, §13) сделан** вместе с основой, которая в артефакте помечена «[Есть]», а в iOS её не было. Этапы 2–5 не начаты |
| Дизайн в стиле Wise (просьба пользователя без ТЗ) | **сделано**, принято 02.11 |
| Gemini вторым AI-провайдером (просьба пользователя без ТЗ, разд. 7) | **сделано**, разд. 3 п. 19 |

ТЗ 3 написано под веб-артефакт «Pisz po polsku» (он у пользователя в claude.ai; прочитан в этой сессии — промпты `P.paragraph`, `P.exam`, `P.support`, `P.transcribe`, `P.checkText`, лестница). §15 («привязка к стеку») к iOS неприменим.

**Чем проверялось.** В сессии Mac и iPhone не было: UI проверялся сборкой и скриншотами CI с демо-данными и фейковым AI. **У пользователя есть Mac с Xcode** (02.11 прислала скриншот из симулятора iPhone) — следующие проверки можно просить делать там. Ключа Claude нет. **Появился бесплатный ключ Gemini** (02.11): часть критериев, зависящих от модели, проверена живым Gemini через `LiveAITests` (запускается только с `GEMINI_API_KEY`, разд. 6). «Проверено юнит-тестом» = логика приложения с подставным ответом модели.

### ТЗ 1, критерии приёмки (§8)

1. «`rzece` даёт перевод «реке (дат./предл. п.)», base `rzeka`, alternation `k→c`. Сохранённая `pl` равна `rzece`.» — **проверено живым Gemini** (`gemini-3.5-flash`, `LiveAITests.testEnrichForms`, 02.11) и пайплайн юнит-тестом `testRzeceKeepsTheFormAndGetsTranslationOfTheForm`. С Claude не проверено (нет ключа).
2. «`o morzu` даёт «о море», base `morze`.» — **проверено живым Gemini** (тот же тест). Огрех модели: придумала alternation `r→rz`.
3. «`poszłam [pójść]` даёт «(я) пошла», base остаётся `pójść`, `baseCheck` пустой.» — **проверено живым Gemini** и `testLearnerBaseFormIsKeptAndOnlyChecked`. Огрех модели: alternation `ó→o`.
4. «`poszłam [iść]` даёт заполненный `baseCheck` (видовая пара: pójść / iść). Поле base остаётся `iść`, пока пользователь не поменяет.» — **проверено живым Gemini** (`baseCheck`: «для «poszłam» начальная форма — «pójść», а не «iść»»); то, что поле base не перезаписывается, — тем же юнит-тестом.
5. «`ksiazce` показывает подсказку «Похоже, пишется książce». Без нажатия «Исправить» сохраняется `ksiazce`, с нажатием сохраняется `książce`.» — `fix: książce` **проверено живым Gemini**; логика кнопки — `testSpellingFixIsOnlyASuggestion`. Подсказка на экране **не проверена** (на скриншоте строка обрезана).
6. «Строка `morzu, przy rzece, poszłam` превращается в 3 элемента. Строки `załatwić sprawę — уладить дело` и `kot\tкот` не уходят в AI, если начальная форма не нужна.» — **проверено**: `testSingleLineWithCommasIsSplit`, `testRowsWithTranslationSkipAIWhenBaseIsNotWanted` («не нужна» = выключен переключатель «Определять начальную форму»).
7. «Фото тетради с тремя подчёркнутыми словами в режиме «Только выделенное» даёт ровно эти 3 слова в исходной форме.» — **не проверено**: нужны настоящее фото и устройство с камерой. Путь «ответ модели → экран проверки» проверен: `testRecognizedWordsGoToTheCheckScreen`.
8. «Повторное добавление существующей формы даёт «Пропущено повторов: 1».» — **частично**: при добавлении вместе с новыми словами экран проверки показывает «Пропущено повторов: N» (`testDuplicatesAreCountedAndDifferentFormsAreKept`, скриншот). Если добавить **только** существующую форму, показывается тост: «Эта форма уже есть в карточках» (одно слово) или «Эти слова уже есть в тетради» (список). Так требует §7 ТЗ 1 («Все слова уже есть → тост, экран проверки не открывается»). Противоречие внутри ТЗ — разд. 3, п. 4.
9. «В повторении после ответа на `rzece` видно `rzeka → rzece (k→c)`.» — **проверено**: `testStudySessionShowsAlternationAndKeepsMistakes` + скриншот.

### ТЗ 2, критерии приёмки (§8)

1. «Тема «wizyta u lekarza» на **A1** даёт 60–90 слов, только настоящее время, короткие предложения, нет форм прошедшего времени (-łem/-łam/-ł).» — **не проверено**: живой Gemini дважды ответил 503 (перегрузка бесплатного тарифа, `LiveAITests.testGenerateA1`). Проверено, что профиль A1 целиком в промпте (`testGenerationPromptCarriesTheWholeLevelProfile`), длина вне ±20% даёт предупреждение (`testLengthWithinTwentyPercentIsAccepted`).
2. «Та же тема на **B2** даёт 180–250 слов, есть хотя бы одна сложноподчинённая конструкция и один пример страдательного залога или причастия.» — **не проверено** (живой запрос не делался).
3. «На **B1** с типом «статья с мнением» в тексте есть moim zdaniem / wydaje mi się и связки.» — **не проверено** (живой запрос не делался); в промпте эти конструкции есть.
4. «Проще» и «Сложнее» меняют уровень на соседний и сохраняют тему.» — **проверено**: `testEasierAndHarderAreNeighbours`, `testEasierAndHarderKeepTheTopic`.
5. «Клик по `lekarza` даёт «врача (род./вин. п.)», base `lekarz`, alternation пустое. Клик по `rzece` в предложении `Spacerowaliśmy nad rzeką… przy rzece` даёт перевод с подсказкой падежа и `k→c`.» — **живой Gemini НЕ прошёл** (`gemini-3.5-flash`, `LiveAITests.testTranslateInContext`, 02.11): «врачу (дат. п.)» (подсказка о русском падеже во фразе «к врачу», а не о польском D.) и alternation «k:k» вместо пустого. base `lekarz` верный. Возможная правка промпта — разд. 3, п. 20. Контекст предложения уходит целиком (`testSelectionTextAndSentence`).
6. «Добавить в карточки» сохраняет `pl` ровно как в тексте и `example` равное полному предложению. С переключателем «начальная форма» сохраняется `base`.» — **проверено**: `testTapTranslatesWithCacheAndAddsTheFormFromTheText`, `testBaseFormSwitchSavesTheBaseForm`. Нажатие кнопки в симуляторе не прогонялось.
7. «Включённые «мои слова»: минимум 4 из выбранных слов встречаются в тексте в любой форме и подсвечены.» — **частично**: подсветка проверена (`testMyWordsAreSentAndHighlighted`, скриншот); что модель вплетает ≥4 слов — **не проверено**.
8. «В отрисованном DOM нет `innerHTML` с ответом модели. Текст с `<script>` внутри отображается как текст.» — **проверено в переводе на iOS**: DOM нет, текст модели выводится только как строки (`testMarkupIsJustText`).

### ТЗ 3, критерии приёмки (§14)

1. «На ступени Akapit (печатаю) опора открыта, идеи показывают только русский текст. Тап открывает польский вариант, счётчик раскрытий растёт.» — **проверено юнит-тестом** `testAkapitSupportIsOpenAndIdeasAreCounted`; экран — скриншоты CI #19 `14-writing-workspace` и `18-ipad-writing-workspace` (план с началами фраз, связки, идеи по-русски, одна раскрыта: «милые коллеги → mili współpracownicy», «Подсмотрено: 1 из 5»).
2. «На ступени Egzamin в тренировке опора скрыта. После открытия текст в истории помечен «с опорой» и не участвует в прогнозе.» — **проверено юнит-тестом** `testExamTrainingHidesTheSupportAndOpeningMarksTheText` (скрыта по умолчанию, `support.opened` после открытия, бейдж «с опорой» в истории, `WritingRules.forecast` такие тексты пропускает). Экран прогноза — этап 5, не сделан.
3. «В симуляции нет поля ввода, перевода задания и опоры. Таймер идёт обратным отсчётом, итог выводится в /30 со статусом относительно порога.» — **не начато** (этап 3). Есть только строка таблицы видимости для симуляции (`SupportPolicy.of(…, simulation: true)`, `testVisibilityTable`).
4. «В разборе письма с пропущенным пунктом этот пункт помечен ✗, балл «zadanie» не выше 3/5.» — **проверено**: юнит-тест `testMissedPointCapsTheTaskScoreAndErrorsGoToTheBank` (приложение само ограничивает zadanie тремя, если есть пункт «nie») и **живой Gemini** (`gemini-3.5-flash-lite`, `LiveAITests.testCheckFindsMissedPointAndMixedRegister`, 02.11): модель сама поставила «nie» и zadanie 2/5.
5. «Письмо с «Szanowny Panie» и «jak się masz?» в одном тексте получает `register.consistent = false` и понятное замечание по-русски.» — **проверено**: юнит-тест `testMixedSalutationsMakeTheRegisterInconsistent` (локальная проверка формул обращения дополняет ответ модели) и **живой Gemini** (тот же живой тест: `consistent: false`, «Неформальное обращение Jak się masz?»). Огрех flash-lite: в пояснениях по-русски бывают ошибки («местоведение»).
6. «Самопроверка показывает только количество ошибок по предложениям, исправлений не видно.» — **не начато** (этап 2).
7. «Переписать» скрывает исправленную версию. После проверки показывается дельта баллов и число исправленных ошибок.» — **не начато** (этап 2).
8. «Кнопка «ł» на панели букв вставляет символ в позицию курсора, фокус остаётся в поле.» — **сделано** (`NotebookTextView.insertPolishLetter` → `UITextView.insertText`, панель — `inputAccessoryView`, её кнопки не забирают фокус). **Проверено в симуляторе**: скриншоты CI #19 `14-writing-workspace` и `18-ipad-writing-workspace` — демо ставит курсор в «by|am» и нажимает «ł» на панели: получилось «byłam», курсор сразу после «ł», клавиатура открыта. На тех же снимках найден баг: панель была прозрачной поверх стеклянной клавиатуры iOS 26 — исправлено в `7a4377d`, проверка — run #20. На устройстве не проверено.
9. «Слова из «Слова для повторения» сохраняются в карточки в форме из текста (ТЗ 1).» — **проверено юнит-тестом** `testNewWordsKeepTheirFormInCards` (форма из ответа, base и перевод, источник «из письма», повторно не добавляются).
10. «Лимиты слов, вес заданий и время меняются в настройках и сразу применяются к новым заданиям.» — **частично**: слова и уровень — `testSettingsApplyToTheNextTask`; вес — тот же тест через `taskWeight` в `testMissedPointCapsTheTaskScoreAndErrorsGoToTheBank`. Время хранится в настройках, но используется только симуляцией (этап 3, не сделан).

### Дизайн (без ТЗ)

Запрос пользователя дословно: «давай дизайн всей апы сменим на аналогичный https://wise.com/ru/cost-of-living/japan/okinawa, можем только цветовую палитру заменить а так скругления/элементы/отступы и другое брала отсюда, чтобы уйти от типичного навайбкоженного дизайна». Сделано и принято 02.11 («По дизайну все ок, принято»). Экраны «Письма» сделаны из той же дизайн-системы; лист в клетку и красная ручка — из ТЗ 3 §11.

## 2. Отклонения от ТЗ и итоговые промпты

### Отклонения ТЗ 1 и 2 (не менялись в этой сессии)

- **Хранение.** `localStorage`/Mongo заменены на UserDefaults (настройки) и JSON-файлы в `Application Support/PolishLang/`: `cards.json`, `texts.json`, `mistakes.json`, `photos/<id>/<n>.jpg`.
- **Rate limit** (5 генераций и 30 переводов в минуту) работает на устройстве, в памяти. Ответ 429 обрабатывается так же.
- **Панель перевода:** на iPhone — `.sheet` с детентами medium/large, на iPad — колонка справа. `inspector` не подошёл, см. разд. 5.
- **Выделение фразы** — только тач-режим «Фраза» (первое и последнее слово), в пределах абзаца.
- **JSON-ответы** — structured outputs плюс терпимый разбор. Пакетные ответы обёрнуты в `{"items":[...]}`.
- **Один автоматический повтор** (не цикл) у Claude: если API отвечает 400 из-за бета-заголовка резервной модели, запрос повторяется без него.
- **Фото** — сканер VisionKit + галерея, ровно 3 фото, 2048 px, JPEG 0.8, вход до 40 МБ.
- **Повторение** — Лейтнер `[0,1,2,4,8,16,32]` дня; «почти» и ответ после подсказки — коробка −1; ошибка — коробка 0 и повтор в сессии (до 2 раз, через 3 карточки).
- **Типы ошибок** — к ТЗ добавлены «окончание» и «другое».
- **«Мои слова»** — до 8 слов, приоритет ошибок и свежих карточек.
- **Кэш переводов** — в памяти. **Перевод начальной формы** — дозапрос через промпт 4.1 ТЗ 1.
- **Параметры вызовов** (`ios/PolishLang/Core/AI/PolishAI.swift`), без `temperature`:

  | Вызов | effort | max_tokens |
  |---|---|---|
  | 4.1 ТЗ 1 | low | 16000 (пачки по 40) |
  | 4.2 ТЗ 1 | medium | 16000 (картинки перед текстом) |
  | 4.1 ТЗ 2 | medium | 16000 |
  | 4.2 ТЗ 2 | low | 4000 |
  | 7.1 ТЗ 3 и «Свой текст» | medium | 16000 |
  | 7.2 ТЗ 3 (расшифровка) | medium | 16000, ответ — текст без схемы |
  | 7.4 ТЗ 3 (разбор) | medium | 24000 |

  У Gemini effort → `thinkingLevel`, max_tokens → `maxOutputTokens`.

### Отклонения ТЗ 3

- **Объём этапа 1.** В iOS не было ничего из помеченного «[Есть]», поэтому сделано и это: генерация задания, рабочее место (печатаю / от руки по фото), полный разбор, экран разбора, история, «Свой текст».
- **Лестница** — только Akapit → Egzamin (разд. 3, п. 18, подтверждено). Ступень Egzamin: короткая и длинная форма по очереди (`nextExamLength`), формы для случайного задания — описания из `P.exam` артефакта.
- **Akapit:** 50–80 слов (как в артефакте), 5 обязательных слов из карточек (`MyWordsPicker`, лимит 5) и 2 случайные связки из списка артефакта — чипы в блоке задания.
- **Объём:** для экзамена и своего задания — цель ±10%; счётчик зелёный в диапазоне, жёлтый до 20% за границей, красный дальше. Число слов задания всегда берётся из настроек, а не из ответа модели.
- **Рабочее место:** на iPad опора — колонка справа со своей прокруткой; на iPhone — карточка между заданием и полем (вместо «шторки»: шторка спорит с клавиатурой). На Akapit и в «Своём тексте» открыта, в тренировке Egzamin свёрнута с пояснением. Таб-бар на рабочем месте скрыт.
- **Поле:** `UITextView` на клетчатом фоне (SwiftUI `Canvas`) с красными полями, антиква New York 19 pt с Dynamic Type вместо Literata, высота строки кратна клетке. Без автокоррекции, заглавных и проверки орфографии; польская раскладка включается сама, если установлена.
- **Панель ą…ż с Shift** — над клавиатурой (`inputAccessoryView`), а не под полем: так она всегда видна при наборе. По таблице §5 — только Akapit (печатаю) и «Свой текст»; в тренировке Egzamin её нет. Отключается в настройках.
- **Подчёркивание ошибок** — сплошное красное с надстрочным номером (волнистого у `Text` в SwiftUI нет); фрагменты — ссылки `plerr://<n>`, тап подсвечивает пункт списка и прокручивает к нему.
- **Страховки поверх ответа модели:** пропущенный пункт («nie») ограничивает zadanie тремя; смешанные формулы обращения (`RegisterHeuristics`: Szanown…, Z poważaniem… против Cześć, Jak się masz…) делают регистр несогласованным с замечанием по-русски.
- **Балл:** сумма критериев / 25 × 100; баллы задания — только у экзаменационных заданий (вес короткой/длинной формы из настроек). Подпись «оценка по нашей шкале».
- **«С опорой»** — у любого текста, где панель опоры была показана (на Akapit она открыта сразу, как в артефакте). Прогноз /30 считает только экзаменационные тексты от руки без опоры.
- **Банк ошибок текстов** — отдельный файл `text-errors.json` (у карточек свой банк `mistakes.json`, другая структура). id = hash(fragment → correction), подкатегории орфографии ó/u, rz/ż, ch/h, ą/ę, nie, ogonki. Регистр — одна запись «Pan/Pani или ty — не смешивай». Ловушки — топ-3 по count / дни с lastSeen, только из банка текстов.
- **Черновик** — `writing-draft.json`, сохраняется через 2 с после изменения и при уходе с экрана; фото в черновик не пишутся (только расшифровка). Новое задание при черновике с текстом — встроенное подтверждение на хабе.
- **Фото:** до 3, поворот на 90°, порядок — кнопками ←/→ (вместо перетаскивания), просмотр. >15% слов с `[?]` → «Сфотографируй ближе при дневном свете».
- **Сбой разбора** — черновик и расшифровка сохраняются, «Ещё раз» повторяет только разбор (фото заново не читаются).
- **Не сделано из этапа 1 и общих требований §11:** фокус-режим «На весь экран», полноэкранный шаг «Пиши на бумаге» с блокировкой сна, предупреждение за 10 минут (нужно только для обратного отсчёта симуляции).
- **Лимиты:** генерация заданий делит лимит 5 в минуту с генерацией текстов; разбор и расшифровка без локального лимита.

### Итоговые промпты ТЗ 3 (`ios/PolishLang/Core/Writing/WritingPrompts.swift`)

**7.1 — задание** (`WritingPrompts.task`). Изменено относительно ТЗ: (а) «Dla każdego zadania» → «Dla zadania» (одно задание; набор для симуляции — этап 3); (б) добавлена строка «Temat może być podany po rosyjsku — zadanie pisz po polsku.» (если тема задана); (в) для Akapit — «, oraz wyrażeń: …» (2 связки, как в артефакте); (г) в "plan" добавлены примеры частей и строка о формулах для писем (из `SUPPORT_SPEC` артефакта и §4.3 ТЗ); (д) "ru" — «краткий перевод задания на русский»; (е) явный JSON-шаблон в последней строке, ответ только `{"task":{...}}`. Пример для Akapit:
```
Jesteś autorem zadań Państwowego Egzaminu Certyfikatowego z języka polskiego jako obcego, poziom B1.
Ułóż jedno zadanie z części „Pisanie”.
Forma: krótka forma: e-mail, wpis na forum, opinia, wiadomość do znajomego albo notatka. Temat: z życia codziennego w Polsce. Liczba słów: 50–80.
W zadaniu musi dać się naturalnie użyć słów: {słowo1}, {słowo2}, {słowo3}, {słowo4}, {słowo5}, oraz wyrażeń: {związek1}, {związek2}.
Dla zadania:
- "form", "register": "formalny"|"nieformalny", "polecenie" (w stylu egzaminu), "punkty" (3–4 elementy treści do uwzględnienia), "words", "ru" (краткий перевод задания на русский),
- "plan": 3–4 części w kolejności [{"ru": nazwa części po rosyjsku, np. "Вступление", "Просьба", "Прощание", "phrases": 2–3 polskie początki zdań typowe dla tej formy}]. W listach i e-mailach plan zawiera formuły powitania i pożegnania (np. „Szanowni Państwo,”, „Z poważaniem”, „Pozdrawiam serdecznie”),
- "connectors": 4–6 wyrażeń łączących pasujących do formy,
- "ideas": 5–6 [{"ru": myśl po rosyjsku 2–5 słów, "pl": kluczowa polska kolokacja}].
Odpowiedz tylko JSON: {"task":{"form":"","register":"","polecenie":"","punkty":[],"words":0,"ru":"","plan":[{"ru":"","phrases":[]}],"connectors":[],"ideas":[{"ru":"","pl":""}]}}
```
Для «Тренировки формы» третья строка — `Forma: {forma}. Temat: {temat}. Liczba słów: około {N}.` и строка про тему на русском, без строки «W zadaniu musi…». Для «Сегодня» на ступени Egzamin `Forma:` — описание короткой или длинной формы уровня (`WritingPrompts.examForms`), тема «z życia codziennego w Polsce».

**«Свой текст»** (`WritingPrompts.ownTask`) — нового в ТЗ нет («[Есть]» в артефакте как `P.support`); переписан так, чтобы модель выделяла пункты и регистр для разбора 7.4. Первые строки, дальше — те же поля, что в 7.1, с `"words" ({N})`:
```
Jesteś nauczycielem języka polskiego jako obcego. Rosyjskojęzyczna uczennica (poziom B1) ma napisać tekst na około 120 słów. Oto zadanie, które przyniosła (po polsku albo po rosyjsku):
"""
{zadanie uczennicy}
"""
Przygotuj je do pracy tak jak zadanie egzaminu. "polecenie": treść zadania po polsku; jeśli zadanie jest po polsku, przepisz je bez zmian. "punkty": elementy treści, które zadanie każe uwzględnić; jeśli ich nie wymienia, podaj 3 najważniejsze.
```

**7.2 — расшифровка** (`WritingPrompts.transcribe`) — `P.transcribe` артефакта; добавлена вторая фраза про несколько фото:
```
Na zdjęciu (lub zdjęciach) jest odręczny tekst uczennicy po polsku. Kilka zdjęć to kolejne strony jednego tekstu, w tej kolejności. Przepisz go DOKŁADNIE tak, jak jest napisany — ze wszystkimi błędami ortograficznymi i gramatycznymi, brakującymi lub zbędnymi ogonkami, interpunkcją i podziałem na akapity. Niczego nie poprawiaj i nie dopisuj. Słowo, którego nie da się odczytać, zapisz jako [?]. Odpowiedz wyłącznie przepisanym tekstem, bez komentarzy.
```

**7.4 — полный разбор** (`WritingPrompts.check`). Изменено относительно ТЗ: (а) правила полей взяты из `P.checkText` артефакта (подробнее, чем в ТЗ); (б) у "points" — «po jednym na każdy punkt zadania, w tej samej kolejności»; (в) у "register" — что проверять (Pan/Pani/Państwo или ty, формулы); (г) у "zadanie" — «pominięty punkt — najwyżej 3» и штраф за длину (§12 ТЗ); (д) строка «Oceniaj uczciwie i surowo…» (принцип 5 ТЗ); (е) явный JSON-шаблон. Строка «Obowiązkowe słowa: …» — только если они есть (Akapit: слова и связки).
```
Jesteś egzaminatorem Państwowego Egzaminu Certyfikatowego z języka polskiego, poziom B1. Oceń tekst rosyjskojęzycznej uczennicy.
ZADANIE: reklamacja. {polecenie}
Punkty: {punkt 1}; {punkt 2}; {punkt 3}.
Rejestr: formalny. Długość: około 150 słów (tekst ma {n}).
TEKST:
"""
{tekst}
"""
Zwróć JSON:
- "errors": [{"fragment": DOKŁADNY fragment z tekstu uczennicy (taki sam zapis), najkrótszy fragment z błędem, "correction": poprawna forma tego fragmentu, "type": "ortografia"|"gramatyka"|"leksyka"|"składnia"|"interpunkcja", "rule_ru": wyjaśnienie reguły po rosyjsku, max 20 słów}] — każdy błąd osobno; nie oznaczaj poprawnych wariantów stylistycznych,
- "points": [{"punkt": tekst punktu, "status": "tak"|"częściowo"|"nie", "quote": cytat z tekstu, w którym punkt jest zrealizowany, albo ""}] — po jednym na każdy punkt zadania, w tej samej kolejności,
- "register": {"expected": rejestr wymagany przez zadanie, "detected": rejestr tekstu, "consistent": true/false, "issues_ru": ["…"]} — sprawdź, czy forma zwracania się (Pan/Pani/Państwo albo ty) i formuły powitania i pożegnania są jednolite i pasują do zadania; problemy opisz po rosyjsku,
- "scores": {"zadanie","spojnosc","gramatyka","leksyka","ortografia"} każde 0–5 jak na egzaminie: "zadanie" (realizacja polecenia, wszystkie punkty, forma, długość; pominięty punkt — najwyżej 3; tekst dużo dłuższy lub krótszy od wymaganego — obniż ocenę i wyjaśnij w summary_ru), "spojnosc" (spójność, logika, akapity, wyrażenia łączące), "gramatyka" (poprawność gramatyczna), "leksyka" (bogactwo i trafność słownictwa), "ortografia" (ortografia i interpunkcja),
- "corrected_text": cały tekst poprawiony minimalnie, z zachowaniem stylu uczennicy,
- "upgrade": 3 propozycje {"plain": fragment uczennicy, "better": ten sam sens na wyższym poziomie, "ru": po co to, krótko po rosyjsku},
- "new_words": 3–6 słów lub kolokacji przydatnych w tym temacie, których uczennica nie użyła: {"pl": forma, w jakiej należy ich użyć w tym kontekście, "base": forma podstawowa, "ru": tłumaczenie tej formy},
- "used": które obowiązkowe słowa zostały użyte (w dowolnej formie),
- "summary_ru": 2–3 zdania po rosyjsku: co dobrze, co najważniejsze do poprawy.
Oceniaj uczciwie i surowo, jak na prawdziwym egzaminie, bez zawyżania.
Odpowiedz tylko JSON: {"errors":[],"points":[],"register":{"expected":"","detected":"","consistent":true,"issues_ru":[]},"scores":{"zadanie":0,"spojnosc":0,"gramatyka":0,"leksyka":0,"ortografia":0},"corrected_text":"","upgrade":[],"new_words":[],"used":[],"summary_ru":""}
```

**Промпты ТЗ 1 и 2** — код не менялся, тексты ниже перенесены дословно из прошлого хендоффа.

### Промпт 4.1 ТЗ 1 — перевод форм (`Prompts.enrich`)
Изменено относительно ТЗ: **только последняя строка** (формат `{"items":[...]}` и уточнение порядка). Список позиций подставляется (`N. форма` или `N. форма [base]`); ниже пример для `rzece`, `poszłam [pójść]`.
```
Rosyjskojęzyczna uczennica zapisuje polskie słowa i frazy DOKŁADNIE w tej formie, w jakiej je spotkała (często odmienione), żeby zapamiętać pisownię końcówek i wymiany głosek (r → rz, k → c, g → dz, ó → o itd.). Na fiszce zobaczy tłumaczenie rosyjskie i będzie musiała napisać z pamięci właśnie TĘ formę.
Pozycje (forma; w nawiasie kwadratowym forma podstawowa podana przez uczennicę, jeśli jest):
1. rzece
2. poszłam [pójść]
Dla każdej pozycji, w tej samej kolejności:
- "ru": tłumaczenie na rosyjski, które oddaje tę konkretną formę (przypadek, liczba, osoba, czas, rodzaj), np. „o morzu” → „о море”, „poszłam” → „(я) пошла”, „rzece” → „реке (дат./предл. п.)”. Jeśli z rosyjskiego tłumaczenia nie da się odgadnąć formy, dodaj w nawiasie krótką wskazówkę po rosyjsku.
- "base": forma podstawowa (mianownik l.poj. / bezokolicznik). Jeśli uczennica podała własną i jest poprawna — zwróć ją bez zmian.
- "baseCheck": "" jeśli forma podstawowa uczennicy jest poprawna albo jej nie podała; w przeciwnym razie krótko po rosyjsku, co nie tak.
- "form": nazwa formy po polsku, skrótowo, np. „C./Msc. l.poj.”, „cz. przeszły, 1 os. l.poj., ż.”.
- "alternation": wymiana głosek między formą podstawową a tą formą, np. „k→c”, „ó→o”, albo "".
- "note": krótko po polsku (max 60 znaków): „rzeka → rzece, C./Msc. l.poj., k→c”. Dla formy podstawowej: rodzaj albo aspekt.
- "fix": jeśli w zapisie jest błąd ortograficzny (np. brak ogonka), podaj poprawny zapis TEJ SAMEJ formy; w przeciwnym razie "".
- "isPolish": false, jeśli to nie jest polskie słowo.
Niczego nie zmieniaj w samej formie i nie sprowadzaj do formy słownikowej.
Odpowiedz tylko JSON: {"items":[{"ru":"","base":"","baseCheck":"","form":"","alternation":"","note":"","fix":"","isPolish":true}]} — w "items" po jednym elemencie na każdą pozycję, w tej samej kolejności.
```

### Промпт 4.2 ТЗ 1 — распознавание фото (`Prompts.photo`)
Изменено относительно ТЗ: **только последняя строка** (`{"items":[...]}`). Режим «Все польские слова» меняет строку `Tryb:` на: `Tryb: Wypisz wszystkie polskie słowa i frazy, które wyglądają na słownictwo do nauki (pomiń całe zdania z ćwiczeń, numery, nagłówki).`
```
Na zdjęciu (zdjęciach) są notatki lub strona z podręcznika do nauki polskiego. Uczennica mówi po rosyjsku.
Tryb: Wypisz TYLKO polskie słowa i frazy wyróżnione: podkreślone, zakreślone, zaznaczone markerem, wypisane na marginesie.
Zasady:
- Przepisz każdą pozycję DOKŁADNIE tak, jak jest napisana: ta sama forma (przypadek, osoba, czas) i ten sam zapis, nawet z błędem. Niczego nie poprawiaj i nie sprowadzaj do formy podstawowej.
- Jeśli obok jest rosyjskie tłumaczenie, wpisz je do "ru". Jeśli obok jest forma podstawowa (np. w nawiasie), wpisz ją do "base".
- Rosyjskich słów nie traktuj jako pozycji.
- "confidence": "high" albo "low" (nieczytelne pismo, niepewne litery). Niepewne litery zaznacz w "pl" jako [?].
- Bez powtórzeń.
Odpowiedz tylko JSON: {"items":[{"pl":"","ru":"","base":"","confidence":"high"}]}
```

### Промпт 4.1 ТЗ 2 — генерация текста (`Prompts.generate`)
Изменено относительно ТЗ:
- (а) во 2-й строке добавлено «Temat może być podany po rosyjsku — tekst i tytuł pisz zawsze po polsku.»;
- (б) для типа «dialog» добавлена строка «Każda kwestia dialogu to osobny akapit, który zaczyna się od myślnika (—).»;
- (в) профили уровней из §3 переведены на польский мной;
- (г) добавлена последняя строка про `usedMyWords`: без «моих слов» она звучит `"usedMyWords": [].`;
- (д) тема и «мои слова» очищаются от кавычек „” " и переводов строк, тема обрезается до 200 символов (`Prompts.sanitize`).

Строка «Wpleć…» есть только при включённых «моих словах». Типы (`TextKind.promptName`): opowiadanie, dialog, e-mail, artykuł z opinią, ogłoszenie. Пример для B1, «рассказ», с «моими словами»:
```
Jesteś autorem tekstów do nauki języka polskiego jako obcego. Czytelniczka mówi po rosyjsku.
Napisz tekst na temat: „{topic}”. Temat może być podany po rosyjsku — tekst i tytuł pisz zawsze po polsku.
Rodzaj tekstu: opowiadanie.
Poziom: B1. Trzymaj się ściśle tego profilu poziomu:
- Długość: 130–180 słów.
- Zdania: złożone podrzędnie (który, że, żeby, ponieważ, kiedy, jeśli).
- Czasy: wszystkie czasy, świadome przeciwstawienie aspektów, tryb przypuszczający (gdybym, chciałabym).
- Przypadki: wszystkie przypadki, liczebniki z przypadkami.
- Słownictwo: tematyczne (nauka, praca, zdrowie), wyrażanie opinii.
- Konstrukcje: wyrażanie opinii (moim zdaniem, wydaje mi się), spójniki (jednak, dlatego).
- Nie używaj: imiesłowów przysłówkowych uprzednich na -wszy, ciężkiego stylu urzędowego.
Wpleć naturalnie te słowa (możesz je odmieniać): {słowo1}, {słowo2}.
Tekst ma być spójny, ciekawy, z realiami życia w Polsce. Bez tłumaczenia i komentarzy w tekście.
Odpowiedz tylko JSON:
{"title":"tytuł po polsku","paragraphs":["akapit 1","akapit 2"],"keyWords":[{"form":"forma jak w tekście","base":"forma podstawowa","ru":"перевод этой формы"}],"usedMyWords":["..."]}
"keyWords": 5–8 najprzydatniejszych słów lub kolokacji z tego tekstu dla poziomu B1, w formie DOKŁADNIE jak w tekście.
"usedMyWords": słowa z podanej listy, które pojawiły się w tekście — w formie DOKŁADNIE jak w tekście.
```
Остальные профили (`CEFRLevel.profile`, `ios/PolishLang/Core/Models/Reading.swift`):
```
A1:
- Długość: 60–90 słów.
- Zdania: proste, 4–8 słów.
- Czasy: tylko czas teraźniejszy; czas przyszły z „będę” + bezokolicznik tylko jako gotowa fraza.
- Przypadki: mianownik, biernik i miejscownik w częstych konstrukcjach (w domu, mam kota).
- Słownictwo: 1000 najczęstszych słów, codzienne i konkretne.
- Nie używaj: czasu przeszłego, zdań podrzędnych, imiesłowów.
A2:
- Długość: 90–130 słów.
- Zdania: do 12 słów, zdania współrzędnie złożone (i, ale, więc, bo).
- Czasy: teraźniejszy, przeszły i przyszły; podstawowe pary aspektowe.
- Przypadki: mianownik, biernik i miejscownik, a także dopełniacz (nie ma, dużo czegoś) i narzędnik (z kimś, jestem nauczycielką).
- Słownictwo: codzienne oraz częste czasowniki ruchu, miasto, praca.
- Nie używaj: imiesłowów, trybu przypuszczającego, strony biernej.
B2:
- Długość: 180–250 słów.
- Zdania: długie, z kilkoma zdaniami podrzędnymi i wtrąceniami.
- Czasy: wszystkie, także strona bierna (jest/został zrobiony) i formy bezosobowe na -no/-to (zrobiono).
- Przypadki: wszystkie, także trudniejszy rząd (zależeć od, dziękować za).
- Słownictwo: abstrakcyjne, publicystyczne, idiomy, synonimy.
- Konstrukcje: imiesłowy (-ący, -ny/-ty; rzadziej -ąc, -wszy), spójniki natomiast, w związku z tym, mimo że.
```

### Промпт 4.2 ТЗ 2 — перевод в контексте (`Prompts.translate`)
Изменено относительно ТЗ:
- (а) добавлена 1-я строка с заголовком: ТЗ просит отправлять заголовок, но в шаблоне его не было; если заголовка нет, строка опускается;
- (б) добавлена 4-я строка с просьбой о подсказке формы в скобках — под критерий «врача (род./вин. п.)»;
- (в) пробелы и переводы строк в `{sentence}` и `{selection}` схлопываются.
```
Tytuł tekstu: „{title}”
Kontekst (zdanie z tekstu): „{sentence}”
Przetłumacz na rosyjski polskie słowo lub frazę: „{selection}” — dokładnie w tej formie i w tym znaczeniu, w jakim występuje w tym zdaniu.
W "ru" oddaj tę konkretną formę; jeśli z rosyjskiego tłumaczenia nie da się odgadnąć formy, dodaj w nawiasie krótką wskazówkę po rosyjsku, np. „врача (род./вин. п.)”.
Odpowiedz tylko JSON:
{"ru":"перевод этой формы в этом контексте","base":"forma podstawowa","pos":"część mowy po rosyjsku","form":"forma gramatyczna po polsku, np. Msc. l.poj.","alternation":"wymiana głosek względem formy podstawowej albo \"\"","note":"krótka uwaga po rosyjsku, jeśli znaczenie w tym kontekście jest nietypowe, albo \"\"","sentence_ru":"перевод всего предложения на русский"}
```


## 3. ОТКРЫТЫЕ решения (ждут подтверждения пользователя)

Подтверждены: п. 12 (частично), 15, 16 — 02.11, первая сессия; п. 18 — 02.11, вторая сессия. Остальное не подтверждалось.

1. **API-ключи:** Claude и Gemini — в Keychain устройства (`ios/PolishLang/Platform/Keychain.swift`, service `polish-lang`, account `anthropic-api-key` / `gemini-api-key`), запросы идут напрямую в `api.anthropic.com` и `generativelanguage.googleapis.com`. Если приложение будет у других людей или в App Store — нужен свой сервер-прокси (Google тоже не советует ключи в мобильных приложениях). Поле «Адрес API» есть только для Claude.
2. **Резервная модель Claude при отказе:** включена по умолчанию (`fallbacks: "default"` + `anthropic-beta: server-side-fallback-2026-07-01`) для `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-opus-5`, `claude-fable-5-1`. Выключается в Настройки → «Для опытных».
3. **«Если начальная форма не нужна» (ТЗ 1 §2.1, крит. 6)** — переключатель «Определять начальную форму», **по умолчанию вкл.**
4. **Крит. 8 ТЗ 1 vs §7:** что показывать, если добавляется только уже существующая форма — тост (сейчас) или экран с «Пропущено повторов: 1».
5. **Правки промптов ТЗ 1 и 2** (разд. 2): обёртка `items`, строка про тему на русском, строка для диалога, перевод профилей на польский, `usedMyWords` в форме из текста, строка с заголовком и подсказка падежа в 4.2 ТЗ 2.
6. **Модели и effort:** Claude — `claude-sonnet-5-5`; Gemini — `gemini-3.5-flash`; effort low для переводов, medium для генерации, фото и всех вызовов ТЗ 3.
7. **Автосохранение текстов в историю (чтение):** по умолчанию вкл.
8. **Повторение:** интервалы, правила «почти», подсказки и повторы в сессии (разд. 2).
9. **Выделение фразы** только режимом «Фраза» (без протягивания), в пределах абзаца.
10. **Фото (ТЗ 1):** сканер + галерея (без обычной камеры), максимум 3, хранятся, пока на них ссылается карточка.
11. **Данные только на устройстве:** без iCloud; экспорт в JSON есть (теперь с письменными работами и банком ошибок текстов), импорта нет.
12. **Оформление.** Подтверждено 02.11: формы и отступы Wise, палитра малиновый `#FF7E9D` + винный `#3D0A1A`, тёмные карточки разделов, Inter, антиква в читалке. Не подтверждено: название «Po polsku», bundle id `io.github.anastasia-narchuk.polishlang`, иконка «ą», интерфейс на русском, iOS 17+, iPhone и iPad.
13. **CI на каждый пуш в `ios/**`** (macOS-раннер, ~15 мин; прогоны встают в очередь друг за другом). Оставить, урезать или убрать?
14. **Apple Foundation Models вместо платного API.** Всё ещё блокер: Apple Intelligence не поддерживает польский и русский ([support.apple.com/121115](https://support.apple.com/en-us/121115), список от 22.10.2026); в анонсе моделей 3-го поколения ([machinelearning.apple.com](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models), 08.06.2026) Polish и Russian есть среди локалей оценки, даты нет. Подробности разбора (размер модели, PCC, Evaluations, протокол `LanguageModel` в iOS 27) — в `git show 24f0872:HANDOFF.md`, разд. 3 п. 14. **02.11 пользователь выбрала бесплатный Gemini** как бесплатный вариант на сейчас; Apple FM — когда появятся языки.
15. **ТЗ в репозитории — подтверждено 02.11** («по обоим пунктам принято, давай»). Все три ТЗ лежат в `docs/tz/` дословно, как во вложениях.
16. **PR #2 → `main` — подтверждено 02.11** (та же цитата), влит. `CLAUDE.md` и `HANDOFF.md` в ветке по умолчанию.
17. **Мелочь по дизайну:** выбранный уровень в карточке «Новый текст» подсвечен почти чёрной плашкой. Предлагала светлую или малиновую — ответа нет.
18. **Ступени в «Письме» — подтверждено 02.11** (ответ на вопрос: «Akapit и Egzamin (Recommended)»). Переносятся только Akapit и Egzamin + «Тренировка формы» и «Свой текст». «Słowo» — повторение карточек. Fraza, Zdanie и ежедневный орфодрил артефакта — позже отдельной задачей. Egzamin открывается после 3 абзацев ≥70%, из них 2 от руки (правило артефакта), или досрочно.
19. **Gemini вторым провайдером** (просьба пользователя, разд. 7). Не подтверждено: переключатель Claude / Gemini; модель по умолчанию `gemini-3.5-flash`; `generateContent` + `responseJsonSchema` вместо нового Interactions API; проверка подключения тратит 1 запрос (иначе 402 не поймать); при 503 один повтор на `gemini-3.5-flash-lite` (переключатель в «Для опытных», по умолчанию вкл.; lite быстрее, но пишет с опечатками — в задании была «przestal», «e-1mailu»).
    - Факты 02.11: первый ключ — `402 Your prepayment credits are depleted` (к проекту привязан биллинг = платный тариф с предоплатой; бесплатный тариф только в проекте без биллинга); второй ключ — бесплатный тариф работает. `gemini-3.5-flash` и `gemini-3.8-flash` часто отвечают 503, `gemini-3.5-flash-lite` отвечал. `gemini-2.5-*` новым пользователям недоступны (404). На бесплатном тарифе Google может использовать запросы для улучшения моделей. Дневные лимиты сбрасываются в полночь по тихоокеанскому времени (≈ 9:00 по Варшаве).
20. **Промпт 4.2 ТЗ 2 с Gemini:** «врачу (дат. п.)» вместо «врача (род./вин. п.)» — подсказка о русском падеже. Предложение: уточнить в промпте «wskazówka o formie polskiej (przypadek w języku polskim)», а мусорное alternation вида «k:k» отбрасывать в парсере. Без команды не менять.
22. **Ключ Gemini для всех пользователей.** Пользователь ожидала, что ключ будет вшит в приложение «чтобы все юзеры сидели на одном». Против: репозиторий публичный; вшитый ключ достаётся из приложения; лимиты общие на проект; и условия Gemini API: «You may use only Paid Services when making API Clients available to users in the European Economic Area» (бесплатный тариф нельзя давать пользователям в ЕС), на бесплатном тарифе запросы могут читать люди. Варианты: вшить при сборке из git-ignored `ios/Secrets.xcconfig` (только для себя) или сервер-прокси (Cloudflare Worker) + платный тариф к релизу. **Ответ 02.11:** «пока давай ничего не менять … платное апи не хочу подключать, хочу попробовать через этот бесплатный гемини» — ключ вводится в Настройках, для своих тестов бесплатного тарифа хватает. К вопросу вернуться перед раздачей приложения другим.
21. **Решения по ТЗ 3 без подтверждения** (подробно — разд. 2, «Отклонения ТЗ 3»): опора на iPhone карточкой, а не шторкой; панель букв над клавиатурой и не в тренировке Egzamin (как в таблице §5); диапазоны объёма; страховки zadanie ≤ 3 и регистра; «с опорой» и у Akapit; ловушки только из банка текстов; фото не хранятся в черновике; лимит генерации общий с чтением.

## 4. Сверх ТЗ

- **GitHub Actions** `.github/workflows/ios.yml`: push/PR в `ios/**` или сам workflow, `workflow_dispatch`.
  - job `build`: `swift test` в `ios/` + `xcodebuild` под `generic/platform=iOS Simulator`;
  - job `screenshots`: демо-экраны iPhone в светлой и тёмной теме, затем iPad, артефакт `screenshots`. Снимки письма: `09-writing` (хаб), `14-writing-workspace`, `15-writing-feedback`, `16-…-dark`, `17-…-dark`, `18-ipad-writing-workspace`.

  Смотреть: Actions → iOS → запуск → Artifacts. В облачной сессии `gh` нет: MCP GitHub `actions_list` (list_workflow_runs / list_workflow_jobs / list_workflow_run_artifacts), `get_job_logs`, `actions_get` (download_workflow_run_artifact даёт временную ссылку для `curl`). Отменять прогоны интеграции нельзя (403).
- **Демо-режим** (только Debug), `ios/PolishLang/UI/App/DemoMode.swift`: тестовые данные во временной папке, фейковый AI (`DemoTransport`). Аргументы `-demo -demo-screen <экран>`: `setup reader panel cards add review study settings writing workspace feedback`.
  - `reader`/`panel` и `workspace` проходят настоящий путь: генерация с фейковым AI → открытие экрана. В `workspace` после открытия печатается абзац, раскрывается одна идея и через 1,2 с кнопкой панели вставляется «ł» в «byam» (крит. 8 ТЗ 3).
  - `feedback` открывает разбор демо-текста (ошибки, пропущенный пункт, смешанный регистр).
  - Из терминала: `xcrun simctl launch --terminate-running-process <UDID> io.github.anastasia-narchuk.polishlang -demo -demo-screen workspace`.
- **Живые проверки AI** `ios/PolishCoreTests/LiveAITests.swift` — только с `GEMINI_API_KEY` (модель — `GEMINI_MODEL`), каждый тест = 1 запрос: `testEnrichForms`, `testGenerateA1`, `testTranslateInContext`, `testWritingTask`, `testCheckFindsMissedPointAndMixedRegister`.
- Экран «Банк ошибок» карточек, карточка с правкой и удалением, экспорт в JSON, панель букв, проверка ключа Claude без расхода токенов, иконка.
- **Дизайн-система** `ios/PolishLang/UI/Design` (разд. 6).
- **`CLAUDE.md`** — порядок сессии и правила handoff.

## 5. Что пробовали и не сработало

- **`.inspector` для панели перевода.** На iPhone внутри `NavigationStack` читалка исчезала через ~150 мс. Заменено на `.sheet` + боковую колонку (`d71ef42`). **`inspector` не возвращать**; по той же причине опора письма на iPhone — карточка, а не лист.
- **`print()` для диагностики в CI** — логи пустые; использовать `NSLog` (stderr).
- **`simctl spawn … log stream`** — только шум.
- **Однострочный `run:` с `: ` в YAML** роняет CI — нужен блок `run: |`.
- **Путь навигации до первого рендера** (старый демо-вариант) — не перепроверялся после фикса `inspector`.
- **Mac для сборки нет** (`list_computer_folders` пустой). UI локально проверяется только `swiftc -parse`; типы — только CI.
- **Сессия 02.11 (первая) начала не с того** — дизайн ТЗ 3 под веб-артефакт без хендоффа; откат `754bac9`. Правило в `CLAUDE.md`.
- **Force-push** заблокирован; откатывать через `git revert`.
- **WebFetch не читает developer.apple.com** — брать `curl -s https://developer.apple.com/tutorials/data/documentation/foundationmodels/<страница>.json`.
- **Стиль сайта через WebFetch не снять** — Playwright + `getComputedStyle`.
- **Gemini, ключ проекта с биллингом:** `models.list` отвечает 200, а генерация — 402. Поэтому проверка подключения Gemini делает маленький запрос генерации.
- **Документация Gemini** (ai.google.dev) теперь описывает в основном Interactions API (`/v1beta/interactions`, `Api-Revision`); `generateContent` работает и проверен живыми запросами 02.11.
- **Очередь CI:** прогоны #18 и #20 GitHub снял через ровно 15 минут ожидания macOS-раннера (`conclusion: cancelled`, шаги не начинались). Отменить, перезапустить или запустить workflow из облачной сессии нельзя (MCP → 403 «Resource not accessible by integration»). Не пушить пачку коммитов подряд: прогоны идут по одному и встают в очередь.
- **`static let` с `KeyPath`** в ядре не собирается в строгом Swift 6 (KeyPath не Sendable) — заменено на `enum Criterion`.

## 6. Ключевые файлы, команды, баги

Все пути от корня репо.

**AI:**
- `ios/PolishLang/Core/AI/AIProvider.swift` — `AIProvider` (claude/gemini, account ключа, модель по умолчанию), протокол `AIBackend`;
- `ios/PolishLang/Core/AI/AnthropicClient.swift` — `AIConfiguration` (в т. ч. `provider`, `overloadFallbackModel`), `send`, `checkConnection`, `body`, `parseResponse`, `error(for:)`, `rejectsFallback`;
- `ios/PolishLang/Core/AI/GeminiClient.swift` — `send` (+ один повтор на lite при 503), `checkConnection` (1 запрос), `body` (`inlineData`, `responseJsonSchema`, `thinkingLevel`), `parseResponse` (thought-части, MAX_TOKENS, SAFETY), `error(for:)` (402 → `paymentRequired`, 429 PerDay → `dailyLimit`, `RetryInfo`);
- `ios/PolishLang/Core/AI/PolishAI.swift` — `enrich`, `recognize`, `generate`, `translate`, `writingTask`, `transcribe`, `checkText`;
- `ios/PolishLang/Core/AI/Prompts.swift`, `Schemas.swift`, `ResponseParser.swift`, `TolerantJSON.swift`, `AIError.swift`;
- `ios/PolishLang/Core/State/AIService.swift` — ключи по провайдерам (`savedKeys`, `hasKey`), `makeAI()`, лимиты 5/30, `acquireGenerationSlot`.

**ТЗ 1:** `ios/PolishLang/Core/Text/OwnListParser.swift`, `ios/PolishLang/Core/Cards/CardDraft.swift` (`DraftBuilder.prepare/save`), `DraftReviewModel.swift`, `PhotoImportModel.swift`, `ios/PolishLang/Core/Models/Flashcard.swift` (`CardSource` теперь и `.writing` — «из письма»), `ios/PolishLang/Core/Text/PolishText.swift`, `ios/PolishLang/UI/Cards/AddWordsView.swift`, `DraftReviewView.swift`, `ios/PolishLang/Platform/ImagePreparation.swift` (+ `rotatedClockwise`), `DocumentScanner.swift`.

**Повторение:** `ios/PolishLang/Core/Review/AnswerChecker.swift`, `Leitner.swift`, `ios/PolishLang/Core/Cards/StudyModel.swift`, `ios/PolishLang/UI/Cards/StudyView.swift`, `ios/PolishLang/Platform/PolishTextField.swift`.

**ТЗ 2:** `ios/PolishLang/Core/Models/Reading.swift`, `ios/PolishLang/Core/Reading/TextGeneration.swift` (`MyWordsPicker` — и для слов Akapit), `ReadingSession.swift`, `ReaderModel.swift`, `ios/PolishLang/Core/Text/ReaderDocument.swift`, `ios/PolishLang/UI/Reading/*`.

**ТЗ 3 (письмо):**
- `ios/PolishLang/Core/Models/Writing.swift` — `ExamLevel` (порог 50/60), `WritingStep`, `WritingMode`, `WritingForm` (длина, письмо или нет), `WritingTask`, `TextCheck` и части, `Criterion`, `SupportStats`, `WritingChecklist`, `WritingText`;
- `ios/PolishLang/Core/Writing/WritingPrompts.swift` — промпты 7.1/«свой текст»/7.2/7.4, `connectors`, `examForms`, схемы;
- `ios/PolishLang/Core/Writing/WritingParser.swift` — `task(from:)`, `check(from:)`;
- `ios/PolishLang/Core/Writing/WritingRules.swift` — `SupportPolicy.of` (таблица §5), `range`, `lengthStatus`, `isUsed` (по основе), `applyGuards`, `taskPoints`, `akapitProgress`, `forecast`, `errorRanges`, `spellingCategory`, `RegisterHeuristics`;
- `ios/PolishLang/Core/Writing/WorkspaceModel.swift` — рабочее место: текст, опора, идеи, фото, расшифровка, `check`/`retry`/`stop`, черновик;
- `ios/PolishLang/Core/Writing/WritingSession.swift` — хаб: `start(.today|.form|.own)`, `pendingStart`, `anotherTask`, `resumeDraft`, `addToCards`, лестница;
- `ios/PolishLang/Core/State/WritingStores.swift` — `WritingSettings`, `WritingStore`, `TextErrorStore` (`record`, `traps`), `WritingDraftStore`;
- `ios/PolishLang/UI/Writing/WritingTab.swift` (хаб, история, `WritingTextRow`), `WorkspaceView.swift` (+ `WordCounter`, `CheckRow`, `StopwatchLabel`), `SupportPanel.swift`, `FeedbackView.swift` (+ `FeedbackLink`, `Accordion`);
- `ios/PolishLang/Platform/NotebookEditor.swift` — `NotebookMetrics`, `NotebookField`, `NotebookPaper`, `NotebookTextView.insertPolishLetter`, `PolishLettersInputView`;
- настройки письма — `AppSettings.writing`, `writingStep`, `egzaminUnlocked`, `nextExamLength`; группа «Письмо» в `ios/PolishLang/UI/Settings/SettingsView.swift`.

**Прочее:** меню — `ios/PolishLang/UI/App/RootView.swift`; хранилища — `ios/PolishLang/Core/State/Stores.swift`, `WritingStores.swift`; модель приложения — `AppModel.swift` (`deleteWritingText`); Xcode-проект синхронизирует папку `ios/PolishLang` (новые файлы без правки `project.pbxproj`); тесты — `ios/PolishCoreTests/*` (письмо — `WritingTests.swift`, Gemini — `GeminiTests.swift`).

**Команды:**
```bash
cd ios && swift test
```
Тесты ядра (115, из них 5 живых пропускаются без ключа), на macOS или Linux. На Linux тулчейна нет, ставить так (`D` — любая временная папка):
```bash
curl -sSL -o "$D/swift.tar.gz" https://download.swift.org/swift-6.4.0-release/ubuntu2404/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-ubuntu24.04.tar.gz
```
```bash
tar xzf "$D/swift.tar.gz" -C "$D" && export PATH="$D/swift-6.4.0-RELEASE-ubuntu24.04/usr/bin:$PATH"
```
Живые проверки Gemini (каждый тест — 1 запрос дневного лимита; ключ не коммитить):
```bash
cd ios && GEMINI_API_KEY=… swift test --filter LiveAITests
```
```bash
cd ios && GEMINI_MODEL=gemini-3.5-flash-lite GEMINI_API_KEY=… swift test --filter LiveAITests/testCheckFindsMissedPointAndMixedRegister
```
Ядро в строгом Swift 6 (сейчас без ошибок):
```bash
cd ios && swift build -Xswiftc -swift-version -Xswiftc 6 --build-path "$D/build6"
```
Синтаксис UI на Linux:
```bash
for f in $(find ios/PolishLang/UI ios/PolishLang/Platform -name '*.swift'); do swiftc -parse "$f"; done
```
Сборка на Mac:
```bash
xcodebuild build -project ios/PolishLang.xcodeproj -scheme PolishLang -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

**Известные баги и ограничения** (не чинить без запроса):
- Ответы живого Claude не проверялись ни разу; Gemini — только перечисленное в разд. 1. Сканер, польская раскладка, панель букв и клетчатое поле не проверены на устройстве.
- Крит. 8 ТЗ 1 — разд. 3, п. 4. Крит. 5 ТЗ 2 с Gemini — разд. 3, п. 20.
- Панель букв **в карточках** (`AddWordsView.insert`, `StudyView`) по-прежнему вставляет в конец поля; в поле письма — в позицию курсора.
- Однобуквенные слова в читалке — маленькая зона тапа; кнопка «Фраза» — только иконка.
- Лимиты запросов и кэш переводов сбрасываются при перезапуске.
- Фото рукописи живут только в памяти до разбора: после перезапуска черновик «от руки» восстанавливается без фото (расшифровка сохраняется).
- Gemini lite пишет с опечатками в польском (задание) и ошибками в русском (пояснения).
- В CI предупреждение: `actions/checkout@v4` и `actions/upload-artifact@v4` на Node 20.
- В симуляторе поверх клавиатуры бывает системная подсказка про свайп-ввод — не баг приложения.
- У приложения `SWIFT_VERSION = 5.0`; ядро собирается и в Swift 6.
- `FeatureCard` включает тёмную схему внутри себя; `Theme.applyAppearance` задаёт Inter навигации и таб-бару (стеклянный таб-бар iOS 26 может игнорировать).

**Дизайн:** `ios/PolishLang/UI/Design/Theme.swift` — палитра (`bright`, `ink`, `text*`, `background`, `surface`, `fill`, `track`, `line`, `border`, `positive`/`warning`/`negative` с `*Fill`), карточки разделов (`readingFeature`, `cardsFeature`, `writingFeature`, `studyFeature`), **письмо: `notebookPaper`, `notebookGrid`, `notebookMargin`, `mistakeInk`, `fixInk`**, `Radius`, `Space`, `Font.ui`, `heading`, `applyAppearance`. `ios/PolishLang/UI/Design/Components.swift` — `PillButtonStyle` (`.pill(...)`), `CircleIconButtonStyle`, `ChipButtonStyle`, `cardBackground()`, `FeatureCard`, `IconCircle`, `SectionHeader`, `InfoRow`, `Hairline`, `ValueRow`, `SegmentedPills`, `ProgressBar`, `fieldBackground`, `LabeledTextField`, `PolishLettersBar`, `Tag`, `LevelBadge`, `Banner`, `WorkingRow`, `EmptyState`, `RetryButton`, `FlowLayout`, `PhotoStrip`, `PhotoViewer`. Тост — `Toast.swift`; шрифты — `UI/Design/Fonts/`.

**Тулчейн Swift на Linux:** архив ≈1 ГБ, в сессии распакован в scratchpad; после перезапуска контейнера ставить заново.

## 7. Требования и ограничения пользователя

- Общаться только на русском или английском, **никогда на украинском**.
- Делаем iOS-приложение; функционал расширяется. Модули: чтение (ТЗ 2), карточки (ТЗ 1), письмо (ТЗ 3).
- Из ТЗ: «Если что-то противоречит коду проекта, сначала спроси».
- PR без просьбы не создавать. PR #2 пользователь открыла сама; влит в `main` по её просьбе.
- ТЗ хранить в `docs/tz/`.
- Ветки: 29.10 — `claude/funny-brown-3l5wg1`; 02.11 (первая сессия) — `claude/design-next-part-tsbh86`; 02.11 (вторая) — `claude/relaxed-noether-l6x8d0`.
- Дизайн всего приложения — как на wise.com (формы, отступы, элементы), палитра своя; принято.
- Хочет бесплатный AI вместо платных ключей: Apple Foundation Models (разд. 3, п. 14), пока — бесплатный Gemini.
- 02.11 (вторая сессия), дословно: «давай сделаем 3й модуль апки - обучение письменной части/написанию текстов, там в проекте есть ТЗ для нее».
- 02.11, дословно: «давай попробуем в апку api key привязать - у меня gemini, free tier, карта привязана с 0 денег на которой их пока не бывает чтобы не списало, потестим просто обычные лимиты на фри тире». Затем: «а попробуй этот ключ, пересоздала, тут по идее бесплатный тир уже должен быть». Ключи Gemini пользователь присылала в чат — **в репозиторий, хендофф, логи и коммиты их не писать**; в приложении ключ вводится в Настройках. В сессии ключ лежал только во временной папке scratchpad.
- Handoff писать сжато, с точными путями и командами; правила — в `CLAUDE.md`. Коммитить и пушить в текущую ветку, в ответе дать ветку и ссылку на файл.
- Сначала хендофф, потом работа (урок первой сессии 02.11).
- 02.11, про ключ: «я думала ты его сразу вошьешь в апу чтобы все юзеры сидели на одном (когда будет трафик в апе то тогда подумаю о повышении лимитов/переход на платное апи)». Затем: «пока давай ничего не менять, тут просто подскажи какой актуальный способ сейчас мне проверить работоспособность апки? платное апи не хочу подключать, хочу попробовать через этот бесплатный гемини». Слияние: «Да, открой PR и влей в main».
- Открывала проект через GitHub Desktop и Xcode на своём Маке: по умолчанию это `main`, поэтому изменения из рабочей ветки нужно вливать (или говорить, на какую ветку переключиться).

## 8. Следующий шаг

0. **Перезапустить CI run #20** (кнопка «Re-run all jobs», разд. «Шапка») и посмотреть `14-writing-workspace` (панель букв теперь непрозрачная) и `19-writing-feedback-text` (текст с красными подчёркиваниями, первая ошибка выделена) — эти два исправления CI ещё не видел.
1. **Пользователю — проверить на iPhone** (Xcode, разд. README «Как запустить»): Настройки → Gemini → вставить ключ → «Проверить подключение» → Письмо → «Начать абзац». Особенно: панель ą…ż в середине слова, клетчатое поле, фото рукописи.
2. **По команде — ТЗ 3, этап 2:** самопроверка (проход 1, промпт 7.3), «Переписать» с дельтой, образцовый текст (7.5). Затем этапы 3 (симуляция: 3 набора, общий таймер, итог /30, «сдано после времени»), 4 (Wzory, колода `phrases`, формульный дрил), 5 (прогноз /30, матрица форм, графики).
3. Решения из разд. 3 (особенно п. 19–21) и баги из разд. 6 — только по прямой просьбе.

Не начинать без команды: Fraza, Zdanie, орфодрил (п. 18), правку промптов ТЗ 1–2 (п. 5, 20), слияние ветки в `main` и PR.

## Журнал сессий

- **29.10–02.11.2026**, `claude/funny-brown-3l5wg1`: ТЗ 1 и ТЗ 2 на iOS, CI со скриншотами, демо-режим, первый HANDOFF.
- **02.11.2026**, `claude/design-next-part-tsbh86`: откат ошибочного дизайна ТЗ 3 под артефакт; редизайн в стиле Wise (принят); разбор Apple Foundation Models; `CLAUDE.md`; ТЗ 1–3 в `docs/tz/`; PR #2 влит в `main`.
- **02.11.2026**, `claude/relaxed-noether-l6x8d0`: Gemini вторым провайдером (402-история, бесплатный ключ, живые проверки ТЗ 1 и ТЗ 3); ТЗ 3 этап 1 — модуль «Письмо» (ядро, экраны, демо, скриншоты CI); README.
