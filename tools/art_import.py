#!/usr/bin/env python3
"""생성한 스프라이트 PNG를 게임에 쓸 수 있는 형태로 정리한다.

  python3 tools/art_import.py <입력폴더> [--out image] [--tone 1.55] [--height 128]

하는 일
  1) 흰 배경·체크무늬 배경을 투명으로 바꾸고 반투명 가장자리를 제거한다
  2) 내용 영역만 잘라낸다
  3) 가로로 이어진 시트를 프레임 단위로 쪼갠다 (완전히 빈 세로줄을 경계로 삼음)
  4) 모든 프레임을 같은 칸 크기로 맞추고 발바닥(내용 하단)을 한 줄에 정렬한다
  5) 채도·대비를 아케이드용으로 올리고 팔레트를 줄인다
  6) 낱장 프레임 + 합친 아틀라스 + 좌표 JSON 을 내보낸다

파일 이름의 낱말로 저장 위치를 정한다. 모르는 이름은 _unsorted 로 간다.
"""
import argparse
import json
import os
import re
import sys

from PIL import Image, ImageEnhance

# 파일 이름 낱말 → image/ 아래 경로
ROUTES = [
    (r"boss.*cannon|cannon.*boss",      "Character/Boss",            "Boss_Cannon"),
    (r"boss.*damag|damag.*boss",        "Character/Boss",            "Boss_Damaged"),
    (r"boss",                           "Character/Boss",            "Boss_Tank"),
    (r"grenad",                         "Character/Enemy/Soldier",   "Grenadier"),
    (r"para|chute",                     "Character/Enemy/Soldier",   "Paratrooper"),
    (r"enemy.*death|soldier.*death",    "Character/Enemy/Soldier",   "Soldier_Death"),
    (r"enemy.*attack|soldier.*attack",  "Character/Enemy/Soldier",   "Soldier_Attack"),
    (r"enemy|soldier",                  "Character/Enemy/Soldier",   "Soldier_Run"),
    (r"tread|track",                    "Character/Enemy/Vehicle",   "Tank_Tread"),
    (r"tank",                           "Character/Enemy/Vehicle",   "Tank"),
    (r"heli|chopper",                   "Character/Enemy/Vehicle",   "Heli"),
    (r"slug|apc|armor",                 "Vehicle/Player",            "Slug"),
    (r"idle|wait|stand",                "Character/Player",          "Idle"),
    (r"run|walk",                       "Character/Player",          "Run"),
    (r"jump",                           "Character/Player",          "Jump"),
    (r"fire|shoot|attack",              "Character/Player",          "Fire"),
    (r"hit|death|die",                  "Character/Player",          "Hit"),
    (r"explo",                          "WeaponSFX",                 "Explosion"),
    (r"muzzle|flash",                   "WeaponSFX",                 "Muzzle"),
    (r"bullet|projectile",              "WeaponSFX",                 "Bullets"),
    (r"smoke|dust",                     "WeaponSFX",                 "Smoke"),
    (r"impact|spark",                   "WeaponSFX",                 "Impact"),
    (r"item|pickup",                    "Item",                      "Items"),
    (r"hostage|prisoner",               "Item",                      "Hostage"),
    (r"digit|number",                   "UI",                        "Font_Numbers"),
    (r"letter|alphabet|font",           "UI",                        "Font_Letters"),
    (r"hud.*icon|icon",                 "UI",                        "HUD_Icons"),
    (r"hud|interface",                  "UI",                        "HUD_Frame"),
    (r"ground|tile",                    "Map",                       "Ground_Tile"),
    (r"far|ridge|mountain",             "Map",                       "BG_Far"),
    (r"mid|prop",                       "Map",                       "BG_Mid"),
    (r"bunker",                         "Map",                       "Bunker"),
]

