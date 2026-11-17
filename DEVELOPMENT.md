# MacCat 개발


Swift 5.9 이상의 Xcode Command Line Tools가 필요합니다. Sparkle 의존성은 SwiftPM으로 설치됩니다.

```sh
swift build
swift test
bash Scripts/bundle.sh --open
```

`build/MacCat.app`이 생성됩니다. 응용 프로그램 폴더에 복사하면 메뉴에서 로그인 자동 실행을 설정할 수 있습니다. 기본 빌드는 로컬용 ad-hoc 서명입니다. `CODESIGN_IDENTITY`로 배포 인증서를 지정하고 `UNIVERSAL=1`로 두 아키텍처를 빌드할 수 있습니다. 공개 릴리스는 CI에서 Developer ID 서명과 Apple 공증을 거칩니다.

```sh
swift run MacCat
"$(swift build --show-bin-path)/MacCat" --render-previews build/previews
```

렌더링 명령은 모든 고양이의 PNG, 전체 디자인 모음, 동작별 자세 모음, 앱 아이콘을 만듭니다.

걷기 원화와 실제 앱 렌더러의 재생 결과를 확인합니다. 생성 프롬프트는 `Assets/illustration-prompts.txt`에 있습니다.

```sh
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
"$BIN_DIR/MacCat" --render-motion build/motion-comparison
ffmpeg -framerate 60 -i build/motion-comparison/frame-%03d.png \
  -c:v libx264 -pix_fmt yuv420p build/motion-comparison.mp4
"$BIN_DIR/MacCat" --measure-animation   # 실제 240회 화면 갱신 측정 후 종료
```

## 구조

- `CatDesign.swift`: 8종의 색상·이름, 크기와 산책 설정
- `CatRenderer.swift`: PNG 아틀라스 캐시, 프레임 렌더링, 알파 기반 클릭 영역
- `FrameSampling.swift`: 원래 걷기 8장과 휴식 자세 선택
- `IllustrationScale.swift`: 고양이별 원화의 머리 크기를 기준으로 자세 배율 보정
- `Resources/PawCorrections/`: 복숭아 걷기 두 자세의 뒷발 수정 원화 (`Assets/paw-correction-prompt.txt`)
- `Resources/Cats/`: 앱에 포함되는 투명 배경 손그림풍 고양이 아틀라스 8종
- `Motion.swift`: 화면 경계, 이동 가감속, 행동 전환, 드래그 및 쓰다듬기 상태
- `CatPanel.swift`: 투명 패널, 캐릭터 영역 입력 처리
- `GalleryView.swift`: 고양이 선택 화면
- `AppDelegate.swift`: 메뉴 막대, 디스플레이 동기화, 화면 변경·잠자기 대응
- `DevTools.swift`: 디자인·동작·앱 아이콘 렌더링
- `UpdaterController.swift`: Sparkle 자동 업데이트 및 수동 확인 메뉴

