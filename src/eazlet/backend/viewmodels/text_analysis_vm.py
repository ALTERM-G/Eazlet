import re
from collections import Counter
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication

from .base_vm import BaseVM


class TextAnalysisVM(BaseVM):
    inputChanged = Signal()
    modeChanged = Signal()
    analysisChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()

    WORD_RE = re.compile(r"[^\W_]+(?:['’\-][^\W_]+)*", re.UNICODE)
    SENTENCE_RE = re.compile(r"[^.!?]+[.!?]+|[^.!?]+$", re.UNICODE)
    TOKEN_RE = re.compile(r"\S+")

    SAMPLE_TEXT = (
        "Clear writing is not about using big words. It is about helping readers "
        "understand an idea quickly and remember it.\n\n"
        "Good text has a purpose, a natural rhythm, and enough detail to be useful "
        "without becoming noisy. Short sentences make complex ideas easier to follow. "
        "Long sentences can work too, but they need structure, momentum, and a clear "
        "destination so the reader never loses the thread.\n\n"
        "Read your draft aloud, cut what does not help, and keep the words that do. "
        "The result is usually shorter, sharper, and easier to trust."
    )

    STOP_WORDS = frozenset(
        {
            "a", "about", "above", "after", "again", "against", "all", "am",
            "an", "and", "any", "are", "as", "at", "be", "because", "been",
            "before", "being", "below", "between", "both", "but", "by", "can",
            "could", "did", "do", "does", "doing", "down", "during", "each",
            "few", "for", "from", "further", "had", "has", "have", "having",
            "he", "her", "here", "hers", "herself", "him", "himself", "his",
            "how", "i", "if", "in", "into", "is", "it", "its", "itself",
            "just", "me", "more", "most", "my", "myself", "no", "nor", "not",
            "now", "of", "off", "on", "once", "only", "or", "other", "our",
            "ours", "ourselves", "out", "over", "own", "same", "she", "should",
            "so", "some", "such", "than", "that", "the", "their", "theirs",
            "them", "themselves", "then", "there", "these", "they", "this",
            "those", "through", "to", "too", "under", "until", "up", "very",
            "was", "we", "were", "what", "when", "where", "which", "while",
            "who", "whom", "why", "will", "with", "would", "you", "your",
            "yours", "yourself", "yourselves",
        }
    )

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._input = ""
        self._mode = "text"
        self._has_results = False
        self._status = "Waiting for text"
        self._error = ""
        self._stats: list[dict] = []
        self._top_words: list[dict] = []
        self._top_word_max = 0
        self._word_lengths: list[dict] = []
        self._word_length_max = 0
        self._character_composition: list[dict] = []
        self._character_total = 0
        self._longest_words: list[dict] = []
        self._readability_label = ""
        self._insights: list[str] = []
        self._report_text = ""

    @Property(str, notify=inputChanged)
    def input(self):
        return self._input

    @input.setter
    def input(self, value):
        if value != self._input:
            self._input = value
            self.inputChanged.emit()

    @Property(str, notify=modeChanged)
    def mode(self):
        return self._mode

    @Slot(str)
    def setMode(self, value):
        normalized = "code" if value == "code" else "text"
        if normalized != self._mode:
            self._mode = normalized
            self.modeChanged.emit()
            if self._input.strip():
                self.process()

    @Property(bool, notify=analysisChanged)
    def hasResults(self):
        return self._has_results

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=errorChanged)
    def error(self):
        return self._error

    @Property(list, notify=analysisChanged)
    def stats(self):
        return self._stats

    @Property(list, notify=analysisChanged)
    def topWords(self):
        return self._top_words

    @Property(int, notify=analysisChanged)
    def topWordMax(self):
        return self._top_word_max

    @Property(list, notify=analysisChanged)
    def wordLengths(self):
        return self._word_lengths

    @Property(int, notify=analysisChanged)
    def wordLengthMax(self):
        return self._word_length_max

    @Property(list, notify=analysisChanged)
    def characterComposition(self):
        return self._character_composition

    @Property(int, notify=analysisChanged)
    def characterTotal(self):
        return self._character_total

    @Property(list, notify=analysisChanged)
    def longestWords(self):
        return self._longest_words

    @Property(str, notify=analysisChanged)
    def readabilityLabel(self):
        return self._readability_label

    @Property(list, notify=analysisChanged)
    def insights(self):
        return self._insights

    @Property(str, notify=analysisChanged)
    def reportText(self):
        return self._report_text

    @staticmethod
    def _count_syllables(word: str) -> int:
        cleaned = re.sub(r"[^a-z]", "", word.lower())
        if not cleaned:
            return 0
        vowels = "aeiouy"
        count = 0
        previous_was_vowel = False
        for char in cleaned:
            is_vowel = char in vowels
            if is_vowel and not previous_was_vowel:
                count += 1
            previous_was_vowel = is_vowel
        if cleaned.endswith("e") and count > 1 and not cleaned.endswith(("le", "ye")):
            count -= 1
        return max(1, count)

    @staticmethod
    def _format_duration(seconds: float) -> str:
        if seconds < 60:
            return f"{max(1, round(seconds))} sec"
        minutes = seconds / 60
        if minutes < 60:
            return f"{minutes:.1f} min"
        hours = int(minutes // 60)
        remaining = int(minutes % 60)
        return f"{hours}h {remaining}m"

    @staticmethod
    def _describe_readability(score: float) -> str:
        if score >= 90:
            return "Very easy"
        if score >= 80:
            return "Easy"
        if score >= 70:
            return "Fairly easy"
        if score >= 60:
            return "Standard"
        if score >= 50:
            return "Fairly difficult"
        if score >= 30:
            return "Difficult"
        return "Very difficult"

    def _clear_analysis(self) -> None:
        self._has_results = False
        self._stats = []
        self._top_words = []
        self._top_word_max = 0
        self._word_lengths = []
        self._word_length_max = 0
        self._character_composition = []
        self._character_total = 0
        self._longest_words = []
        self._readability_label = ""
        self._insights = []
        self._report_text = ""

    @Slot()
    def process(self):
        self._error = ""
        self.errorChanged.emit()
        text = self._input.strip()
        if not text:
            self._clear_analysis()
            self.analysisChanged.emit()
            self._status = "Nothing to analyze"
            self.statusChanged.emit()
            return

        if self._mode == "code":
            self._process_code(text)
        else:
            self._process_text(text)

    def _process_text(self, text):
        words = self.WORD_RE.findall(text)
        if not words:
            self._clear_analysis()
            self.analysisChanged.emit()
            self._status = "Failed"
            self.statusChanged.emit()
            self._error = "No words found in the input"
            self.errorChanged.emit()
            return

        lower_words = [word.lower() for word in words]
        unique_words = set(lower_words)
        word_count = len(words)
        sentence_parts = [
            part.strip() for part in self.SENTENCE_RE.findall(text) if part.strip()
        ]
        sentence_count = max(1, len(sentence_parts))
        paragraph_parts = [
            part.strip() for part in re.split(r"\n\s*\n", text) if part.strip()
        ]
        paragraph_count = max(1, len(paragraph_parts))

        character_count = len(text)
        syllable_count = sum(self._count_syllables(word) for word in words)
        average_word_length = sum(len(word) for word in words) / word_count
        average_sentence_length = word_count / sentence_count
        lexical_diversity = len(unique_words) / word_count * 100
        reading_seconds = word_count / 200 * 60
        speaking_seconds = word_count / 130 * 60

        readability_score = 206.835 - 1.015 * average_sentence_length
        readability_score -= 84.6 * (syllable_count / word_count)
        readability_score = max(0.0, min(100.0, readability_score))
        self._readability_label = self._describe_readability(readability_score)

        self._stats = [
            {"label": "Words", "value": f"{word_count:,}"},
            {"label": "Characters", "value": f"{character_count:,}"},
            {"label": "Sentences", "value": f"{sentence_count:,}"},
            {"label": "Paragraphs", "value": f"{paragraph_count:,}"},
            {"label": "Unique words", "value": f"{len(unique_words):,}"},
            {"label": "Lexical diversity", "value": f"{lexical_diversity:.1f}%"},
            {"label": "Avg word length", "value": f"{average_word_length:.1f}"},
            {"label": "Avg sentence length", "value": f"{average_sentence_length:.1f}"},
            {"label": "Syllables", "value": f"{syllable_count:,}"},
            {"label": "Reading time", "value": self._format_duration(reading_seconds)},
            {"label": "Speaking time", "value": self._format_duration(speaking_seconds)},
            {"label": "Readability", "value": f"{readability_score:.0f}"},
        ]

        content_words = [
            word for word in lower_words if word not in self.STOP_WORDS and len(word) > 1
        ]
        if not content_words:
            content_words = lower_words
        top_counts = Counter(content_words).most_common(10)
        self._top_words = [
            {"word": word, "count": count} for word, count in top_counts
        ]
        self._top_word_max = top_counts[0][1] if top_counts else 0

        length_counts = Counter(len(word) for word in words)
        max_length = max(length_counts, default=1)
        upper_length = min(max_length, 12)
        self._word_lengths = [
            {"length": str(length), "count": length_counts.get(length, 0)}
            for length in range(1, upper_length + 1)
        ]
        if max_length > 12:
            self._word_lengths.append(
                {
                    "length": "13+",
                    "count": sum(
                        count
                        for length, count in length_counts.items()
                        if length > 12
                    ),
                }
            )
        self._word_length_max = max(
            (item["count"] for item in self._word_lengths), default=0
        )

        letters = sum(1 for char in text if char.isalpha())
        digits = sum(1 for char in text if char.isdigit())
        whitespace = sum(1 for char in text if char.isspace())
        other = character_count - letters - digits - whitespace
        self._character_composition = [
            {"name": "Letters", "value": letters},
            {"name": "Digits", "value": digits},
            {"name": "Whitespace", "value": whitespace},
            {"name": "Punctuation", "value": other},
        ]
        self._character_total = character_count

        seen_words = set()
        longest_words: list[dict] = []
        for word in sorted(set(words), key=lambda item: (-len(item), item.lower())):
            key = word.lower()
            if key in seen_words:
                continue
            seen_words.add(key)
            longest_words.append({"word": word, "length": len(word)})
            if len(longest_words) == 6:
                break
        self._longest_words = longest_words

        insights: list[str] = []
        insights.append(
            f"Readability is {self._describe_readability(readability_score).lower()} "
            f"(score {readability_score:.0f}/100)."
        )
        if average_sentence_length >= 25:
            insights.append(
                f"Sentences are long at {average_sentence_length:.1f} words on average; "
                "splitting some may improve clarity."
            )
        elif average_sentence_length <= 10:
            insights.append(
                f"Sentences are short at {average_sentence_length:.1f} words on average; "
                "the text reads quickly."
            )
        else:
            insights.append(
                f"Average sentence length is {average_sentence_length:.1f} words, "
                "which is comfortable for most readers."
            )
        if lexical_diversity >= 60:
            insights.append(
                f"Vocabulary is varied: {lexical_diversity:.0f}% of words are unique."
            )
        elif lexical_diversity <= 35:
            insights.append(
                f"Vocabulary repeats often: only {lexical_diversity:.0f}% of words are unique."
            )
        else:
            insights.append(
                f"Vocabulary is balanced: {lexical_diversity:.0f}% of words are unique."
            )
        if top_counts:
            top_word, top_count = top_counts[0]
            insights.append(
                f"Most frequent meaningful word: “{top_word}” ({top_count}×)."
            )
        if longest_words:
            insights.append(
                f"Longest word: “{longest_words[0]['word']}” "
                f"({longest_words[0]['length']} letters)."
            )
        if reading_seconds < 60:
            insights.append(
                f"About {max(1, round(reading_seconds))} seconds to read, "
                f"{max(1, round(speaking_seconds))} seconds to speak."
            )
        else:
            insights.append(
                f"About {self._format_duration(reading_seconds)} to read, "
                f"{self._format_duration(speaking_seconds)} to speak."
            )
        self._insights = insights

        top_lines = ", ".join(
            f"{item['word']} ({item['count']})" for item in self._top_words[:5]
        )
        report_lines = [
            "Text Analysis Report",
            "",
            f"Words: {word_count:,}",
            f"Characters: {character_count:,}",
            f"Sentences: {sentence_count:,}",
            f"Paragraphs: {paragraph_count:,}",
            f"Unique words: {len(unique_words):,}",
            f"Lexical diversity: {lexical_diversity:.1f}%",
            f"Average word length: {average_word_length:.1f}",
            f"Average sentence length: {average_sentence_length:.1f}",
            f"Syllables: {syllable_count:,}",
            f"Reading time: {self._format_duration(reading_seconds)}",
            f"Speaking time: {self._format_duration(speaking_seconds)}",
            f"Readability: {readability_score:.0f}/100 "
            f"({self._describe_readability(readability_score)})",
            "",
            f"Top words: {top_lines or 'none'}",
            f"Longest words: {', '.join(item['word'] for item in longest_words) or 'none'}",
            "",
            "Insights:",
        ]
        report_lines.extend(f"- {insight}" for insight in insights)
        self._report_text = "\n".join(report_lines)

        self._has_results = True
        self.analysisChanged.emit()
        self._status = "Analysis complete"
        self.statusChanged.emit()

    def _process_code(self, text):
        tokens = self.TOKEN_RE.findall(text)
        character_count = len(text)
        line_count = text.count("\n") + 1
        token_count = len(tokens)
        unique_tokens = len(set(tokens))

        letters = sum(1 for char in text if char.isalpha())
        digits = sum(1 for char in text if char.isdigit())
        whitespace = sum(1 for char in text if char.isspace())
        symbols = character_count - letters - digits - whitespace

        self._readability_label = "N/A (code / unusual)"

        avg_token_length = (sum(len(t) for t in tokens) / token_count) if token_count else 0.0
        self._stats = [
            {"label": "Characters", "value": f"{character_count:,}"},
            {"label": "Lines", "value": f"{line_count:,}"},
            {"label": "Tokens", "value": f"{token_count:,}"},
            {"label": "Unique tokens", "value": f"{unique_tokens:,}"},
            {"label": "Letters", "value": f"{letters:,}"},
            {"label": "Digits", "value": f"{digits:,}"},
            {"label": "Whitespace", "value": f"{whitespace:,}"},
            {"label": "Symbols", "value": f"{symbols:,}"},
            {"label": "Avg token length", "value": f"{avg_token_length:.1f}"},
        ]

        top_counts = Counter(tokens).most_common(10)
        self._top_words = [{"word": tok, "count": count} for tok, count in top_counts]
        self._top_word_max = top_counts[0][1] if top_counts else 0

        lengths = [len(t) for t in tokens] or [0]
        length_counts = Counter(lengths)
        max_length = max(length_counts, default=1)
        upper_length = min(max_length, 12)
        self._word_lengths = [
            {"length": str(length), "count": length_counts.get(length, 0)}
            for length in range(1, upper_length + 1)
        ]
        if max_length > 12:
            self._word_lengths.append(
                {
                    "length": "13+",
                    "count": sum(c for l, c in length_counts.items() if l > 12),
                }
            )
        self._word_length_max = max((item["count"] for item in self._word_lengths), default=0)

        self._character_composition = [
            {"name": "Letters", "value": letters},
            {"name": "Digits", "value": digits},
            {"name": "Whitespace", "value": whitespace},
            {"name": "Symbols", "value": symbols},
        ]
        self._character_total = character_count

        seen = set()
        longest_words: list[dict] = []
        for tok in sorted(set(tokens), key=lambda item: (-len(item), item)):
            if tok in seen:
                continue
            seen.add(tok)
            longest_words.append({"word": tok, "length": len(tok)})
            if len(longest_words) == 6:
                break
        self._longest_words = longest_words

        insights: list[str] = []
        if character_count:
            letter_pct = letters / character_count * 100
            digit_pct = digits / character_count * 100
            symbol_pct = symbols / character_count * 100
            insights.append(
                f"Composition: {letter_pct:.0f}% letters, {digit_pct:.0f}% digits, "
                f"{symbol_pct:.0f}% symbols/other."
            )
        insights.append(f"{line_count:,} line(s), {token_count:,} token(s), {unique_tokens:,} unique.")
        if top_counts:
            insights.append(f"Most frequent token: “{top_counts[0][0]}” ({top_counts[0][1]}×).")
        if longest_words:
            insights.append(
                f"Longest token: “{longest_words[0]['word']}” ({longest_words[0]['length']} chars)."
            )
        if token_count == 0:
            insights.append("Input contains only whitespace.")
        self._insights = insights

        top_lines = ", ".join(f"{i['word']} ({i['count']})" for i in self._top_words[:5])
        report_lines = [
            "Text Analysis Report (code / unusual)",
            "",
            f"Characters: {character_count:,}",
            f"Lines: {line_count:,}",
            f"Tokens: {token_count:,}",
            f"Unique tokens: {unique_tokens:,}",
            f"Letters: {letters:,}",
            f"Digits: {digits:,}",
            f"Whitespace: {whitespace:,}",
            f"Symbols: {symbols:,}",
            f"Avg token length: {avg_token_length:.1f}",
            "",
            f"Top tokens: {top_lines or 'none'}",
            f"Longest tokens: {', '.join(i['word'] for i in longest_words) or 'none'}",
            "",
            "Insights:",
        ]
        report_lines.extend(f"- {insight}" for insight in insights)
        self._report_text = "\n".join(report_lines)

        self._has_results = True
        self.analysisChanged.emit()
        self._status = "Analysis complete"
        self.statusChanged.emit()

    @Slot()
    def clear(self):
        self._input = ""
        self.inputChanged.emit()
        self._clear_analysis()
        self.analysisChanged.emit()
        self._error = ""
        self.errorChanged.emit()
        self._status = "Waiting for text"
        self.statusChanged.emit()

    @Slot()
    def loadSample(self):
        self._input = self.SAMPLE_TEXT
        self.inputChanged.emit()
        self.process()
        if self._has_results:
            self._status = "Sample loaded"
            self.statusChanged.emit()

    @Slot(str)
    def loadFile(self, path):
        self._error = ""
        self.errorChanged.emit()

        raw = (path or "").strip()
        if raw.startswith("file:"):
            local = QUrl(raw).toLocalFile()
            if local:
                raw = local
        if not raw:
            self._error = "No file selected"
            self.errorChanged.emit()
            self._status = "Nothing loaded"
            self.statusChanged.emit()
            return

        file_path = Path(raw)
        suffix = file_path.suffix.lower()
        if suffix not in {".txt", ".md", ".markdown"}:
            self._error = (
                f"Unsupported file type: {suffix or 'unknown'} "
                "(open a .txt or .md file)"
            )
            self.errorChanged.emit()
            self._status = "Nothing loaded"
            self.statusChanged.emit()
            return

        try:
            text = file_path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            self._error = f"Could not read {file_path.name}: {exc}"
            self.errorChanged.emit()
            self._status = "Nothing loaded"
            self.statusChanged.emit()
            return

        self._input = text
        self.inputChanged.emit()
        self.process()
        if self._has_results:
            self._status = f"Loaded {file_path.name}"
            self.statusChanged.emit()

    @Slot()
    def copyReport(self):
        if not self._report_text:
            self._status = "Nothing to copy"
            self.statusChanged.emit()
            return
        app = QGuiApplication.instance()
        clipboard = app.clipboard() if app is not None else None
        if clipboard is None:
            self._status = "Clipboard unavailable"
            self.statusChanged.emit()
            return
        clipboard.setText(self._report_text)
        self._status = "Report copied to clipboard"
        self.statusChanged.emit()
