# 테스트 가이드 (Voylog)

Voylog는 Flutter **Android/iOS 네이티브 앱**입니다. Flutter Web은 지원하지 않으며,
`package:web`/`dart:js_interop`이나 브라우저 전용 구현은 사용하지 않습니다. 지도는
`kakao_map_plugin`(`webview_flutter` 기반 네이티브 플러그인)을 통해서만 렌더링합니다.

## 테스트 두 종류

### 1. 일반 테스트 (`flutter test`) — `test/`

**대상**: 네이티브 플랫폼 채널(지도, 카카오 로그인, WebView, Secure Storage)에
의존하지 않는 모든 것.

- 순수 Dart 로직 (예: `ItineraryProvider`의 장소 선택 개수 검증)
- Provider 상태 관리 (`VideoProvider`, `BookmarkProvider`, `HotelProvider`, `ItineraryProvider`, `AuthProvider`)
- Repository 로직 (Dio 응답 → 도메인 모델 매핑)
- JSON 모델 변환 (`fromJson`)
- API 응답 파싱
- 네이티브 플러그인에 의존하지 않는 화면 위젯

지도가 등장하는 화면(`HotelSearchScreen`, `RoutePlannerScreen`, `VideoAnalysisScreen`)도
**`FakeMapRepository`를 주입하면 일반 테스트에서 검증 가능**합니다. 실제 `kakao_map_plugin`을
로드하지 않기 때문입니다.

```dart
import 'package:travel_youtube_app/repositories/map_repository.dart';
import 'fakes/fake_map_widget.dart'; // FakeMapRepository, FakeMapWidget

await tester.pumpWidget(
  MaterialApp(
    home: HotelSearchScreen(
      role: HotelSelectionRole.start,
      mapRepository: const FakeMapRepository(), // 실제 지도 대신 fake 사용
    ),
  ),
);
```

실행:

```bash
flutter test
flutter test test/home_screen_test.dart   # 특정 파일만
```

### 2. 통합 테스트 (`integration_test/`) — 실기기/에뮬레이터 전용

**대상**: 실제 네이티브 SDK 동작을 반드시 확인해야 하는 기능.

- Kakao 지도 (`KakaoMapWidget`이 실제로 WebView 안에서 Kakao Maps JS SDK를 로드하는지)
- Kakao 로그인 (연동 후)
- WebView 자체 동작
- Secure Storage 실제 읽기/쓰기
- 기타 Android/iOS 플랫폼 채널 의존 기능

실행 전 `travel_youtube_app/.env`가 있어야 합니다 (`cp .env.example .env` 후
`KAKAO_JAVASCRIPT_KEY` 채우기 — [KAKAO_SETUP.md](KAKAO_SETUP.md) 참고). 기기 하나를
반드시 지정해서 실행:

```bash
flutter devices                      # 사용 가능한 기기/에뮬레이터 목록
flutter emulators                    # 설치된 에뮬레이터 목록
flutter emulators --launch <emulator-id>

flutter test integration_test -d <device-id>
```

`integration_test/kakao_map_test.dart`는 실제 `KakaoMapWidget`을 그려서 지도가
로드되고 중심 좌표 콜백이 오는지까지 확인합니다. CI의 `flutter analyze`/`flutter test`
단계에는 포함되지 않습니다 — 반드시 기기/에뮬레이터에서 별도로 실행하세요.

## 플랫폼 의존 기능을 fake로 감싸는 규칙

새로운 네이티브 플랫폼 의존 기능(카카오 로그인 등)을 추가할 때는 이 프로젝트의
지도 처리 방식을 그대로 따르세요.

```text
lib/repositories/xxx_repository.dart   # abstract 인터페이스 (+ 실제 구현)
lib/widgets 또는 services/xxx.dart      # 실제 네이티브 SDK를 감싸는 구현체
test/fakes/fake_xxx.dart               # 테스트 전용 fake 구현체
```

화면(screen)은 생성자에서 리포지토리를 주입받고, 기본값은 실제 구현체를 쓰되
테스트에서는 fake로 교체합니다 (예: `HotelSearchScreen({this.mapRepository = const
KakaoMapRepository()})`). 화면 코드는 네이티브 SDK 타입을 절대 직접 import하지 않습니다.

## ⚠️ 현재 알려진 한계: Windows 로컬 환경에서 `flutter test` 실행 불가

이 저장소를 개발 중인 Windows 머신에서는 `flutter test`(일반 테스트 포함)를 실행하면
`flutter_tester.exe` 프로세스 자체가 네이티브 크래시(exit code `-1073740791`,
`STATUS_STACK_BUFFER_OVERRUN`)로 즉시 종료됩니다. 어떤 테스트 파일을 실행하든
(`kakao_map_plugin`을 전혀 참조하지 않는 테스트조차) 동일하게 발생합니다.

