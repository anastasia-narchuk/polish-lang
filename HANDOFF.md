# HANDOFF — состояние на 02.11.2026

Это текущее состояние проекта, а не дневник: каждая сессия переписывает файл целиком, история — в «Журнале сессий» внизу и в `git log`. Как начинать и завершать сессию и как писать этот файл — в [CLAUDE.md](CLAUDE.md). Что за проект, стек, структура, запуск — в [README.md](README.md).

- **Рабочая ветка:** `claude/design-next-part-tsbh86`. В неё влита `claude/funny-brown-3l5wg1` (ТЗ 1 и 2); открыт PR [anastasia-narchuk/polish-lang#2](https://github.com/anastasia-narchuk/polish-lang/pull/2) в `main`. Пока PR не влит, в `main` только README: новую сессию начинать с этой ветки.
- **Последний зелёный CI:** [run #11](https://github.com/anastasia-narchuk/polish-lang/actions/runs/41454585191), коммит `416e23a`: тесты ядра, сборка Xcode, 13 скриншотов (iPhone, светлая и тёмная тема, iPad).

## 1. ТЗ и статусы

| ТЗ | Статус |
|---|---|
| ТЗ 1 «Свои слова во флеш-карточки (текстом и по фото)» | **сделано**; приёмка частично, см. ниже |
| ТЗ 2 «Генерация текста по теме и уровню A1–B2 + читалка» | **сделано**; приёмка частично, см. ниже |
| ТЗ 3 «Подготовка к письменной части экзамена (Pisanie, B1–B2)» | **не начато.** ТЗ получено 02.11 во вложении чата, в репозитории его нет (разд. 3, п. 15). Вкладка-заглушка: `ios/PolishLang/UI/Writing/WritingPlaceholderView.swift` |
| Дизайн в стиле Wise (просьба пользователя без ТЗ) | **сделано**, принято пользователем 02.11 |

ТЗ 3 написано под веб-артефакт «Pisz po polsku»: §15 («привязка к стеку»: артефакт, polish-learner, Mongo) к iOS неприменим, как §9 в ТЗ 1 и 2. Модель в ТЗ 3 — Claude (`claude-sonnet-5-5`); это зависит от решения по Apple Foundation Models (разд. 3, п. 14).

Почему в ТЗ 1 и 2 почти везде «не проверено»: **не было API-ключа Claude** (живых ответов модели не было ни разу) и **не было Mac или iPhone** (UI проверялся только в CI: сборка и скриншоты с демо-данными и фейковым Claude). «Проверено юнит-тестом» = логика приложения с подставным ответом модели.

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

### ТЗ 3, критерии приёмки (§14, текст дословно) — все не проверены: работа не начата

1. На ступени Akapit (печатаю) опора открыта, идеи показывают только русский текст. Тап открывает польский вариант, счётчик раскрытий растёт.
2. На ступени Egzamin в тренировке опора скрыта. После открытия текст в истории помечен «с опорой» и не участвует в прогнозе.
3. В симуляции нет поля ввода, перевода задания и опоры. Таймер идёт обратным отсчётом, итог выводится в /30 со статусом относительно порога.
4. В разборе письма с пропущенным пунктом этот пункт помечен ✗, балл «zadanie» не выше 3/5.
5. Письмо с «Szanowny Panie» и «jak się masz?» в одном тексте получает `register.consistent = false` и понятное замечание по-русски.
6. Самопроверка показывает только количество ошибок по предложениям, исправлений не видно.
7. «Переписать» скрывает исправленную версию. После проверки показывается дельта баллов и число исправленных ошибок.
8. Кнопка «ł» на панели букв вставляет символ в позицию курсора, фокус остаётся в поле.
9. Слова из «Слова для повторения» сохраняются в карточки в форме из текста (ТЗ 1).
10. Лимиты слов, вес заданий и время меняются в настройках и сразу применяются к новым заданиям.

Крит. 8 противоречит текущему коду: панель букв вставляет букву в конец поля (разд. 6, баги).

### Дизайн (без ТЗ)

Запрос пользователя дословно: «давай дизайн всей апы сменим на аналогичный https://wise.com/ru/cost-of-living/japan/okinawa, можем только цветовую палитру заменить а так скругления/элементы/отступы и другое брала отсюда, чтобы уйти от типичного навайбкоженного дизайна».
- **Сделано:** все экраны. Формы, размеры и шрифт сняты со страницы Wise через Playwright (computed styles); описание — в README, раздел «Дизайн».
- **Проверено:** по 13 скриншотам CI run #11 (светлая и тёмная тема, iPad). Пользователь: «По дизайну все ок, принято».
- **Не проверено:** на устройстве; Dynamic Type на крупных размерах.

## 2. Отклонения от ТЗ и итоговые промпты

В сессии 02.11 промпты и логика не менялись, менялся только интерфейс (разд. 4).

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

## 3. ОТКРЫТЫЕ решения (ждут подтверждения пользователя)

В сессии 02.11 подтверждено только оформление (п. 12, частично). Остальное не подтверждалось.

1. **API-ключ:** сейчас в Keychain устройства (`ios/PolishLang/Platform/Keychain.swift`, service `polish-lang`, account `anthropic-api-key`), запросы идут напрямую в `api.anthropic.com`. Альтернатива — свой сервер-прокси: ключ на сервере, лимиты там же. Обязательно, если приложение будет у других людей или в App Store. Поле «Адрес API» в настройках уже есть. Связано с п. 14.
2. **Резервная модель при отказе:** включена по умолчанию: `fallbacks: "default"` + `anthropic-beta: server-side-fallback-2026-07-01`, только для `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-opus-5`, `claude-fable-5-1`. Выключается в Настройки → «Для опытных».
3. **«Если начальная форма не нужна» (ТЗ 1 §2.1, крит. 6)** сделано переключателем «Определять начальную форму», **по умолчанию вкл.** Пока он включён, слова с готовым переводом тоже уходят в AI за base и пометкой.
4. **Крит. 8 ТЗ 1 vs §7:** что показывать, если добавляется только уже существующая форма — тост (сейчас) или экран с «Пропущено повторов: 1».
5. **Правки промптов** из разд. 2: обёртка `items`, строка про тему на русском, строка для диалога, перевод профилей на польский, `usedMyWords` в форме из текста, строка с заголовком и подсказка падежа в 4.2 ТЗ 2.
6. **Модель и effort:** `claude-sonnet-5-5`; effort low для переводов, medium для генерации и фото.
7. **Автосохранение текстов в историю:** по умолчанию вкл.
8. **Повторение:** интервалы, правила «почти», подсказки и повторы в сессии (разд. 2).
9. **Выделение фразы** только режимом «Фраза» (без протягивания), в пределах абзаца.
10. **Фото:** сканер + галерея (без обычной камеры), максимум 3, фото хранятся навсегда, пока на них ссылается карточка.
11. **Данные только на устройстве:** без iCloud-синхронизации; экспорт в JSON есть, импорта нет.
12. **Оформление.** Подтверждено 02.11: формы и отступы Wise, палитра малиновый `#FF7E9D` + винный `#3D0A1A`, тёмные карточки разделов, Inter, антиква в читалке. Не подтверждено: название «Po polsku», bundle id `io.github.anastasia-narchuk.polishlang`, иконка «ą» (малиновая, к палитре подходит), интерфейс на русском (`developmentRegion = ru`), iOS 17+, iPhone и iPad.
13. **CI на каждый пуш в `ios/**`** (macOS-раннер, ~15 мин; бесплатно, пока репозиторий публичный). Оставить, урезать или убрать?
14. **Apple Foundation Models вместо Claude API.** Пользователь хочет перейти: без ключа, инференс бесплатный, расходы на стороне Apple. **Планируется, но сейчас не готово к внедрению.** Проверено 02.11 по документации Apple:
    - **Блокер — языки.** Apple Intelligence не поддерживает польский и русский: в списке [support.apple.com/121115](https://support.apple.com/en-us/121115) (обновлён 22.10.2026) их нет. Если в промпте есть неподдерживаемый язык, `LanguageModelSession.respond` бросает `unsupportedLanguageOrLocale`. Язык устройства и Siri должны совпадать и быть из этого списка. В анонсе третьего поколения моделей ([machinelearning.apple.com](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models), 08.06.2026) Polish и Russian есть среди локалей оценки — поддержка, вероятно, появится, но даты нет.
    - **На устройстве** (`SystemLanguageModel`, iOS 26+): около 3B параметров, контекст 4096 токенов (iOS 26) и 8192 (iOS 27, новые устройства). С iOS 27 принимает картинки (`Attachment(UIImage)`), есть системные `OCRTool` и `BarcodeReaderTool`. Нужны iPhone 15 Pro, 16 или новее и включённая Apple Intelligence. Работает офлайн.
    - **Private Cloud Compute** (`PrivateCloudComputeLanguageModel`, только iOS 27+): контекст 32K, рассуждение (`ContextOptions(reasoningLevel:)`). Без затрат на облачный API для участников App Store Small Business Program с менее чем 2 млн первых загрузок; нужен managed entitlement (заявка у Apple). У каждого пользователя дневная квота (`quotaUsage`), больше — через iCloud+. Нужна сеть.
    - **Риск по качеству:** модель на устройстве маленькая и с коротким контекстом. Для ТЗ 3 (разбор как на экзамене, точные фрагменты ошибок) и для перевода форм с падежом в ТЗ 1 и 2 её сначала проверить через фреймворк Evaluations.
    - **Как внедрять:** в iOS 27 появился протокол `LanguageModel`, и одна `LanguageModelSession` может работать с моделью Apple или с Claude (Anthropic выпускает Swift-пакет провайдера). План:
      1. Спайк на iPhone пользователя: бросает ли `respond` ошибку на польском и русском, какое качество.
      2. Провайдер AI как настройка: «Apple (бесплатно)» или «Claude (ключ)». По умолчанию Apple, если `supportsLocale` и Evaluations это позволяют.
      3. Claude остаётся резервом.

      Решить: когда делать (до ТЗ 3 или после) и поднимать ли минимум до iOS 26/27.
    - **В CI не проверить:** на macOS-раннерах Apple Intelligence нет, нужен iPhone пользователя или Mac с Apple silicon.
15. **ТЗ 3 в репозиторий:** положить в `docs/tz/TZ-3-pisanie.md`, чтобы следующая сессия не зависела от вложений чата. Это рекомендация; копию, сделанную в начале сессии 02.11 вместе с макетами, по просьбе пользователя откатили.
16. **PR #2 → `main`:** влить, чтобы `CLAUDE.md` и `HANDOFF.md` были в ветке по умолчанию, или продолжать в `claude/design-next-part-tsbh86`.
17. **Мелочь по дизайну:** выбранный уровень в карточке «Новый текст» подсвечен почти чёрной плашкой. Предлагала светлую или малиновую — ответа нет.

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
- **Дизайн-система** (02.11), `ios/PolishLang/UI/Design`: палитра (светлая и тёмная), Inter (OFL) с регистрацией при первом использовании, шкала шрифтов, кнопки-пилюли, чипы, сегменты-пилюли, карточки, тёмные карточки разделов, баннеры, теги, поля, пустые состояния. Пути — в разд. 6.
- **`CLAUDE.md`** (02.11): порядок начала и завершения сессии, правила handoff.

## 5. Что пробовали и не сработало

- **`.inspector` для панели перевода.** На iPhone внутри `NavigationStack` читалка появлялась и через ~150 мс исчезала; путь при этом оставался `[.reader]`. Нашли по NSLog-трассировке и эксперименту с простым `Text` вместо читалки (CI-запуски #3–#8). Заменено на `.sheet` + боковую колонку (коммит `d71ef42`). **`inspector` в читалку не возвращать.**
- **`print()` для диагностики в CI** — логи пустые: stdout буферизуется и теряется, когда `simctl launch --terminate-running-process` убивает процесс. Использовать `NSLog` (stderr).
- **`simctl spawn … log stream`** с грепом по SwiftUI — только шум (`Solarium…` из UserDefaults), пользы ноль.
- **Первый запуск CI упал мгновенно:** в однострочном `run:` YAML было `: ` — для таких команд нужен блок `run: |`.
- **Путь навигации, выставленный до первого рендера** (старый демо-вариант), читалку не показал — но тогда ещё мешал `inspector`; после фикса этот вариант не перепроверялся.
- **Mac для сборки** не было (`list_computer_folders` пустой). UI-код локально проверялся только `swiftc -parse` (синтаксис); типы проверяет только CI.
- **`AttributedString[K.self] = …`** заранее заменён на типизированные свойства (`piece.backgroundColor`, `piece.underlineStyle`, `piece.link`); сам вариант с сабскриптом не проверялся.
- **Сессия 02.11 начала не с того.** Взялась дизайнить ТЗ 3 для веб-артефакта «Pisz po polsku» на claude.ai: в ветке сессии `HANDOFF.md` не было, он лежал в `claude/funny-brown-3l5wg1`. Холст с макетами удалён, коммит с документами отменён через revert (`754bac9`). Правило в `CLAUDE.md`: сначала искать `HANDOFF.md` во всех ветках.
- **Force-push** (`git reset --hard` + `git push --force-with-lease`) заблокирован классификатором авто-режима. Откатывать через `git revert`.
- **WebFetch не читает developer.apple.com** (страницы рендерит JS). Брать JSON: `curl -s https://developer.apple.com/tutorials/data/documentation/foundationmodels/<страница>.json`.
- **Стиль сайта через WebFetch не снять.** Работает Playwright: `chromium.launch()`, viewport 390×844, `getComputedStyle` по кнопкам и карточкам.

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
- `PolishTextField` (`ios/PolishLang/Platform/PolishTextField.swift`) теперь в Inter; хелпер `withSerifDesign` больше не используется.
- `FeatureCard` включает внутри себя тёмную схему (`.environment(\.colorScheme, .dark)`): всё внутри берёт тёмные варианты цветов.
- `Theme.applyAppearance` задаёт Inter заголовкам навигации и подписям таб-бара через UIKit appearance. Стеклянный таб-бар iOS 26 шрифт подписей может игнорировать (на скриншотах подписи системные).

**Дизайн (02.11):**
- `ios/PolishLang/UI/Design/Theme.swift`:
  - палитра: `bright`, `onBright`, `ink`, `onInk`, `text*`, `background`, `surface`, `fill`, `track`, `line`, `border`, `positive`/`warning`/`negative` с `*Fill`;
  - карточки разделов: `readingFeature`, `cardsFeature`, `writingFeature`, `studyFeature`;
  - размеры: `Radius`, `Space`;
  - шрифты: `InterFont.isAvailable`/`uiFont`, `Font.ui(_:weight:)`, `View.heading(_:)`;
  - UIKit: `applyAppearance()`.
- `ios/PolishLang/UI/Design/Components.swift`:
  - кнопки: `PillButtonStyle` (`.buttonStyle(.pill(.primary|.secondary|.tertiary|.destructive|.inverse, size: .large|.medium|.small))`), `CircleIconButtonStyle`, `ChipButtonStyle`;
  - поверхности: `cardBackground()`, `FeatureCard`, `IconCircle`, `screenBackground()`;
  - строки: `SectionHeader`, `InfoRow`, `Hairline`, `ValueRow`;
  - контролы: `SegmentedPills`, `ProgressBar`, `fieldBackground(isFocused:)`, `LabeledTextField`, `PolishLettersBar`;
  - статусы: `Tag`, `LevelBadge`, `Banner`, `WorkingRow`, `EmptyState`, `RetryButton`.
- Остальное:
  - `ios/PolishLang/UI/Design/Toast.swift` — тост;
  - `ios/PolishLang/UI/Design/Fonts/` — Inter-Regular/Medium/SemiBold/Bold.ttf и `Inter-OFL.txt`;
  - `themedRow()` — строка списка в новом стиле, в `ios/PolishLang/UI/Cards/CardsTab.swift`;
  - шрифт и tint на всё приложение — `ios/PolishLang/UI/App/AppEnvironment.swift`;
  - `Theme.applyAppearance()` вызывается в `PolishLangApp.init`.

**Тулчейн Swift на Linux:** архив ≈1 ГБ, в сессии 02.11 распакован в scratchpad; после перезапуска контейнера ставить заново командами выше.

## 7. Требования и ограничения пользователя

- Общаться только на русском или английском, **никогда на украинском**.
- Делаем iOS-приложение; функционал будет расширяться. Следующий раздел — тренировка письма (ТЗ 3).
- Из ТЗ: «Если что-то противоречит коду проекта, сначала спроси».
- PR без просьбы не создавать. PR #2 пользователь открыл сам; описание обновлено по её просьбе.
- Ветки: в сессии 29.10 — `claude/funny-brown-3l5wg1`; в сессии 02.11 — `claude/design-next-part-tsbh86` (назначена средой, в неё влита прежняя).
- Дизайн всего приложения — как на wise.com (формы, отступы, элементы), палитра своя; принято.
- Хочет Apple Foundation Models вместо платных API-ключей (разд. 3, п. 14).
- Handoff писать сжато, с точными путями и командами; правила — в `CLAUDE.md`. Коммитить и пушить в текущую ветку, в ответе дать название ветки и ссылку на файл на GitHub.
- В начале сессии 02.11 пользователь попросила откатить всё, что было сделано до прочтения хендоффа. Вывод: сначала хендофф, потом работа.

## 8. Следующий шаг

**ТЗ 3 «Письмо» получено, но без команды пользователя ничего не начинать.** Перед стартом ТЗ 3 спросить:
1. Положить ли ТЗ 3 в репозиторий (п. 15).
2. Что с Apple Foundation Models (п. 14): от этого зависит, на чём строить AI в ТЗ 3. Если решим делать спайк — нужен iPhone пользователя с iOS 26/27.
3. Как адаптировать ТЗ 3 к iOS (§15 неприменим), начиная с этапа 1 (MVP, §13).

Остальные решения из разд. 3 и правки багов из разд. 6 — только по прямой просьбе.

## Журнал сессий

- **29.10–02.11.2026**, `claude/funny-brown-3l5wg1`: ТЗ 1 и ТЗ 2 на iOS, CI со скриншотами, демо-режим, первый HANDOFF.
- **02.11.2026**, `claude/design-next-part-tsbh86`:
  - откат ошибочного дизайна ТЗ 3 под веб-артефакт;
  - влита ветка с iOS-приложением;
  - редизайн в стиле Wise (CI #11 зелёный, принят);
  - описание PR #2;
  - разбор Apple Foundation Models;
  - `CLAUDE.md` и этот HANDOFF.
