#!/bin/bash
# 지은 앱을 가짜 서명해 IPA 로 묶는다.
#   package_ipa.sh <출력.ipa> <보일 이름> <빌드 번호>
set -e
OUT="$1"; DISPLAY="$2"; RUN="$3"

APP_PATH="$(find build/Build/Products -maxdepth 3 -name 'MetalSlugOriginal.app' -type d 2>/dev/null | head -n 1)"
if [ -z "$APP_PATH" ]; then
  echo "Could not find MetalSlugOriginal.app"
  find . -maxdepth 6 -name '*.app' -type d -print
  exit 1
fi
echo "App: $APP_PATH"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RUN" "$APP_PATH/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $RUN" "$APP_PATH/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY" "$APP_PATH/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $DISPLAY" "$APP_PATH/Info.plist"

# TrollStore 설치용 가짜 서명. 정보 파일을 고친 뒤에 서명한다.
ldid -S "$APP_PATH/MetalSlugOriginal"

rm -rf Payload "$OUT"
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry "$OUT" Payload
rm -rf Payload
ls -lh "$OUT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist" 2>/dev/null || echo 1.0)"
echo "IPA_VERSION=$VERSION" >> "$GITHUB_ENV"