**원인 분석**:

- `flutter test`는 플랫폼에 관계없이 프로젝트의 모든 의존성 그래프에 등록된 플러그인을
  `flutter_tester`(범용 헤드리스 테스트 호스트)에 초기화하려고 시도합니다.
- `kakao_map_plugin`이 의존하는 `webview_flutter_android`, 그리고 `path_provider_android`가
  최근 버전에서 Android JNI 바인딩 패키지인 `jni`/`jni_flutter`(`dart:ffi` 기반)를 사용하는데,
  이 패키지의 네이티브 초기화가 Android가 아닌 플랫폼(Windows)의 범용 테스트 하네스에서
  크래시를 일으키는 것으로 보입니다.
- `flutter analyze`는 정적 분석이라 플러그인을 초기화하지 않으므로 영향이 없고,
  실제로 **이슈 0건으로 통과**합니다.
- `windows/`, `macos/`, `linux/`, `web/` 플랫폼 폴더를 제거해도 (이 프로젝트는 원래
  Android/iOS 전용이라 제거함) 이 크래시는 사라지지 않았습니다 — `flutter_tester`는
  특정 플랫폼 폴더에 묶여 동작하는 게 아니라 SDK에 내장된 범용 헤드리스 엔진이기
  때문입니다.
- `flutter clean` 후 재설치해도 동일하게 재현됩니다 (캐시 문제가 아님을 확인).

**검증 상태**:

| 명령어 | 결과 |
| --- | --- |
| `flutter analyze` | ✅ 통과 (이슈 0건) |
| `flutter test` (이 Windows 머신) | ❌ `flutter_tester.exe` 네이티브 크래시 |
| `flutter test` (CI: Linux/macOS 러너) | 미검증 — 이 문제는 Windows 데스크톱 테스트 하네스와
    Android 전용 JNI 플러그인 조합에서 보고되는 유형의 이슈라, Linux/macOS CI에서는
    발생하지 않을 가능성이 높습니다. |
| `flutter test integration_test -d <device>` | 미검증 — 실기기/에뮬레이터 필요 |

**권장 조치**:

1. GitHub Actions 등 Linux 기반 CI에서 `flutter test`를 실행해 실제로 통과하는지 확인
2. 로컬에서 위젯 테스트를 꼭 돌려봐야 한다면 WSL2(Linux) 환경에서 시도
3. `kakao_map_plugin`/`webview_flutter_android`/`path_provider_android`의 이후 릴리스가
   이 Windows 호환성 문제를 해결하는지 주기적으로 확인 (`flutter pub outdated`)

이 문제는 **작성된 테스트 코드나 앱 코드의 결함이 아니라, 로컬 Windows 개발 환경과
Android 전용 네이티브 플러그인 조합에서 발생하는 도구(tooling) 이슈**입니다.

## ⚠️ Windows + 한글 사용자명 환경: Android 빌드 전 필수 설정

Windows 계정 이름이 한글(또는 기타 비-ASCII 문자)이면, 기본 경로들
(`C:\Users\<한글계정명>\...`)에 의존하는 여러 네이티브 빌드 도구가 깨집니다.
**`PUB_CACHE` 하나만 옮기는 것으로는 충분하지 않습니다.** 이 프로젝트에서
실제로 확인된 두 지점은 다음과 같습니다.

1. **Pub 캐시** (`%LOCALAPPDATA%\Pub\Cache`, 기본적으로
   `C:\Users\<한글계정명>\AppData\Local\Pub\Cache`) — `jni` 패키지(native FFI,
   `path_provider_android`/`webview_flutter_android`가 사용)의 CMake/ninja
   빌드가 이 경로 안의 소스를 읽다가 실패합니다.
2. **Android SDK/NDK** (기본적으로
   `C:\Users\<한글계정명>\AppData\Local\Android\Sdk`) — `PUB_CACHE`를 옮겨도
   NDK include 경로 자체가 여전히 한글 계정 경로 밑에 있으면 ninja가 동일한
   방식으로 실패합니다 (`FindFirstFileExA` 오류 — Windows ANSI 파일 API가
   비-ASCII 경로를 못 읽어서 발생).

두 경로 모두 ASCII 전용 경로로 옮겨야 `flutter build apk`가 안정적으로
동작합니다.

### 권장 환경변수

Windows 설정 → 시스템 → 정보 → 고급 시스템 설정 → 환경 변수에서 (또는
PowerShell을 관리자 권한으로 열어 `setx`로) 아래 값을 **영구적으로** 설정하세요.

```text
PUB_CACHE=C:\pub-cache
ANDROID_HOME=C:\Android\Sdk
ANDROID_SDK_ROOT=C:\Android\Sdk
```

