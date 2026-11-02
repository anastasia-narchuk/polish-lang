# HANDOFF — сессия 29.10–02.11.2026

Ветка: `claude/funny-brown-3l5wg1` (PR не создавался). Что за проект, стек, структура, запуск — в [README.md](README.md). Здесь только итог сессии.

Последний зелёный CI: [run #9](https://github.com/anastasia-narchuk/polish-lang/actions/runs/40954610220), коммит `b93c334`: 85/85 тестов, сборка Xcode 26.6 (Swift 6.3.3) без предупреждений, скриншоты в симуляторе iOS 26.2 (iPhone 16e и iPad).

## 1. ТЗ и статусы

ТЗ лежали во вложениях чата, в репозитории их нет. Если нужно — попросить у пользователя ещё раз.

| ТЗ | Статус |
|---|---|
| ТЗ 1 «Свои слова во флеш-карточки (текстом и по фото)» | **сделано** (весь функционал); приёмка — частично, см. ниже |
| ТЗ 2 «Генерация текста по теме и уровню A1–B2 + читалка» | **сделано** (весь функционал); приёмка — частично, см. ниже |
| ТЗ 3 «Письмо» (подготовка к письменной части экзамена) | **не начато**: ТЗ не получено; в меню вкладка-заглушка `ios/PolishLang/UI/Writing/WritingPlaceholderView.swift` |

По разделам: ТЗ 1 §2.1–§7 и ТЗ 2 §2–§7 сделаны; §9 обоих ТЗ («привязка к стеку»: polish-learner, артефакт «Pisz po polsku») к iOS неприменимы.

Почему «не проверено» почти везде одинаково: **в сессии не было API-ключа Claude** (живые ответы модели не получены ни разу) и **не было Mac/iPhone** (UI проверялся только в CI: сборка и скриншоты с демо-данными и фейковым Claude). «Проверено юнит-тестом» = логика приложения с подставным ответом модели.

### ТЗ 1, критерии приёмки (§8)

1. «`rzece` даёт перевод «реке (дат./предл. п.)», base `rzeka`, alternation `k→c`. Сохранённая `pl` равна `rzece`.» — **не проверено** с живым Claude (нет ключа). Пайплайн проверен: `testRzeceKeepsTheFormAndGetsTranslationOfTheForm`.
2. «`o morzu` даёт «о море», base `morze`.» — **не проверено** (нет ключа).
3. «`poszłam [pójść]` даёт «(я) пошла», base остаётся `pójść`, `baseCheck` пустой.» — **не проверено** с живым Claude; логика «base пользователя не перезаписывается» проверена: `testLearnerBaseFormIsKeptAndOnlyChecked`.
4. «`poszłam [iść]` даёт заполненный `baseCheck` (видовая пара: pójść / iść). Поле base остаётся `iść`, пока пользователь не поменяет.» — **не проверено** с живым Claude; логика проверена тем же тестом; отображение `baseCheck` видно на скриншоте экрана проверки (фейковый ответ).
5. «`ksiazce` показывает подсказку «Похоже, пишется książce». Без нажатия «Исправить» сохраняется `ksiazce`, с нажатием сохраняется `książce`.» — **проверено юнит-тестом** `testSpellingFixIsOnlyASuggestion`; подсказка на экране и ответ живой модели **не проверены** (на скриншоте строка обрезана).
6. «Строка `morzu, przy rzece, poszłam` превращается в 3 элемента. Строки `załatwić sprawę — уладить дело` и `kot\tкот` не уходят в AI, если начальная форма не нужна.» — **проверено**: `testSingleLineWithCommasIsSplit`, `testRowsWithTranslationSkipAIWhenBaseIsNotWanted` («не нужна» = выключен переключатель «Определять начальную форму»).
7. «Фото тетради с тремя подчёркнутыми словами в режиме «Только выделенное» даёт ровно эти 3 слова в исходной форме.» — **не проверено**: нужны настоящее фото, живой Claude и устройство с камерой. Путь «ответ модели → экран проверки» проверен: `testRecognizedWordsGoToTheCheckScreen`.
8. «Повторное добавление существующей формы даёт «Пропущено повторов: 1».» — **частично**: при добавлении вместе с новыми словами экран проверки показывает «Пропущено повторов: N» (`testDuplicatesAreCountedAndDifferentFormsAreKept`, скриншот). Если добавить **только** существующую форму, показывается тост: «Эта форма уже есть в карточках» (одно слово) или «Эти слова уже есть в тетради» (список). Так требует §7 ТЗ 1 («Все слова уже есть → тост, экран проверки не открывается»). Это противоречие внутри ТЗ — открытый вопрос в разд. 3.
9. «В повторении после ответа на `rzece` видно `rzeka → rzece (k→c)`.» — **проверено**: `testStudySessionShowsAlternationAndKeepsMistakes` + скриншот в симуляторе.

### ТЗ 2, критерии приёмки (§8)

1. «Тема «wizyta u lekarza» на **A1** даёт 60–90 слов, только настоящее время, короткие предложения, нет форм прошедшего времени (-łem/-łam/-ł).» — **не проверено** (нет ключа). Проверено только, что профиль A1 целиком попадает в промпт (`testGenerationPromptCarriesTheWholeLevelProfile`) и что длина вне ±20% даёт мягкое предупреждение (`testLengthWithinTwentyPercentIsAccepted`). Прошедшее время приложение само не проверяет.
2. «Та же тема на **B2** даёт 180–250 слов, есть хотя бы одна сложноподчинённая конструкция и один пример страдательного залога или причастия.» — **не проверено** (нет ключа).
3. «На **B1** с типом «статья с мнением» в тексте есть moim zdaniem / wydaje mi się и связки.» — **не проверено** (нет ключа); в промпте эти конструкции есть.
4. «Проще» и «Сложнее» меняют уровень на соседний и сохраняют тему.» — **проверено**: `testEasierAndHarderAreNeighbours`, `testEasierAndHarderKeepTheTopic`.
5. «Клик по `lekarza` даёт «врача (род./вин. п.)», base `lekarz`, alternation пустое. Клик по `rzece` в предложении `Spacerowaliśmy nad rzeką… przy rzece` даёт перевод с подсказкой падежа и `k→c`.» — **не проверено** с живым Claude. Проверено: в контекст уходит всё предложение «Spacerowaliśmy nad rzeką… przy rzece było cicho.» (`testSelectionTextAndSentence`); панель перевода работает (скриншот, фейковый ответ).
6. «Добавить в карточки» сохраняет `pl` ровно как в тексте и `example` равное полному предложению. С переключателем «начальная форма» сохраняется `base`.» — **проверено**: `testTapTranslatesWithCacheAndAddsTheFormFromTheText`, `testBaseFormSwitchSavesTheBaseForm`. Нажатие кнопки в симуляторе не прогонялось.
7. «Включённые «мои слова»: минимум 4 из выбранных слов встречаются в тексте в любой форме и подсвечены.» — **частично**: подсветка форм из `usedMyWords` проверена (`testMyWordsAreSentAndHighlighted`, скриншот); что модель вплетает ≥4 слов — **не проверено** (нет ключа).
8. «В отрисованном DOM нет `innerHTML` с ответом модели. Текст с `<script>` внутри отображается как текст.» — **проверено в переводе на iOS**: DOM нет, текст модели выводится только как обычные строки (`AttributedString` из токенов); `<script>` остаётся текстом (`testMarkupIsJustText`).

## 2. Отклонения от ТЗ и итоговые промпты

### Отклонения

- **Хранение.** `localStorage`/Mongo заменены на UserDefaults (настройки) и JSON-файлы в `Application Support/PolishLang/`: `cards.json`, `texts.json`, `mistakes.json`, `photos/<id>/<n>.jpg`.
- **Rate limit** (5 генераций и 30 переводов в минуту) работает на устройстве, в памяти (сбрасывается при перезапуске), а не на сервере. Ответ 429 обрабатывается так же.
- **Панель перевода** «справа на десктопе / снизу на телефоне»: на iPhone — `.sheet` с детентами medium/large (текст под листом остаётся тапабельным), на iPad — колонка справа внутри читалки. `inspector` не подошёл, см. разд. 5.
- **Выделение фразы.** Выделения протягиванием нет (`Text` в SwiftUI этого не умеет). Есть только тач-режим из ТЗ: кнопка «Фраза» → тап по первому и последнему слову → «Перевести фразу». Фраза — в пределах одного абзаца.
- **JSON-ответы** — structured outputs (`output_config.format`, схемы в `ios/PolishLang/Core/AI/Schemas.swift`) плюс терпимый разбор из ТЗ. Пакетные ответы обёрнуты в `{"items":[...]}`, потому что схеме нужен объект в корне.
- **Один автоматический повтор** (не цикл): если API отвечает 400 из-за бета-заголовка резервной модели, запрос сразу повторяется без него (`AnthropicClient.send`, `rejectsFallback`).
- **Фото.** Сканер VisionKit + галерея, без обычной камеры; ровно 3 фото («N из лимита модели» не вычисляется). Фото уменьшаются до 2048 px, JPEG 0.8, вход до 40 МБ.
- **Повторение** («как в проекте» — того проекта нет): интервалы Лейтнера `[0,1,2,4,8,16,32]` дня. «Почти» и верный ответ после подсказки — коробка −1 (не ниже 1). Ошибка или «Не помню» — коробка 0 и повтор в этой же сессии (не больше 2 раз, через 3 карточки). «Почти» = разница только в ogonki или одна буква при длине слова ≥ 7. Сессия — до 20 карточек к повторению, «Потренироваться ещё» — 10.
- **Типы ошибок:** к перечисленным в ТЗ ó/u, rz/ż, ch/h, ą/ę, ogonki добавлены «окончание» и «другое».
- **«Мои слова»:** до 8 слов. Приоритет: ошибки +2, карточка моложе 14 дней +1…2, плюс случайность 0…0.75. Берётся `base`, если есть. Фразы длиннее 3 слов и формы с `[?]` пропускаются. Если карточек меньше 5 — уходит сколько есть.
- **Кэш переводов** `(selection, sentence)` хранится в памяти на всё время работы приложения, на диск не пишется.
- **Перевод начальной формы** для переключателя в читалке — дозапрос через промпт 4.1 ТЗ 1, а не `ru` из `keyWords` (там перевод формы, а не base).
- **Параметры вызовов** (`ios/PolishLang/Core/AI/PolishAI.swift`). Везде: `anthropic-version: 2026-10-21`, без `temperature`, модель по умолчанию `claude-sonnet-5-5`.

  | Вызов | effort | max_tokens |
  |---|---|---|
  | 4.1 ТЗ 1 | low | 16000 (пачки по 40) |
  | 4.2 ТЗ 1 | medium | 16000 (картинки идут перед текстом) |
  | 4.1 ТЗ 2 | medium | 16000 |
  | 4.2 ТЗ 2 | low | 4000 |

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

## 3. ОТКРЫТЫЕ решения (пользователь не подтверждал ни одно)

1. **API-ключ:** сейчас он в Keychain устройства (`ios/PolishLang/Platform/Keychain.swift`, service `polish-lang`, account `anthropic-api-key`), запросы идут напрямую в `api.anthropic.com`. Альтернатива — свой сервер-прокси: ключ хранится на сервере, лимиты считаются там же. Это обязательно, если приложение будет у других людей или в App Store. Поле «Адрес API» в настройках уже есть.
2. **Резервная модель при отказе:** включена по умолчанию: `fallbacks: "default"` + `anthropic-beta: server-side-fallback-2026-07-01`, только для `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-opus-5`, `claude-fable-5-1`. Выключается в Настройки → «Для опытных».
3. **«Если начальная форма не нужна» (ТЗ 1 §2.1, крит. 6)** сделано переключателем «Определять начальную форму», **по умолчанию вкл.** Пока он включён, слова с готовым переводом тоже уходят в AI за base и пометкой.
4. **Крит. 8 ТЗ 1 vs §7:** что показывать, если добавляется только уже существующая форма — тост (сейчас) или экран с «Пропущено повторов: 1».
5. **Правки промптов** из разд. 2: обёртка `items`, строка про тему на русском, строка для диалога, перевод профилей на польский, `usedMyWords` в форме из текста, строка с заголовком и подсказка падежа в 4.2 ТЗ 2.
6. **Модель и effort:** `claude-sonnet-5-5`; effort low для переводов, medium для генерации и фото.
7. **Автосохранение текстов в историю:** по умолчанию вкл.
8. **Повторение:** интервалы, правила «почти», подсказки и повторов в сессии (разд. 2).
9. **Выделение фразы** только режимом «Фраза» (без протягивания), в пределах абзаца.
10. **Фото:** сканер + галерея (без обычной камеры), максимум 3, фото хранятся навсегда, пока на них ссылается карточка.
11. **Данные только на устройстве:** без iCloud-синхронизации; экспорт в JSON есть, импорта нет.
12. **Оформление:** название «Po polsku», bundle id `io.github.anastasia-narchuk.polishlang`, иконка «ą», акцентный цвет — малиновый; интерфейс на русском, `developmentRegion = ru`; iOS 17+, iPhone и iPad.
13. **CI на каждый пуш в `ios/**`** (macOS-раннер, ~10–15 мин; бесплатно, пока репозиторий публичный). Оставить, урезать или убрать?

## 4. Сверх ТЗ

- **GitHub Actions** `.github/workflows/ios.yml`. Запускается на push или PR, если менялись `ios/**` или сам workflow, и на `workflow_dispatch` (кнопка «Run workflow» появится, только когда файл будет в `main`).
  - job `build`: `swift test` в `ios/` + `xcodebuild` под `generic/platform=iOS Simulator`;
  - job `screenshots`: собирает под iPhone-симулятор, запускает экраны демо-режима (светлая и тёмная тема), затем iPad (`panel`, `cards`), выкладывает артефакт `screenshots` (PNG и непустые логи stderr).

  Смотреть: Actions → iOS → запуск → Artifacts. В облачной сессии `gh` нет: использовать MCP-инструменты GitHub `actions_list` (list_workflow_runs / list_workflow_jobs / list_workflow_run_artifacts), `get_job_logs`, `actions_get` (download_workflow_run_artifact отдаёт временную ссылку, её можно скачать через `curl`).
- **Демо-режим** (только Debug), `ios/PolishLang/UI/App/DemoMode.swift`. Тестовые карточки и текст во временной папке, фейковый Claude (`DemoTransport`), реальные данные не трогаются. Аргументы запуска `-demo -demo-screen <экран>`, экраны: `setup reader panel cards add review study settings writing`.
  - `reader` и `panel` проходят настоящий путь: `generate()` → открытие читалки; в `panel` автоматически тапается `lekarza`.
  - В Xcode: Edit Scheme → Run → Arguments.
  - Из терминала: `xcrun simctl launch --terminate-running-process <UDID> io.github.anastasia-narchuk.polishlang -demo -demo-screen panel`.
- Экран «Банк ошибок» (`ios/PolishLang/UI/Cards/MistakesView.swift`), экран карточки с правкой и удалением (`ios/PolishLang/UI/Cards/CardDetailView.swift`), экспорт в JSON (Настройки → Данные; `ios/PolishLang/Core/State/Backup.swift` + `Transferable` в `ios/PolishLang/UI/Settings/SettingsView.swift`), панель букв ą ć ę ł ń ó ś ź ż (`PolishLettersBar`), проверка ключа без расхода токенов (`GET /v1/models/{model}`), иконка.

## 5. Что пробовали и не сработало

- **`.inspector` для панели перевода.** На iPhone внутри `NavigationStack` читалка появлялась и через ~150 мс исчезала; путь при этом оставался `[.reader]`. Нашли по NSLog-трассировке и эксперименту с простым `Text` вместо читалки (CI-запуски #3–#8). Заменено на `.sheet` + боковую колонку (коммит `d71ef42`). **`inspector` в читалку не возвращать.**
- **`print()` для диагностики в CI** — логи пустые: stdout буферизуется и теряется, когда `simctl launch --terminate-running-process` убивает процесс. Использовать `NSLog` (stderr).
- **`simctl spawn … log stream`** с грепом по SwiftUI — только шум (`Solarium…` из UserDefaults), пользы ноль.
- **Первый запуск CI упал мгновенно:** в однострочном `run:` YAML было `: ` — для таких команд нужен блок `run: |`.
- **Путь навигации, выставленный до первого рендера** (старый демо-вариант), читалку не показал — но тогда ещё мешал `inspector`; после фикса этот вариант не перепроверялся.
- **Mac для сборки** не было (`list_computer_folders` пустой). UI-код локально проверялся только `swiftc -parse` (синтаксис); типы проверяет только CI.
- **`AttributedString[K.self] = …`** заранее заменён на типизированные свойства (`piece.backgroundColor`, `piece.underlineStyle`, `piece.link`); сам вариант с сабскриптом не проверялся.

## 6. Ключевые файлы, команды, баги

Все пути от корня репо.

**AI:**
- `ios/PolishLang/Core/AI/AnthropicClient.swift` — `send`, `checkConnection`, `body(for:model:fallback:)`, `parseResponse`, `error(for:data:model:)`, `rejectsFallback`;
- `ios/PolishLang/Core/AI/PolishAI.swift` — `enrich`, `recognize`, `generate`, `translate`;
- `ios/PolishLang/Core/AI/Prompts.swift`, `ios/PolishLang/Core/AI/Schemas.swift`;
- `ios/PolishLang/Core/AI/ResponseParser.swift` — `enrichResults`, `photoItems`, `generatedText`, `translation`, `items(in:)`;
- `ios/PolishLang/Core/AI/TolerantJSON.swift`;
- `ios/PolishLang/Core/State/AIService.swift` — ключ и лимиты 5/30.

**ТЗ 1:**
- `ios/PolishLang/Core/Text/OwnListParser.swift` — `parse`, `parseLine`, `separatorRange`, `stripListMarker`;
- `ios/PolishLang/Core/Cards/CardDraft.swift` — `CardDraft.needsAI/apply/applyFix`, `DraftBuilder.prepare/save`;
- `ios/PolishLang/Core/Cards/DraftReviewModel.swift` — `enrich(using:)`;
- `ios/PolishLang/Core/Cards/PhotoImportModel.swift` — `recognize`;
- `ios/PolishLang/Core/Models/Flashcard.swift` — `makeID`, `formLine`;
- `ios/PolishLang/Core/Text/PolishText.swift` — `dedupKey`, `fold`, `slug`, `stableHash`;
- `ios/PolishLang/UI/Cards/AddWordsView.swift` — `addSingle`, `addList`, `proceed`, `loadPicked`;
- `ios/PolishLang/UI/Cards/DraftReviewView.swift` — `save`;
- `ios/PolishLang/Platform/ImagePreparation.swift`, `ios/PolishLang/Platform/DocumentScanner.swift`.

**Повторение:**
- `ios/PolishLang/Core/Review/AnswerChecker.swift` — `check`, `alignment`, `classify`;
- `ios/PolishLang/Core/Review/Leitner.swift` — `Leitner`, `StudyPlanner`, `StudyQueue`;
- `ios/PolishLang/Core/Cards/StudyModel.swift`;
- `ios/PolishLang/UI/Cards/StudyView.swift` (`DiffView`);
- `ios/PolishLang/Platform/PolishTextField.swift` — `PolishUITextField.textInputMode` включает польскую раскладку.

**ТЗ 2:**
- `ios/PolishLang/Core/Models/Reading.swift` — `CEFRLevel.profile`, `TextKind`, `ReadingText`, `ReadingTopics`;
- `ios/PolishLang/Core/Reading/TextGeneration.swift` — `GenerationValidator.check`, `MyWordsPicker.pick`;
- `ios/PolishLang/Core/Reading/ReadingSession.swift` — `generate`, `regenerate(level:)`, `retry`, `stop`, `open`, кэш переводов;
- `ios/PolishLang/Core/Reading/ReaderModel.swift` — `tap`, `translate`, `loadBaseForm`, `candidateCard`, подсветки;
- `ios/PolishLang/Core/Text/ReaderDocument.swift` — `pieces`, `sentenceRanges`, `selection`, `occurrences`;
- `ios/PolishLang/UI/Reading/ReadingTab.swift`;
- `ios/PolishLang/UI/Reading/ReaderView.swift` — `attributed`, `showsSidePanel`, `sheetPresented`;
- `ios/PolishLang/UI/Reading/TranslationPanel.swift`.

**Прочее:**
- меню — `ios/PolishLang/UI/App/RootView.swift` (`AppModel.Tab`);
- хранилища — `ios/PolishLang/Core/State/Stores.swift`;
- настройки — `ios/PolishLang/Core/State/AppSettings.swift`;
- Xcode-проект `ios/PolishLang.xcodeproj` синхронизирует папку `ios/PolishLang`: новые файлы подхватываются без правки `project.pbxproj`;
- тесты — `ios/PolishCoreTests/*`.

**Команды:**
```bash
cd ios && swift test
```
Тесты ядра (85 шт., `ios/Package.swift` = `ios/PolishLang/Core`), на macOS или Linux. На Linux тулчейна нет, ставить так (`D` — любая временная папка):
```bash
curl -sSL -o "$D/swift.tar.gz" https://download.swift.org/swift-6.4.0-release/ubuntu2404/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE-ubuntu24.04.tar.gz
```
```bash
tar xzf "$D/swift.tar.gz" -C "$D" && export PATH="$D/swift-6.4.0-RELEASE-ubuntu24.04/usr/bin:$PATH"
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
- Всё, что зависит от ответов живого Claude, не проверено (разд. 1). Сканер камеры и автопереключение на польскую раскладку не проверены на устройстве.
- Крит. 8 ТЗ 1 — открытый вопрос (разд. 3, п. 4).
- Панель букв ą…ż вставляет букву в конец поля, а не в позицию курсора (`AddWordsView.insert`, `StudyView`).
- Однобуквенные слова (w, i, z) в читалке — маленькая зона тапа.
- Кнопка «Фраза» в тулбаре — только иконка `text.badge.plus`, может быть неочевидна.
- Лимиты запросов и кэш переводов сбрасываются при перезапуске приложения.
- В CI предупреждение: `actions/checkout@v4` и `actions/upload-artifact@v4` на Node 20 → обновить до новых мажоров.
- В симуляторе на скриншоте повторения поверх клавиатуры висит системная подсказка про свайп-ввод — это не баг приложения.
- У приложения `SWIFT_VERSION = 5.0`; переход на Swift 6 не пробовали (ядро под Swift 6 собирается).

## 7. Требования и ограничения пользователя

- Общаться только на русском или английском, **никогда на украинском**.
- Делаем iOS-приложение; функционал будет расширяться. Следующий раздел — тренировка письма (письменная часть госэкзамена); в меню для него оставлена заглушка — сделано.
- Из ТЗ: «Если что-то противоречит коду проекта, сначала спроси».
- Работать в ветке `claude/funny-brown-3l5wg1`; PR без просьбы не создавать.
- Handoff писать сжато, с точными путями и командами, коммитить и пушить в текущую ветку.

## 8. Следующий шаг

**Ждать от пользователя ТЗ на «Письмо». Без него ничего не начинать.** Решения из разд. 3 и правки из разд. 6 — только по прямой просьбе пользователя.
