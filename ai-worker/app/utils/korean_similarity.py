"""Sound-alike comparison for Korean names.

Speech recognition mishears a syllable's vowel or final consonant far more
often than a whole syllable ("소베" -> "소배", "보흔바" -> "보음바"), so names
are compared letter by letter after splitting each Hangul syllable into its
jamo (초성/중성/종성). Two names a syllable apart at the jamo level are
still close; two different words are not.
"""

import re

_HANGUL_BASE = 0xAC00
_HANGUL_LAST = 0xD7A3
_JUNGSEONG_COUNT = 21
_JONGSEONG_COUNT = 28

_WORD_PATTERN = re.compile(r"[0-9A-Za-z가-힣]{2,}")


def _jamo(text: str) -> list[str]:
    letters = []
    for char in text:
        code = ord(char)
        if _HANGUL_BASE <= code <= _HANGUL_LAST:
            offset = code - _HANGUL_BASE
            initial = offset // (_JUNGSEONG_COUNT * _JONGSEONG_COUNT)
            medial = (offset // _JONGSEONG_COUNT) % _JUNGSEONG_COUNT
            final = offset % _JONGSEONG_COUNT
            letters.append(f"i{initial}")
            letters.append(f"m{medial}")
            if final:
                letters.append(f"f{final}")
        elif not char.isspace():
            letters.append(char.lower())
    return letters


def _edit_distance(a: list[str], b: list[str]) -> int:
    previous = list(range(len(b) + 1))
    for i, letter_a in enumerate(a, start=1):
        current = [i]
        for j, letter_b in enumerate(b, start=1):
            current.append(
                min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (letter_a != letter_b))
            )
        previous = current
    return previous[-1]


def sound_similarity(a: str, b: str) -> float:
    """1.0 for identical jamo, falling toward 0 as more letters differ."""
    jamo_a, jamo_b = _jamo(a), _jamo(b)
    longest = max(len(jamo_a), len(jamo_b))
    if longest == 0:
        return 0.0
    return 1 - _edit_distance(jamo_a, jamo_b) / longest


def similar_written_words(heard_name: str, written_text: str, threshold: float = 0.7, limit: int = 3) -> list[str]:
    """Words in `written_text` that sound like `heard_name` but aren't it,
    most similar first."""
    heard = heard_name.replace(" ", "")
    scored = {}
    for word in _WORD_PATTERN.findall(written_text or ""):
        if word == heard or word in scored:
            continue
        score = sound_similarity(heard, word)
        if score >= threshold:
            scored[word] = score
    return [word for word, _ in sorted(scored.items(), key=lambda item: item[1], reverse=True)[:limit]]


def _core_name(name: str) -> str:
    """The name without branch words ("현대백화점", "대구점") and spacing or
    punctuation, lowercased."""
    tokens = (name or "").split()
    kept = [token for token in tokens if not (len(tokens) > 1 and len(token) >= 2 and token.endswith("점"))]
    return re.sub(r"[^0-9a-z가-힣]", "", " ".join(kept or tokens).lower())


def _longest_common_substring(a: str, b: str) -> int:
    best = 0
    previous = [0] * (len(b) + 1)
    for char_a in a:
        current = [0] * (len(b) + 1)
        for j, char_b in enumerate(b, start=1):
            if char_a == char_b:
                current[j] = previous[j - 1] + 1
                best = max(best, current[j])
        previous = current
    return best


def names_plausibly_same(searched_name: str, map_name: str) -> bool:
    """Whether a map result's name could be the place that was searched for.
    Guards the LLM's candidate pick, which accepted "보카바카 현대백화점
    대구점" (a clothing store) for a shop called "vaca". True when the names
    share a run of at least half the shorter name ("남산서울타워" /
    "N서울타워 ", "몬도 카츠" / "몬도카츠 범어점") or sound nearly the same."""
    a, b = _core_name(searched_name), _core_name(map_name)
    if not a or not b:
        return False
    shorter = min(len(a), len(b))
    if _longest_common_substring(a, b) >= max(2, -(-shorter // 2)):
        return True
    return sound_similarity(a, b) >= 0.7