# 각 시트에 들어 있는 프레임 수. 프롬프트에서 "균등 간격"을 요구했으므로
# 알파 간격 탐지보다 균등 분할이 훨씬 안정적이다. 1 = 단일 스프라이트.
FRAMES = {
    "Idle": 1, "Run": 6, "Jump": 3, "Fire": 4, "Hit": 4,
    "Soldier_Run": 4, "Soldier_Attack": 3, "Soldier_Death": 4,
    "Grenadier": 3, "Paratrooper": 2,
    "Tank": 1, "Tank_Tread": 2, "Heli": 2, "Slug": 1,
    "Boss_Tank": 1, "Boss_Damaged": 1, "Boss_Cannon": 1,
    "Explosion": 6, "Muzzle": 3, "Bullets": 4, "Smoke": 5, "Impact": 4,
    "Items": 8, "Hostage": 3,
    "Ground_Tile": 1, "BG_Far": 1, "BG_Mid": 6, "Bunker": 1,
    "Font_Numbers": 10, "Font_Letters": 26, "HUD_Frame": 1, "HUD_Icons": 5,
}


def route(filename):
    stem = re.sub(r"[^a-z0-9]+", " ", os.path.splitext(filename)[0].lower())
    for pattern, folder, name in ROUTES:
        if re.search(pattern, stem):
            return folder, name
    return "_unsorted", os.path.splitext(filename)[0]