`ANDROID_HOME`/`ANDROID_SDK_ROOT`는 환경변수만 새로 설정한다고 되는 게
아니라, **Android SDK 자체를 그 경로로 실제로 옮기거나 새로 설치**해야
합니다:

- 이미 설치된 SDK를 그대로 옮기려면: 기존 `C:\Users\<한글계정명>\AppData\Local\Android\Sdk`
  전체를 `C:\Android\Sdk`로 복사/이동한 뒤 위 환경변수를 설정
- 또는 Android Studio → Settings → Languages & Frameworks → Android SDK Location에서
  SDK 위치를 `C:\Android\Sdk`로 새로 지정해 재설치

### Flutter에 새 SDK 위치 알려주기

환경변수만으로 충분하지 않을 때는 Flutter 설정에도 명시적으로 지정하세요.

```bash
flutter config --android-sdk "C:\Android\Sdk"
```

### 검증

```bash
flutter doctor -v          # Android SDK/NDK 위치가 새 경로로 잡혔는지 확인
flutter clean
flutter pub get
flutter build apk --debug  # jni CMake/ninja 단계까지 정상 통과해야 함
```

`flutter doctor -v`의 "Android toolchain" 항목에 새로 지정한 `C:\Android\Sdk`
경로가 나오는지 반드시 확인하세요. 여전히 기존 한글 경로가 보인다면
`ANDROID_HOME`/`ANDROID_SDK_ROOT` 환경변수가 실제로 적용됐는지(터미널을
새로 열었는지) 다시 확인하세요.

### KGP(Kotlin Gradle Plugin) 경고는 별개입니다

`flutter build apk` 중 다음 경고가 함께 뜨는데, 이건 **빌드 실패 원인이
아닙니다** — 나열된 플러그인들이 아직 Flutter의 "Built-in Kotlin" 방식으로
마이그레이션하지 않아서 나오는 향후 호환성 경고일 뿐입니다.

```text
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): kakao_flutter_sdk_auth, kakao_flutter_sdk_common, kakao_map_plugin
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

지금 당장 조치할 필요는 없지만, 향후 Flutter 업그레이드 시 이 플러그인들이
여전히 문제라면: `kakao_map_plugin`은 이미 로컬 path dependency로 vendoring해
둔 상태라 (`third_party/kakao_map_plugin/VENDOR_NOTES.md` 참고) 벤더링한
사본의 `android/build.gradle`을 직접 마이그레이션할 수 있습니다.
`kakao_flutter_sdk_auth`/`kakao_flutter_sdk_common`은 Kakao 공식 패키지라
새 버전이 나오면 업데이트로 해결될 가능성이 높습니다 (`flutter pub outdated`로
확인). 지금은 정보성 경고로만 남겨둡니다.

## ⚠️ Windows: x86_64 에뮬레이터가 즉시 종료되는 경우

`flutter emulators --launch <id>`로 AVD를 띄웠는데 `flutter devices`/`adb devices`에
계속 안 잡힌다면, 부팅 중이 아니라 **즉시 실패**했을 가능성이 큽니다. 에뮬레이터를
직접 실행해서 원인을 확인하세요.

```bash
"%ANDROID_HOME%\emulator\emulator.exe" -avd <avd-name> -no-snapshot-load
```

다음 에러가 보인다면, 이 머신에 x86_64 에뮬레이터용 하드웨어 가속 드라이버가
없다는 뜻입니다.

```text
ERROR | x86_64 emulation currently requires hardware acceleration!
CPU acceleration status: Android Emulator hypervisor driver is not installed on this machine
```

**해결 방법 (택 1, 시스템 설정 변경 + 재부팅 필요)**:

1. **Windows Hypervisor Platform 활성화** (권장) — "Windows 기능 켜기/끄기"에서
   "Windows Hypervisor Platform" 체크 후 재부팅. 또는 관리자 PowerShell:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
   ```
   BIOS에서 가상화(VT-x/AMD-V)가 꺼져 있으면 이것만으로는 해결되지 않습니다.
2. **Android Emulator Hypervisor Driver 설치** — Android Studio → SDK Manager →
   SDK Tools 탭 → "Android Emulator Hypervisor Driver (installer)" 체크 후 설치.
   Hyper-V가 켜져 있으면 충돌할 수 있으니 둘 중 하나만 활성화하세요.

재부팅 후 `flutter emulators --launch <id>`로 다시 시도하고, `flutter devices`에
잡히는지 확인하세요. 이 문제는 프로젝트 코드/설정과 무관한, 이 개발 머신의
가상화 활성화 여부에 관한 것입니다.

