"""assets/icon/*.png (런처 아이콘 원본) 를 만든다.

    python tool/make_app_icon.py && dart run flutter_launcher_icons

lib/widgets/voylog_logo.dart 의 VoylogLogoMark 와 같은 그림이어야 한다 --
그라데이션(accentCyan -> primary), 모서리 반경 32%, 흰 산 글리프.
디자인 v2에서 팔레트를 블루에서 틸로 바꿨을 때 이 아이콘만 블루로 남아
있었고, 그때 쓴 스크립트는 스크래치패드에 있어 사라진 뒤였다. 그래서
저장소 안에 둔다.

필요: pillow
"""
from PIL import Image, ImageDraw

SIZE = 1024
ACCENT, PRIMARY = (0x2B, 0xB3, 0xB8), (0x15, 0x8A, 0x92)  # app_theme.dart
SS = 4  # 슈퍼샘플링 배율


def gradient(size):
    """좌상 -> 우하 선형 그라데이션."""
    image = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(image)
    for i in range(2 * size):
        t = i / (2 * size - 1)
        draw.line([(i, 0), (0, i)], fill=tuple(int(a + (b - a) * t) for a, b in zip(ACCENT, PRIMARY)))
    return image


def bezier(p0, p1, p2, p3, n=600):
    points = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        points.append((u**3*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t**3*p3[0],
                       u**3*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t**3*p3[1]))
    return points


def draw_glyph(image, box, center):
    """24x24 뷰박스의 산 글리프 (`M6 18c2-6 4-9 6-9s4 3 6 9` + 양 발과 꼭대기의 점).
    box는 뷰박스 한 변에 해당하는 픽셀 크기."""
    scale = box / 24
    ox = center[0] - 12 * scale
    oy = center[1] - 13.5 * scale  # 점 반지름까지 포함한 글리프의 세로 중심

    def pt(x, y):
        return (ox + x * scale, oy + y * scale)

    draw = ImageDraw.Draw(image)
    path = bezier(pt(6, 18), pt(8, 12), pt(10, 9), pt(12, 9)) + \
           bezier(pt(12, 9), pt(14, 9), pt(16, 12), pt(18, 18))

    # 두꺼운 선은 경로를 따라 원을 찍어서 그린다. ImageDraw.line(width=...)은
    # 꺾이는 곳마다 이음새가 벌어져 빗살 무늬가 생긴다.
    radius = 1.1 * scale  # strokeWidth 2.2의 절반
    for (x, y) in path:
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 255, 255))

    for p in (pt(6, 18), pt(12, 9), pt(18, 18)):
        r = 1.9 * scale
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255, 255))


def main():
    s = SIZE * SS

    # 전체 아이콘: 둥근 사각형 + 글리프. 글리프 크기/위치는 v1 아이콘에서
    # 실측한 값(364x294, 중심 y=547)을 그대로 따른다 -- 색만 바꾸는 작업이다.
    icon = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.32), fill=255)
    icon.paste(gradient(s), (0, 0), mask)
    draw_glyph(icon, box=553 * SS, center=(s / 2, 547 * SS))
    icon.resize((SIZE, SIZE), Image.LANCZOS).save("assets/icon/app_icon.png")

    # 적응형 배경: 꽉 찬 그라데이션 (런처가 모양을 잘라낸다)
    gradient(s).resize((SIZE, SIZE), Image.LANCZOS).save("assets/icon/app_icon_background.png")

    # 적응형 전경: 글리프만, 런처가 잘라내는 바깥 영역을 피해 작게
    foreground = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_glyph(foreground, box=434 * SS, center=(s / 2, 539 * SS))
    foreground.resize((SIZE, SIZE), Image.LANCZOS).save("assets/icon/app_icon_foreground.png")

    print("assets/icon/ 세 파일을 다시 만들었습니다. 이어서: dart run flutter_launcher_icons")


if __name__ == "__main__":
    main()
