# MacCat 배포

공개 저장소: https://github.com/jhaemin/MacCat

## GitHub Actions secrets

| 이름 | 값 |
| --- | --- |
| `DEVELOPER_ID_P12` | 개인 Developer ID Application 인증서와 개인 키를 담은 P12의 base64 |
| `DEVELOPER_ID_P12_PASSWORD` | P12 내보내기 암호 |
| `NOTARY_KEY_P8` | App Store Connect API 키의 P8 원문 |
| `NOTARY_KEY_ID` | API 키 ID |
| `NOTARY_ISSUER_ID` | API 키 issuer UUID |
| `SPARKLE_ED_PRIVATE_KEY` | MacCat 전용 Sparkle Ed25519 개인 키의 base64 텍스트 |

개인 Apple Developer 팀 `TA74GWSAB2`의 배포 인증서만 허용합니다. 태그 릴리스는 위 값이 모두 있어야 진행됩니다. 키·암호·P12는 저장소에 커밋하지 않습니다.

Sparkle 공개 키는 `Scripts/Info.plist`의 `SUPublicEDKey`에 있습니다. 개인 키는 macOS 키체인의 `dev.jhaemin.MacCat` 계정과 Apple Developer 폴더의 `MacCat/Sparkle.private` 백업으로 보관합니다. 이후 버전에서도 같은 키를 사용해야 기존 설치가 업데이트를 신뢰할 수 있습니다.

## 새 버전 배포

1. `CHANGELOG.md`와 `CHANGELOG.ko.md`에 `## 1.0.1` 같은 섹션을 추가하고 `Scripts/Info.plist`의 개발 버전도 맞춥니다.
2. 변경을 `main`에 커밋하고 푸시합니다.
3. Actions의 **Release → Run workflow**로 사전 검증합니다. 수동 실행은 다운로드 가능한 빌드 아티팩트만 만들며 릴리스나 피드는 공개하지 않습니다. 인증서가 없으면 로컬 검증용 ad-hoc 빌드만 생성합니다.
4. 검증 후 태그를 푸시합니다.

```sh
git tag v1.0.1
git push origin v1.0.1
```

CI가 마케팅 버전은 태그에서, 내부 빌드 번호는 `GITHUB_RUN_NUMBER`에서 가져옵니다. 서명된 Universal 앱을 공증·스테이플링하고 Gatekeeper 검사를 통과한 뒤 `MacCat.zip`을 공개합니다. ZIP의 Sparkle 서명이 앱에 내장된 공개 키와 일치하는지도 검사합니다.

다운로드가 공개된 다음 `main`의 `appcast.xml`을 봇 커밋으로 갱신합니다. 이후 로컬에서는 `git pull --ff-only`로 피드 커밋을 받아주세요. 릴리스 작업은 동시에 실행되지 않으며, 임시 인증서·키체인은 성공 여부와 관계없이 정리합니다.

## 업데이트

피드: https://raw.githubusercontent.com/jhaemin/MacCat/main/appcast.xml

앱은 새 버전을 자동 확인하고 Sparkle 표준 UI로 설치를 안내합니다. 메뉴의 **업데이트 확인…**으로 즉시 확인할 수도 있습니다. 자동 확인과 무인 설치는 별개이며, 설치는 Sparkle의 사용자 설정을 따릅니다.

Sparkle 프레임워크와 내부 헬퍼를 앱에 포함하고 안쪽부터 차례로 서명합니다. 개발용 ad-hoc 빌드는 hardened runtime을 사용하지 않고, 배포용 빌드는 hardened runtime과 secure timestamp를 적용합니다. [Sparkle 배포 문서](https://sparkle-project.org/documentation/publishing/)를 참고하세요.
