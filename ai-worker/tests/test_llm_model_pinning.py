"""Every Claude call must go through _CLAUDE_MODEL.

The model string used to be written out at each call site. When
claude-3-5-sonnet-latest was retired, only one of them was updated, so the
fallback 404'd for place matching and the pros/cons summary -- and nothing
caught it, because the tests mock the Anthropic client and a mock answers
to any model name at all.

This reads the source instead, which is the only place the mistake is
visible.
"""

import re
from pathlib import Path

LLM_SERVICE = Path(__file__).resolve().parents[1] / "app" / "services" / "llm_service.py"


def test_no_call_site_hardcodes_a_claude_model():
    source = LLM_SERVICE.read_text(encoding="utf-8")

    hardcoded = re.findall(r'model\s*=\s*"(claude[^"]*)"', source)

    assert hardcoded == [], (
        "Claude model names belong in _CLAUDE_MODEL, not at the call site: "
        f"{hardcoded}"
    )


def test_every_anthropic_call_passes_the_shared_model():
    source = LLM_SERVICE.read_text(encoding="utf-8")

    # One per `_anthropic_client.messages.create(` in the file.
    call_count = source.count("_anthropic_client.messages.create(")
    shared_model_uses = source.count("model=_CLAUDE_MODEL")

    assert call_count > 0, "no Anthropic calls found -- has the client been renamed?"
    assert shared_model_uses == call_count, (
        f"{call_count} Anthropic calls but {shared_model_uses} use _CLAUDE_MODEL"
    )
