import re
from collections import Counter

from PySide6.QtCore import Property, QObject, Signal, Slot

from .base_vm import BaseVM


class TextAnalysisVM(BaseVM):
    inputChanged = Signal()
    analysisChanged = Signal()
    statusChanged = Signal()
    errorChanged = Signal()

    WORD_RE = re.compile(r"[^\W_]+(?:['’\-][^\W_]+)*", re.UNICODE)
    SENTENCE_RE = re.compile(r"[^.!?]+[.!?]+|[^.!?]+$", re.UNICODE)

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

    @Property(str, notify=inputChanged)
    def input(self):
        return self._input

    @input.setter
    def input(self, value):
        if value != self._input:
            self._input = value
            self.inputChanged.emit()

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
