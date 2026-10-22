# 릴리스 빌드 (Voylog)

스토어에 올릴 수 있는 서명된 빌드를 만드는 절차. 서버 배포는 별개다
(`../docs/DEPLOYMENT.md`).

## 이미 되어 있는 것

| 항목 | 값 |
| --- | --- |
| 앱 표시 이름 | Voylog |
| Android `applicationId` / iOS Bundle ID | `com.luckyvicky.voylog` |
| `targetSdk` / `minSdk` | 36 / 24 (Flutter 3.44 기본값, Play 요구치 충족) |
| 런처 아이콘 | `flutter_launcher_icons`로 생성됨 (적응형 아이콘 포함) |
| 버전 | `pubspec.yaml`의 `version: 1.0.0+1` — `1.0.0`이 versionName, `+1`이 versionCode |

## 1. 업로드 키스토어 만들기 (최초 1회)

`keytool`은 Android Studio에 딸려 온다. Git Bash에서:

```bash
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" \
  -genkeypair -v \
  -keystore "$HOME/voylog-upload-keystore.jks" \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias voylog
```

비밀번호를 두 번(키스토어/키) 묻고 이름·조직 등을 묻는다. 이름 항목은 비워도
되고, 마지막 확인에 `y`를 입력하면 만들어진다. `-validity 10000`은 약 27년으로,
Play가 요구하는 "2033년 이후까지 유효"를 넘긴다.

**저장소 안에 두지 않는다.** `.gitignore`가 `*.jks`를 막고는 있지만, 애초에
바깥에 두는 편이 안전하다.

**이 파일과 비밀번호를 잃어버리면 같은 앱의 업데이트를 올릴 수 없다.** 서버
인증키(`.pem`)를 보관한 곳에 같이 백업해 둘 것.

## 2. `android/key.properties`

키스토어를 만든 뒤 이 파일을 만든다 (git에 올라가지 않는다):

```properties
storePassword=<키스토어 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=voylog
storeFile=C:/Users/<사용자>/voylog-upload-keystore.jks
```

경로는 **슬래시(`/`)** 로 쓴다 — `.properties` 파일에서 역슬래시는 이스케이프
문자다.

이 파일이 없으면 릴리스 빌드는 **디버그 키로 서명되고**(Play가 거부한다)
빌드 로그에 경고 한 줄이 남는다. 조용히 넘어가지 않게 하려고 넣어둔 경고다.

## 3. 빌드

```bash
flutter build appbundle --release    # Play 스토어 업로드용 .aab
flutter build apk --release          # 기기에 직접 설치해 볼 .apk
```

결과물:
- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

서명이 제대로 들어갔는지 확인:

```bash
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" \
  -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

소유자(Owner)가 1번에서 입력한 정보면 된다. `Android Debug`로 나오면 아직
디버그 키다.

## 4. 카카오 개발자 콘솔에 릴리스 키 해시 등록

디버그 키 해시만 등록돼 있으면 **릴리스 빌드에서 카카오 로그인이 실패한다.**
릴리스 키의 해시를 뽑아서 추가 등록해야 한다:

```bash
"/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" \
  -exportcert -alias voylog -keystore "$HOME/voylog-upload-keystore.jks" \
  | openssl sha1 -binary | openssl base64
```

나온 값을 Kakao Developers → 내 애플리케이션 → 플랫폼 → Android → 키 해시에
**추가**한다(디버그 해시는 지우지 말 것, 개발 중에 계속 쓴다). 자세한 내용은
[KAKAO_SETUP.md](KAKAO_SETUP.md).

Play 스토어에 올릴 때 **Play 앱 서명**을 쓰면 구글이 자체 서명 키를 따로
가지므로, 그 키의 SHA-1에서 뽑은 해시도 같이 등록해야 한다(Play Console →
설정 → 앱 서명에서 확인).

## 5. iOS

맥과 Apple Developer 계정이 필요하다. 이 저장소의 개발 머신은 Windows라
**iOS 릴리스 빌드는 검증된 적이 없다** — `ios/Runner/Info.plist`의 ATS 설정
(평문 HTTP 제한)도 빌드로 확인하지 못했다.

## 6. 올리기 전 확인

- `travel_youtube_app/.env`의 `API_BASE_URL`이 운영 서버(HTTPS)를 가리키는지
- 서버가 켜져 있는지 (`curl https://<도메인>/health`)
- 개인정보처리방침 URL (`../docs/PRIVACY_POLICY.md`) — Play 등록 시 필수
