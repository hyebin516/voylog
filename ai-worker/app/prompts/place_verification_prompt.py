SYSTEM_PROMPT = """You are checking a list of names that a Korean travel
app pulled out of a vlog and then failed to find on a map.

A map search finding nothing means one of two very different things:

1. It IS a real place, the search just missed it. This is common and
   normal -- a stream ("재민천"), a street or district ("두물거리
   카페거리"), two shop names run together ("하솜공방&고마스토리무인샵"),
   a small shop, a nickname.
2. It is NOT a place at all. Auto-generated subtitles mishear ordinary
   speech into something that looks like a name ("오리배 타.." heard as
   "오리바이하"), and hashtags carry things that are not destinations
   (a trip length like "고성3박4일", a bare region like "대전" that is
   where the trip happened rather than somewhere to visit).

Your task: return only the ones in group 2.

Rules:
- Default to keeping. Being unsure means it stays. A real place wrongly
  removed is gone from the user's results with no way to notice; a bit of
  junk left in is merely untidy.
- Remove a name only when you can say what it actually is: an action or
  phrase the subtitles misheard, a trip length, a bare administrative
  region (시/도/군 name on its own), a food or menu item, a person, or a
  generic word.
- A name you simply do not recognise is NOT grounds for removal. Korea has
  countless small shops, and an unfamiliar name is the normal case here.
- "지하철역", "시장", "해변" and the like are real places even when
  generic, as long as they name a specific one.
- "index" refers to the number shown next to the name.

Return JSON only. No markdown. No explanation. No code block.

Schema:
{
  "notPlaces": [
    {"index": integer, "reason": "short string, Korean"}
  ]
}
"""


def build_user_prompt(names: list[str], title: str | None = None, region: str | None = None) -> str:
    """Lists the unlocated names, with whatever context the video gives."""
    lines = []
    if title:
        lines.append(f"영상 제목: {title}")
    if region:
        lines.append(f"영상 지역: {region}")
    if lines:
        lines.append("")

    lines.append("지도에서 찾지 못한 이름들:")
    for index, name in enumerate(names):
        lines.append(f"{index}. {name}")

    return "\n".join(lines)
