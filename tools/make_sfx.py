#!/usr/bin/env python3
"""아케이드풍 효과음을 합성해 WAV 로 쓴다 (표준 라이브러리만 사용).

  python3 tools/make_sfx.py assets/sfx

녹음 자료를 쓰지 않고 파형을 직접 만든다 — 잡음 버스트에 포락선을 씌우고
톤을 섞는 방식이라 8비트 게임기 소리에 가깝게 나온다.
"""
import array
import math
import os
import random
import struct
import sys

RATE = 22050


def write_wav(path, samples):
    """16비트 모노 WAV."""
    data = array.array("h", (max(-32767, min(32767, int(s * 32767))) for s in samples))
    raw = data.tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(raw)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(raw)) + raw)


def env(i, n, attack=0.005, decay=1.0, curve=2.0):
    """0→1 로 빠르게 올랐다가 곡선으로 떨어지는 포락선."""
    t = i / n
    a = min(1.0, t / max(1e-6, attack))
    d = max(0.0, 1.0 - t / decay) ** curve
    return a * d


def noise(n, seed=1):
    rnd = random.Random(seed)
    return [rnd.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(buf, cut):
    """한 극 저역통과. cut 이 작을수록 둔탁해진다."""
    out, prev = [], 0.0
    for s in buf:
        prev += cut * (s - prev)
        out.append(prev)
    return out


def shoot():
    """소총 발사 — 짧은 잡음 탁음에 하강 톤을 얹는다."""
    n = int(RATE * 0.11)
    nz = lowpass(noise(n, 7), 0.45)
    out = []
    for i in range(n):
        e = env(i, n, 0.002, 1.0, 2.6)
        tone = math.sin(2 * math.pi * (760 - 560 * i / n) * i / RATE)
        out.append((nz[i] * 0.75 + tone * 0.35) * e * 0.55)
    return out


def grenade_throw():
    n = int(RATE * 0.18)
    return [math.sin(2 * math.pi * (300 + 520 * i / n) * i / RATE)
            * env(i, n, 0.01, 1.0, 1.6) * 0.32 for i in range(n)]


def explosion():
    """폭발 — 둔탁한 잡음에 저주파 쿵 소리를 섞는다."""
    n = int(RATE * 0.75)
    nz = lowpass(noise(n, 11), 0.10)
    nz2 = lowpass(noise(n, 23), 0.30)
    out = []
    for i in range(n):
        e = env(i, n, 0.004, 1.0, 1.9)
        boom = math.sin(2 * math.pi * (110 - 70 * i / n) * i / RATE)
        out.append((nz[i] * 0.85 + nz2[i] * 0.3 + boom * 0.55) * e * 0.72)
    return out


def jump():
    n = int(RATE * 0.16)
    return [(1.0 if math.sin(2 * math.pi * (330 + 430 * i / n) * i / RATE) > 0 else -1.0)
            * env(i, n, 0.006, 1.0, 2.2) * 0.26 for i in range(n)]


def hit():
    """피격 — 거친 잡음에 하강 사각파."""
    n = int(RATE * 0.26)
    nz = lowpass(noise(n, 31), 0.25)
    out = []
    for i in range(n):
        e = env(i, n, 0.003, 1.0, 1.7)
        sq = 1.0 if math.sin(2 * math.pi * (420 - 300 * i / n) * i / RATE) > 0 else -1.0
        out.append((nz[i] * 0.5 + sq * 0.5) * e * 0.5)
    return out


def pickup():
    """아이템 — 두 음 상승 아르페지오."""
    n = int(RATE * 0.22)
    out = []
    for i in range(n):
        f = 660 if i < n * 0.45 else 990
        out.append(math.sin(2 * math.pi * f * i / RATE) * env(i, n, 0.005, 1.0, 1.1) * 0.3)
    return out


def slug_board():
    """장갑차 탑승 — 묵직한 금속음."""
    n = int(RATE * 0.35)
    nz = lowpass(noise(n, 41), 0.18)
    out = []
    for i in range(n):
        e = env(i, n, 0.004, 1.0, 1.5)
        out.append((nz[i] * 0.6 + math.sin(2 * math.pi * 150 * i / RATE) * 0.5) * e * 0.45)
    return out


def game_over():
    """하강 3음."""
    n = int(RATE * 0.9)
    out = []
    for i in range(n):
        t = i / n
        f = 440 if t < 0.33 else (330 if t < 0.66 else 220)
        out.append(math.sin(2 * math.pi * f * i / RATE) * env(i, n, 0.01, 1.0, 0.8) * 0.3)
    return out


SFX = {
    "shoot": shoot, "grenade": grenade_throw, "explosion": explosion,
    "jump": jump, "hit": hit, "pickup": pickup,
    "slug": slug_board, "gameover": game_over,
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/sfx"
    os.makedirs(out, exist_ok=True)
    for name, fn in SFX.items():
        path = os.path.join(out, f"{name}.wav")
        write_wav(path, fn())
        print(f"  {name}.wav  {os.path.getsize(path)//1024}KB")
    print(f"{len(SFX)}개 생성 -> {out}")


if __name__ == "__main__":
    main()
