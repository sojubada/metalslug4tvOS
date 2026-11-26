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

# 프레임을 잘라서는 안 되는 것들 (배경 타일·단일 이미지)
NO_SPLIT = {"Ground_Tile", "BG_Far", "Boss_Tank", "Boss_Damaged", "Bunker", "Idle"}


def route(filename):
    stem = re.sub(r"[^a-z0-9]+", " ", os.path.splitext(filename)[0].lower())
    for pattern, folder, name in ROUTES:
        if re.search(pattern, stem):
            return folder, name
    return "_unsorted", os.path.splitext(filename)[0]


def to_transparent(img):
    """밝은 배경과 체크무늬 배경을 투명으로."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    # 네 모서리 색을 배경 후보로 본다
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if r > 236 and g > 236 and b > 236:          # 흰 배경
                px[x, y] = (0, 0, 0, 0)
                continue
            for cr, cg, cb, ca in corners:               # 체크무늬 등 단색 배경
                if ca and abs(r - cr) < 10 and abs(g - cg) < 10 and abs(b - cb) < 10:
                    px[x, y] = (0, 0, 0, 0)
                    break
    # 반투명 가장자리 제거 — 도트는 알파가 0 아니면 255여야 깔끔하다
    alpha = img.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    img.putalpha(alpha)
    return img


def split_frames(img, min_gap=4):
    """완전히 빈 세로줄을 경계로 프레임을 나눈다. 행이 여러 줄이면 먼저 가로로 나눈다."""
    def slices(mask, length, getter):
        runs, start = [], None
        for i in range(length):
            filled = getter(i)
            if filled and start is None:
                start = i
            elif not filled and start is not None:
                runs.append((start, i))
                start = None
        if start is not None:
            runs.append((start, length))
        return [r for r in runs if r[1] - r[0] >= min_gap]

    a = img.getchannel("A")
    w, h = img.size
    cols = a.load()
    row_runs = slices(None, h, lambda y: any(cols[x, y] for x in range(w)))
    frames = []
    for y0, y1 in row_runs:
        band = img.crop((0, y0, w, y1))
        ba = band.getchannel("A").load()
        bw, bh = band.size
        col_runs = slices(None, bw, lambda x: any(ba[x, y] for y in range(bh)))
        for x0, x1 in col_runs:
            f = band.crop((x0, 0, x1, bh))
            if f.getbbox():
                frames.append(f.crop(f.getbbox()))
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
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.15)
    q = rgb.quantize(colors=colors, dither=Image.NONE).convert("RGBA")
    q.putalpha(img.getchannel("A"))
    return q


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("indir")
    ap.add_argument("--out", default="image")
    ap.add_argument("--tone", type=float, default=1.55, help="채도 배율 (1.0 = 원본)")
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
        src = to_transparent(Image.open(os.path.join(args.indir, fn)))
        if not src.getbbox():
            print(f"  ! {fn}: 내용이 비어 있다 (배경 제거가 과했을 수 있음)")
            continue

        if name in NO_SPLIT:
            frames = [src.crop(src.getbbox())]
        else:
            frames = split_frames(src) or [src.crop(src.getbbox())]

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