### 그 다음 단계에서 발견된 별도의 크래시 (이 저장소에서는 미해결로 남김)

이 저장소를 개발 중인 머신에서는 Windows Hypervisor Platform을 켜고 재부팅한
뒤에도 (위 하드웨어 가속 에러는 사라졌지만) **에뮬레이터가 부팅 후반부에서
에러 메시지 없이 조용히 종료**되는 문제가 남아있었습니다. Android Studio의
AVD Manager로 직접 실행해도 "The emulator process for AVD ... has terminated."
라는 동일한 결과가 재현되어, 커맨드라인 실행 방식 자체의 문제는 아님을
확인했습니다.

**시도했지만 해결되지 않은 것들**:

- 헤드리스 실행(`-no-window`) — 디스플레이/세션 문제 배제 목적, 효과 없음
- `-wipe-data`로 AVD 데이터 초기화 — 효과 없음
- GPU 렌더링을 하드웨어(gfxstream) ↔ 소프트웨어(`-gpu swiftshader_indirect`)로 전환 — 둘 다 비슷한 지점에서 종료
- `-feature -Netsim`으로 네트워크 시뮬레이터 비활성화 — 효과 없음 (오히려 더 일찍 종료)
- Windows 이벤트 로그(`Get-WinEvent`) 확인 — `qemu-system-x86_64.exe` 관련 `RADAR_PRE_LEAK_64` 이벤트는 발견했지만, 이 이벤트 타입은 정확한 예외 코드/크래시 모듈을 담고 있지 않아 근본 원인 확정에는 부족함

**가장 유력한 원인 추정 (미확정)**:

1. **AMD-V ↔ WHPX 조합 문제** — 이 머신은 `AMD Radeon 780M`(내장 GPU)이 잡히는
   것으로 보아 AMD 계열 CPU로 추정됩니다. Android Emulator의 WHPX 가속 경로는
   Intel VT-x 기준으로 더 성숙되어 있고, AMD-V 조합에서의 유사 크래시 사례가
   커뮤니티에 보고되어 있습니다.
2. **Windows 프리뷰/Insider 빌드** — WHPX 로그에 찍힌 OS 빌드가 `10.0.26200`으로,
   정식 출시 빌드보다 높은 번호라 Insider 채널로 추정됩니다. 하이퍼바이저 관련
   코드가 아직 불안정할 가능성이 있습니다.
3. (미확인) 백신/보안 소프트웨어가 `qemu-system-x86_64.exe`를 강제 종료했을 가능성.

**이 문제는 이번 작업에서 더 파지 않고 중단했습니다.** 실제 원인 확정에는
WinDbg 등으로 크래시 덤프를 직접 분석해야 하는데, 이는 이 개발 환경/도구
범위를 벗어납니다.

**결론 및 다음 단계**: `flutter build apk --debug`는 이 머신에서 정상적으로
성공하므로 **앱 코드·빌드 설정 자체는 문제 없음**이 확인된 상태입니다. 앱
실행/지도 동작 검증은 이 머신의 에뮬레이터 대신 다음 방법으로 진행하세요.

- **실제 Android 기기를 USB로 연결** (권장 — 개발자 옵션 → USB 디버깅 켜기,
  케이블 연결 후 `flutter devices`에 잡히면 `flutter run -d <device-id>`).
  전체 절차(로컬 백엔드 연결, Kakao 키 해시, 골든 패스 체크리스트)는
  [REAL_DEVICE_TESTING.md](REAL_DEVICE_TESTING.md) 참고
- **다른 PC/노트북에서 에뮬레이터 실행** (Intel CPU 머신이거나 정식 릴리스
  Windows 빌드라면 이 문제가 재현되지 않을 가능성이 높음)
- **GitHub Actions 등 CI에서 Android 에뮬레이터 액션 사용** — Linux CI 러너
  기준으로 `flutter build apk`/에뮬레이터 실행 둘 다 이 Windows 고유 문제와
  무관하게 동작할 가능성이 높음

## 검증 명령어 요약

```bash
flutter doctor -v                                 # Android SDK/NDK 경로 확인 (한글 미포함 여부 포함)
flutter analyze                                   # 정적 분석 (이 환경에서 통과 확인됨)
flutter test                                      # 일반 테스트 (이 Windows 환경에서는 미동작, 위 설명 참고)
flutter devices                                   # 연결된 기기/에뮬레이터 확인
flutter emulators                                 # 설치된 에뮬레이터 목록
flutter run -d <device-id>                        # 실기기/에뮬레이터에서 앱 실행
flutter test integration_test -d <device-id>      # 실기기 통합 테스트 (.env 필요)
flutter build apk --debug                         # Android 빌드 (PUB_CACHE/ANDROID_HOME이 ASCII 경로여야 함)
```
