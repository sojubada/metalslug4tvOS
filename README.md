# MetalSlug tvOS 16.6 — Pure Original Edition (`metalslug-tvos-original`)

tvOS 16.6 (A15 / TrollStore 환경) 실기기용 **순수 오리지널 메탈슬러그 2D 런앤건(그래픽 향상만 적용)** 버전입니다.
조준 각도 선택 UI, 자동 락온, 십자 과녁, 교육 요소를 **전부 제거**하여 본연의 아케이드 게임성을 그대로 유지하고, 고해상도 그래픽 향상만 적용했습니다.

## 주요 특징
- **순수 오리지널 게임성**: 각도 스냅·자동 락온·십자 과녁·각도 표기 전부 삭제. 정면 사격 및 위 방향키(`Up`) 입력 시 상단 사격의 원작 조작 그대로 유지
- **그래픽 향상 전용**: `100%`(1080p) / `150%`(1620p) / `200%`(4K 2160p) 렌더 스케일(`R` 키) 및 리마스터 티어(1x/2x), 다층 사막 노을 배경, 선명한 아케이드 예광탄(`drawCrispBullets:`), 55인치 4K / 3m 고시인성 HUD
- **tvOS 16.6 제약 준수**: 2,097MB 메모리 상한 가드(`safe_mode_fallback`), `NSUserDefaults` 16바이트 설정 저장, GitHub Actions(`macos-15` + Xcode 16 + XcodeGen) `.ipa` 자동 릴리즈
- **교육 버전과 동시 설치 가능**: 독립 Bundle ID (`com.tvos166.metalslug.original`)

## 조작법 (블루투스 키보드 / 게임패드 / Siri Remote)
- 이동: `A`/`D` 또는 좌/우 화살표, 게임패드 D-Pad/좌스틱
- 위 조준 (누른 채 사격 시 상단 발사): `위` 화살표, 게임패드 D-Pad Up
- 점프: `W`, `Space`, 게임패드 `A`
- 사격: `J`, `Z`, Siri Remote `Select`, 게임패드 `X` / `R2`
- 수류탄: `K`, `X`, 게임패드 `B`
- 슬러그 탑승/하차: `E`, `Enter`, 게임패드 `Y`
- 해상도 배율 순환 (`100%` → `150%` → `200%`): `R`
- 일시정지: `P`, `ESC`, Siri Remote `Play/Pause`