def to_transparent(img, tol=20):
    """배경을 투명으로. 테두리에서 흘려보내며(flood fill) 지우므로
    흰 배경, 단색 배경, 생성 모델이 투명을 뜻해 그려 넣는 체크무늬를 모두 처리한다.
    안쪽의 흰 하이라이트는 테두리와 이어져 있지 않으므로 살아남는다."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    # 테두리에 많이 보이는 색을 배경색 후보로 모은다 (체크무늬는 두 가지)
    counts = {}
    border = [(x, y) for x in range(w) for y in (0, h - 1)]
    border += [(x, y) for y in range(h) for x in (0, w - 1)]
    for x, y in border:
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        k = (r // 12, g // 12, b // 12)
        counts[k] = counts.get(k, 0) + 1
    if not counts:
        return img
    total = sum(counts.values())
    bg = [k for k, n in counts.items() if n >= total * 0.10][:4]
    if not bg:
        return img
    bg = [(k[0] * 12 + 6, k[1] * 12 + 6, k[2] * 12 + 6) for k in bg]

    def is_bg(c):
        return any(abs(c[0] - b[0]) <= tol and abs(c[1] - b[1]) <= tol
                   and abs(c[2] - b[2]) <= tol for b in bg)

    seen = bytearray(w * h)
    stack = [p for p in border]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        r, g, b, a = px[x, y]
        if a != 0 and not is_bg((r, g, b)):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    # 2차 제거 — 테두리에서 닿지 않는 안쪽 체크무늬 조각(다리 사이, 칸 안쪽 등)을
    # 지운다. 배경색과 같으면서 덩어리가 큰 것만 지우므로 헬멧 하이라이트 같은
    # 작은 흰 점은 살아남는다.
    seen2 = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if seen2[sy * w + sx]:
                continue
            r, g, b, a = px[sx, sy]
            if a == 0 or not is_bg((r, g, b)):
                seen2[sy * w + sx] = 1
                continue
            blob, stack = [], [(sx, sy)]
            seen2[sy * w + sx] = 1
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen2[ny * w + nx]:
                        rr, gg, bb, aa = px[nx, ny]
                        if aa != 0 and is_bg((rr, gg, bb)):
                            seen2[ny * w + nx] = 1
                            stack.append((nx, ny))
            if len(blob) >= 200:
                for x, y in blob:
                    px[x, y] = (0, 0, 0, 0)

    alpha = img.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    img.putalpha(alpha)
    return img


def strip_guides(img, max_thickness=16, fill_ratio=0.82):
    """생성 모델이 베이스라인 표시로 그려 넣는 가로 전체 선을 지운다.
    이 선을 남겨두면 프레임이 서로 이어져 분할이 되지 않는다."""
    w, h = img.size
    a = img.getchannel("A").load()
    filled = [sum(1 for x in range(w) if a[x, y]) / w for y in range(h)]
    px = img.load()
    y = 0
    while y < h:
        if filled[y] >= fill_ratio:
            y2 = y
            while y2 < h and filled[y2] >= fill_ratio:
                y2 += 1
            if y2 - y <= max_thickness:
                for yy in range(y, y2):
                    for x in range(w):
                        px[x, yy] = (0, 0, 0, 0)
            y = y2
        else:
            y += 1
    return img


def despeckle(img, min_ratio=0.0008):
    """배경을 걷어낸 뒤 남는 자잘한 찌꺼기를 지운다.
    이걸 안 하면 찌꺼기가 프레임으로 잡혀 분할이 엉망이 된다."""
    w, h = img.size
    a = img.getchannel("A").load()
    seen = bytearray(w * h)
    px = img.load()
    min_px = max(12, int(w * h * min_ratio))
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or not a[sx, sy]:
                continue
            blob, stack = [], [(sx, sy)]
            seen[sy * w + sx] = 1
            while stack:
                x, y = stack.pop()
                blob.append((x, y))
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and a[nx, ny]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if len(blob) < min_px:
                for x, y in blob:
                    px[x, y] = (0, 0, 0, 0)
    return img


def split_frames(img, count):
    """내용 영역을 가로로 count등분한다. 각 칸은 다시 내용만큼 잘라낸다."""
    box = img.getbbox()
    if not box:
        return []
    img = img.crop(box)
    if count <= 1:
        return [img]
    w, h = img.size
    step = w / count
    frames = []
    for i in range(count):
        cell = img.crop((round(i * step), 0, round((i + 1) * step), h))
        b = cell.getbbox()
        frames.append(cell.crop(b) if b else cell)
    return frames


def normalize(frames, cell_h, baseline_pad=0):
    """같은 칸 크기로 맞추고 내용 하단(발바닥)을 한 줄에 정렬한다."""
    scale = cell_h / max(f.height for f in frames)
    scaled = [f.resize((max(1, round(f.width * scale)), max(1, round(f.height * scale))),
                       Image.LANCZOS) for f in frames]
    cell_w = max(f.width for f in scaled)
    out = []
    for f in scaled:
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        canvas.alpha_composite(f, ((cell_w - f.width) // 2, cell_h - f.height - baseline_pad))
        a = canvas.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        canvas.putalpha(a)
        out.append(canvas)
    return out


def grade(img, sat, colors):
    """채도만 가볍게 올리고 색 수를 줄인다. 밝기는 생성 단계에서 잡는다 —
    여기서 밝기를 끌어올리면 검은 외곽선이 들뜨고 색이 분필처럼 바랜다."""
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
    q = rgb.quantize(colors=colors, dither=Image.NONE).convert("RGBA")
    q.putalpha(img.getchannel("A"))
    return q


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("indir")
    ap.add_argument("--out", default="image")
    ap.add_argument("--tone", type=float, default=1.20, help="채도 배율 (1.0 = 원본)")
    ap.add_argument("--height", type=int, default=128, help="캐릭터 프레임 높이(px)")
    ap.add_argument("--colors", type=int, default=24)
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(args.indir)
                   if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
    if not files:
        print("입력 폴더에 이미지가 없다:", args.indir)
        return 1

    manifest = {}
    for fn in files:
        folder, name = route(fn)
        src = strip_guides(to_transparent(Image.open(os.path.join(args.indir, fn))))
        if not src.getbbox():
            print(f"  ! {fn}: 내용이 비어 있다 (배경 제거가 과했을 수 있음)")
            continue

        src = despeckle(src)
        if not src.getbbox():
            print(f"  ! {fn}: 정리 후 내용이 남지 않았다")
            continue
        frames = split_frames(src, FRAMES.get(name, 1))

        cell_h = args.height if folder.startswith(("Character", "Vehicle")) else \
            min(args.height, max(f.height for f in frames))
        frames = normalize(frames, cell_h)
        if args.tone != 1.0:
            frames = [grade(f, args.tone, args.colors) for f in frames]

        dest = os.path.join(args.out, folder, name)
        os.makedirs(dest, exist_ok=True)
        for i, f in enumerate(frames):
            f.save(os.path.join(dest, f"{name}_{i:02d}.png"))

        cw, ch = frames[0].size
        atlas = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            atlas.alpha_composite(f, (i * cw, 0))
        atlas_path = os.path.join(args.out, folder, f"{name}.png")
        atlas.save(atlas_path)

        manifest[f"{folder}/{name}"] = {
            "atlas": atlas_path, "frames": len(frames),
            "cell_w": cw, "cell_h": ch, "source": fn,
        }
        print(f"  {fn}  ->  {atlas_path}  ({len(frames)}프레임 {cw}x{ch})")

    with open(os.path.join(args.out, "sprites.json"), "w") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
    print(f"\n{len(manifest)}개 항목 정리 완료 -> {args.out}/sprites.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
