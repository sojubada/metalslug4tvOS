# 그림 생성 프롬프트 모음 (image/ 폴더 전체)

Google AI Studio 등 이미지 생성 모델에 그대로 붙여 넣는 영어 프롬프트다.
모두 **오리지널 디자인**을 만드는 프롬프트이며, 원작에서 추출한 스프라이트를
참조 이미지로 넣지 않는다. 화풍(두꺼운 검은 외곽선, 네오지오풍 제한 팔레트,
사막 군사 배경)은 저작권 대상이 아니므로 이어받아도 된다.

생성 결과는 `image/` 아래 지정된 경로에 그대로 넣으면 된다.
투명화·크롭·축소·팔레트 정리·프레임 분할은 빌드 파이프라인이 처리한다.

---

## 0. 공통 규칙

모든 프롬프트 끝에 이 블록을 붙인다.

```
Pixel art, 16-bit Neo Geo arcade run-and-gun style: thick black outlines,
flat cel shading, limited saturated palette, crisp pixel edges, no
anti-aliasing, no blur, no gradient mesh.
Transparent background. No text, no logo, no watermark, no frame borders,
no numbers, no drop shadow.
Do NOT depict Marco Rossi, Tarma, Eri, Fio, or any existing Metal Slug
character, vehicle, or logo. Original designs only.
```

**시트로 뽑을 때 반드시 들어가야 하는 두 줄**

```
All frames the same height, feet aligned on the same baseline.
Evenly spaced in ONE horizontal row, no separators between frames.
```

이게 빠지면 프레임마다 발 높이가 달라져 달릴 때 캐릭터가 위아래로 튄다.

**캐릭터 일관성** — 2번 이후의 모든 캐릭터 프롬프트는 **1-1에서 만든 기준
이미지를 첨부한 채로** 돌린다. 첨부 없이 새로 뽑으면 얼굴·장비가 매번 달라진다.

```
Using the attached character as the exact reference — same face, same
helmet, same bandana, same uniform and palette — redraw him in: [포즈]
Keep identical art style, pixel resolution, outline weight, and palette.
```

**해상도** — 단일 포즈 2048x2048, 6프레임 시트 3072x512, 차량 2048x1024.
게임 안에서 병사는 화면 높이의 약 14%(1080p에서 128px)로 축소되므로
얼굴 주름 같은 세부는 사라진다. 실루엣이 분명한 쪽이 유리하다.

---

## 1. image/Character/Player/

플레이어 병사. **1-1을 먼저 뽑고, 그 결과를 나머지 전부의 기준 이미지로 쓴다.**

### 1-1. Idle.png — 기준 포즈 (최우선)

```
An ORIGINAL soldier character of my own design. Rugged bearded veteran,
olive-green combat uniform, steel helmet with goggles pushed up, blue
bandana under the helmet, chest webbing, ammo pouches, knee pads, black
combat boots. Holding an assault rifle at hip level pointed right.
Full body, side view facing right, standing idle.
```

### 1-2. Run.png — 달리기 6프레임

```
SPRITE SHEET of one complete run cycle, 6 frames in one horizontal row:
contact (right leg forward extended, left leg back) / passing (legs
crossing, left knee raised) / push-off (left leg extended back) / contact
opposite / passing opposite / push-off opposite.
Body leaning slightly forward, rifle held at hip, facing right.
```

### 1-3. Jump.png — 점프 3프레임

```
SPRITE SHEET, 3 frames in one horizontal row: crouching to launch /
airborne with both knees tucked toward chest / landing crouch with
knees bent. Facing right.
```

### 1-4. Fire.png — 사격 4프레임

```
SPRITE SHEET, 4 frames in one horizontal row: firing the rifle forward
with a bright yellow-white muzzle flash and slight recoil lean / recoil
recovery / firing the rifle straight up at the sky, arms raised vertically,
muzzle flash above / lowering the rifle. Facing right.
```

### 1-5. Hit.png — 피격·사망 4프레임

```
SPRITE SHEET, 4 frames in one horizontal row: hit reaction leaning back
with arms flung out / staggering backward / falling to one knee / lying
collapsed on the ground. Facing right. No blood, no gore.
```

---

## 2. image/Character/Enemy/Soldier/

### 2-1. Soldier_Run.png — 적 보병 달리기 4프레임

```
An ORIGINAL enemy soldier of my own design, DIFFERENT from the attached
player character: dark red-brown uniform, black peaked cap instead of a
helmet, clean-shaven, lighter build, carrying a short submachine gun.
Same art style, same outline weight, same pixel scale as the attached
reference, same body proportions.
SPRITE SHEET, 4 frames in one horizontal row: a run cycle, facing left.
```

### 2-2. Soldier_Attack.png — 적 보병 사격 3프레임

