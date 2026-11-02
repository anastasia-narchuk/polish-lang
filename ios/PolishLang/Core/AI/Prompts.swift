import Foundation

/// Source photo mode for word recognition (TZ 1, section 2.3).
enum PhotoMode: String, CaseIterable, Identifiable, Sendable {
    case highlighted, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highlighted: return "Только выделенное"
        case .all: return "Все польские слова"
        }
    }
}

/// Prompts from the specs. Replies are JSON; batch replies are wrapped in {"items": [...]}
/// so that the structured-output schema has an object at the root.
enum Prompts {
    /// TZ 1, 4.1: translation of the forms the learner wrote down, in one batch.
    static func enrich(_ items: [EnrichInput]) -> String {
        let list = items.enumerated().map { index, item in
            item.base.isEmpty ? "\(index + 1). \(item.pl)" : "\(index + 1). \(item.pl) [\(item.base)]"
        }.joined(separator: "\n")
        return """
        Rosyjskojęzyczna uczennica zapisuje polskie słowa i frazy DOKŁADNIE w tej formie, w jakiej je spotkała (często odmienione), żeby zapamiętać pisownię końcówek i wymiany głosek (r → rz, k → c, g → dz, ó → o itd.). Na fiszce zobaczy tłumaczenie rosyjskie i będzie musiała napisać z pamięci właśnie TĘ formę.
        Pozycje (forma; w nawiasie kwadratowym forma podstawowa podana przez uczennicę, jeśli jest):
        \(list)
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
        """
    }

    /// TZ 1, 4.2: words from photos of notes or a textbook page.
    static func photo(mode: PhotoMode) -> String {
        let modeLine: String
        switch mode {
        case .highlighted:
            modeLine = "Wypisz TYLKO polskie słowa i frazy wyróżnione: podkreślone, zakreślone, zaznaczone markerem, wypisane na marginesie."
        case .all:
            modeLine = "Wypisz wszystkie polskie słowa i frazy, które wyglądają na słownictwo do nauki (pomiń całe zdania z ćwiczeń, numery, nagłówki)."
        }
        return """
        Na zdjęciu (zdjęciach) są notatki lub strona z podręcznika do nauki polskiego. Uczennica mówi po rosyjsku.
        Tryb: \(modeLine)
        Zasady:
        - Przepisz każdą pozycję DOKŁADNIE tak, jak jest napisana: ta sama forma (przypadek, osoba, czas) i ten sam zapis, nawet z błędem. Niczego nie poprawiaj i nie sprowadzaj do formy podstawowej.
        - Jeśli obok jest rosyjskie tłumaczenie, wpisz je do "ru". Jeśli obok jest forma podstawowa (np. w nawiasie), wpisz ją do "base".
        - Rosyjskich słów nie traktuj jako pozycji.
        - "confidence": "high" albo "low" (nieczytelne pismo, niepewne litery). Niepewne litery zaznacz w "pl" jako [?].
        - Bez powtórzeń.
        Odpowiedz tylko JSON: {"items":[{"pl":"","ru":"","base":"","confidence":"high"}]}
        """
    }

    /// TZ 2, 4.1: a text on a topic at the chosen level.
    static func generate(topic: String, kind: TextKind, level: CEFRLevel, myWords: [String]) -> String {
        var lines = [
            "Jesteś autorem tekstów do nauki języka polskiego jako obcego. Czytelniczka mówi po rosyjsku.",
            "Napisz tekst na temat: „\(sanitize(topic))”. Temat może być podany po rosyjsku — tekst i tytuł pisz zawsze po polsku.",
            "Rodzaj tekstu: \(kind.promptName).",
        ]
        if kind == .dialogue {
            lines.append("Każda kwestia dialogu to osobny akapit, który zaczyna się od myślnika (—).")
        }
        lines.append("Poziom: \(level.rawValue). Trzymaj się ściśle tego profilu poziomu:")
        lines.append(level.profile)
        if !myWords.isEmpty {
            lines.append("Wpleć naturalnie te słowa (możesz je odmieniać): \(myWords.map(sanitize).joined(separator: ", ")).")
        }
        lines.append("Tekst ma być spójny, ciekawy, z realiami życia w Polsce. Bez tłumaczenia i komentarzy w tekście.")
        lines.append("Odpowiedz tylko JSON:")
        lines.append(#"{"title":"tytuł po polsku","paragraphs":["akapit 1","akapit 2"],"keyWords":[{"form":"forma jak w tekście","base":"forma podstawowa","ru":"перевод этой формы"}],"usedMyWords":["..."]}"#)
        lines.append("\"keyWords\": 5–8 najprzydatniejszych słów lub kolokacji z tego tekstu dla poziomu \(level.rawValue), w formie DOKŁADNIE jak w tekście.")
        lines.append(myWords.isEmpty
            ? "\"usedMyWords\": []."
            : "\"usedMyWords\": słowa z podanej listy, które pojawiły się w tekście — w formie DOKŁADNIE jak w tekście.")
        return lines.joined(separator: "\n")
    }

    /// TZ 2, 4.2: a word or phrase translated in the context of its sentence.
    static func translate(selection: String, sentence: String, title: String) -> String {
        var lines: [String] = []
        if !title.trimmed.isEmpty {
            lines.append("Tytuł tekstu: „\(sanitize(title))”")
        }
        lines += [
            "Kontekst (zdanie z tekstu): „\(sentence.collapsingWhitespace)”",
            "Przetłumacz na rosyjski polskie słowo lub frazę: „\(selection.collapsingWhitespace)” — dokładnie w tej formie i w tym znaczeniu, w jakim występuje w tym zdaniu.",
            "W \"ru\" oddaj tę konkretną formę; jeśli z rosyjskiego tłumaczenia nie da się odgadnąć formy, dodaj w nawiasie krótką wskazówkę po rosyjsku, np. „врача (род./вин. п.)”.",
            "Odpowiedz tylko JSON:",
            #"{"ru":"перевод этой формы в этом контексте","base":"forma podstawowa","pos":"część mowy po rosyjsku","form":"forma gramatyczna po polsku, np. Msc. l.poj.","alternation":"wymiana głosek względem formy podstawowej albo \"\"","note":"krótka uwaga po rosyjsku, jeśli znaczenie w tym kontekście jest nietypowe, albo \"\"","sentence_ru":"перевод всего предложения на русский"}"#,
        ]
        return lines.joined(separator: "\n")
    }

    /// One line, no quote marks that would break the „…” framing, bounded length.
    static func sanitize(_ text: String) -> String {
        let cleaned = text.collapsingWhitespace.filter { !"„”\"".contains($0) }
        return String(cleaned.prefix(200))
    }
}