```
Same enemy soldier. SPRITE SHEET, 3 frames in one horizontal row:
raising the gun / firing with muzzle flash, facing left / recoil.
```

### 2-3. Soldier_Death.png — 적 보병 사망 4프레임

```
Same enemy soldier. SPRITE SHEET, 4 frames in one horizontal row:
hit reaction / stumbling backward / falling / lying flat on the ground.
No blood, no gore.
```

### 2-4. Grenadier.png — 수류탄병 3프레임

```
Same enemy faction, but a heavier soldier with a helmet and a satchel of
grenades. SPRITE SHEET, 3 frames in one horizontal row: crouching /
winding up to throw / releasing the grenade. Facing left.
```

### 2-5. Paratrooper.png — 낙하산병 2프레임 + 낙하산

```
Same enemy soldier hanging from an ORIGINAL round parachute canopy,
dark red-brown with pale stripes, suspension lines clearly drawn.
SPRITE SHEET, 2 frames in one horizontal row: descending with legs
dangling / landing with the canopy collapsing behind him.
```

---

## 3. image/Character/Enemy/Vehicle/

### 3-1. Tank.png — 적 전차

```
An ORIGINAL military tank design, side view facing LEFT. Boxy riveted
hull, rounded turret, long cannon barrel, heavy segmented tracks with
five road wheels, exhaust stack at the rear. Desert tan and gunmetal
palette with dark red-brown faction markings.
Single sprite, no crew visible.
```

### 3-2. Tank_Tread.png — 궤도 2프레임

```
Only the track assembly of the attached tank, cropped: two frames in one
horizontal row showing the track links shifted by half a link, so the
pair loops as a moving tread animation. Same scale as the reference.
```

### 3-3. Heli.png — 공격헬기 2프레임

```
An ORIGINAL attack helicopter, side view facing LEFT. Stubby armored
fuselage, bubble canopy, weapon pods on short stub wings, skids, tail
boom with vertical stabilizer. Desert tan and gunmetal.
SPRITE SHEET, 2 frames in one horizontal row: main rotor blades at
different angles (one nearly edge-on, one spread wide) for a spin loop.
```

---

## 4. image/Character/Boss/

### 4-1. Boss_Tank.png — 1스테이지 보스

```
An ORIGINAL boss vehicle: a massive siege tank, side view facing LEFT,
roughly four times the size of a normal tank. Twin stacked cannons,
armored skirt over wide tracks, a reinforced command cupola on top,
heavy rivets, exhaust pipes, a glowing weak point hatch on the side.
Desert tan, gunmetal, dark red-brown markings. Menacing but readable
silhouette. Single sprite, 2048x1024.
```

### 4-2. Boss_Damaged.png — 보스 파손 상태

```
The attached boss vehicle, same pose and scale, now heavily damaged:
dented armor plates, one cannon bent, scorch marks, torn track links,
smoke vents glowing orange. Same art style and palette.
```

---

## 5. image/Vehicle/Player/

### 5-1. Slug.png — 플레이어 탑승 장갑차

```
An ORIGINAL small armored assault vehicle for the player, side view
facing RIGHT. Compact rounded hull, open-top cockpit with the driver's
head and shoulders visible, a short stubby cannon on a small turret,
four chunky road wheels with tracks, a headlight at the front.
Olive green and steel palette. Friendly, boxy, cartoon-proportioned —
wider and shorter than a real tank.
```

### 5-2. Slug_Damaged.png — 파손 상태

```
The attached vehicle, same pose and scale, damaged: dented plates,
cracked headlight, black scorch marks, thin smoke from the engine deck.
```

---

## 6. image/Item/

### 6-1. Items.png — 아이템 8종 한 줄

```
SPRITE SHEET of 8 ORIGINAL pickup items in one horizontal row, evenly
spaced, each centered in its own cell, all the same height:
1 heavy machine gun icon, 2 shotgun icon, 3 rocket launcher icon,
4 flame weapon icon, 5 grenade bundle, 6 ammo crate, 7 medical kit with
a white cross, 8 gold star bonus.
Each item drawn as a compact chunky icon with a bright rim light so it
reads against a sand-colored background.
```

### 6-2. Hostage.png — 구조 대상 3프레임

```
An ORIGINAL captured civilian engineer character: wiry old man, round
glasses, dirty beard, tattered work overalls, rope around his wrists.
SPRITE SHEET, 3 frames in one horizontal row: tied up and slumped /
freed, arms raised in cheer / running away to the right.
Comic, friendly, not distressing.
```

---

## 7. image/Map/

지형은 타일로 반복시킨다. 이음매가 맞아야 한다.

### 7-1. Ground_Tile.png — 지면 타일

```
A SEAMLESSLY TILEABLE horizontal ground strip of cracked desert hardpan:
compacted sand, pebbles, dry cracks, a darker packed layer underneath.
The LEFT and RIGHT edges must match exactly so the tile repeats without
a visible seam. Top edge is the walkable surface. 512x256.
```

### 7-2. BG_Far.png — 원경 능선

```
A SEAMLESSLY TILEABLE far-background layer: distant desert mountain
ridges and mesas in flat silhouette, two depth layers in dusty
blue-violet and muted ochre, soft haze at the base. No sky — the sky is
drawn by the engine. Left and right edges must match exactly. 2048x512.
```

### 7-3. BG_Mid.png — 중경 소품 세트

```
SPRITE SHEET of 6 ORIGINAL desert props in one horizontal row, each
centered in its own cell, all standing on a common baseline:
1 tall palm tree, 2 ruined stone archway, 3 stack of sandbags,
4 wooden watchtower, 5 rusted fuel drum, 6 wooden ammo crate.
Side view, flat shading, readable silhouettes.
```

### 7-4. Bunker.png — 벙커

```
An ORIGINAL concrete bunker emplacement, side view: sloped reinforced
concrete face, a dark horizontal firing slit, sandbag rows at the base,
a stubby ventilation pipe on top. Weathered gray concrete with sand
drifted against it.
```

---

## 8. image/UI/

### 8-1. Font_Numbers.png — 숫자 폰트

```
SPRITE SHEET of the digits 0 1 2 3 4 5 6 7 8 9 in one horizontal row,
evenly spaced, each digit the same width and height, monospaced.
Chunky arcade scoreboard lettering, bright yellow face, thick black
outline, a one-pixel white highlight along the top edge.
Readable at small size. Digits only, nothing else in the image.
```

### 8-2. Font_Letters.png — 알파벳 폰트

```
Same style as the attached digits. SPRITE SHEET of the capital letters
A to Z in TWO horizontal rows of 13, evenly spaced, monospaced, same
height as the digits. Letters only.
```

### 8-3. HUD_Frame.png — HUD 프레임

```
An ORIGINAL arcade HUD bar for the top of the screen: a dark angled
metal plate with riveted corners and a thin yellow trim line, with four
empty recessed slots for readouts. Horizontal, wide and short.
No text inside the slots. 2048x256.
```

### 8-4. HUD_Icons.png — 상태 아이콘 5종

```
SPRITE SHEET of 5 ORIGINAL HUD icons in one horizontal row, evenly
spaced, same size: 1 life/heart icon, 2 grenade icon, 3 fuel or armor
gauge icon, 4 bullet icon, 5 wrench icon. Chunky, bright, thick black
outline, readable at 32 pixels.
```

---

## 9. image/WeaponSFX/

### 9-1. Muzzle.png — 총구 화염 3프레임

```
SPRITE SHEET of a muzzle flash, 3 frames in one horizontal row:
small bright spark / full starburst with white-hot core, yellow mid and
orange edge / fading wisp. Pointing right. Nothing else in the frame.
```

### 9-2. Bullets.png — 탄환 4종

```
SPRITE SHEET of 4 ORIGINAL projectiles in one horizontal row, each
centered in its own cell, all travelling right: 1 yellow tracer streak
with a white-hot tip, 2 red-orange enemy plasma bolt, 3 grey hand
grenade with a green band, 4 small rocket with a flame tail.
```

### 9-3. Explosion.png — 폭발 6프레임

```
SPRITE SHEET of one explosion, 6 frames in one horizontal row, evenly
spaced, all frames the same size, each explosion centered in its cell:
1 white-hot flash point / 2 expanding yellow-white fireball / 3 full
orange fireball with debris chunks flying out / 4 fireball collapsing
into dark orange with rising smoke / 5 mostly grey-brown smoke with
embers / 6 thin dissipating smoke. No gore.
```

### 9-4. Smoke.png — 연기·흙먼지 5프레임

```
SPRITE SHEET of a dust puff, 5 frames in one horizontal row: a small
sand-colored burst expanding and thinning into nothing. Used for
footsteps and impacts on the ground.
```

### 9-5. Impact.png — 피탄 효과 4프레임

```
SPRITE SHEET of a bullet impact spark, 4 frames in one horizontal row:
a small white star with radiating yellow lines, expanding then fading,
with a few orange fragments. Used when a bullet hits armor.
```

---

## 10. 작업 순서 권장

1. **1-1 Idle** — 기준 이미지. 이게 마음에 들 때까지 다시 뽑는다
2. **1-2 Run** — 달리기만 들어가도 화면이 완전히 달라진다
3. **2-1 적 보병 달리기**, **9-1 총구 화염**, **9-3 폭발** — 전투가 성립한다
4. **3-1 전차**, **3-3 헬기**, **7-1 지면 타일**, **7-2 원경** — 스테이지가 채워진다
5. 나머지 (UI 폰트, 아이템, 보스, 장갑차)

1~3번까지만 나와도 빌드해서 애플TV에 올려볼 만하다.
