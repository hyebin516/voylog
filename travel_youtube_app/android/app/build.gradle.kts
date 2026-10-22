import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FR-12 push notifications. google-services.json holds the Firebase project
// config and is git-ignored (see ../.gitignore), so this is conditional:
// without it the app still builds and runs, just with notifications off
// (FirebasePushMessagingService catches the missing-config error).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Reads a single value out of the git-ignored ../.env file (see README.md /
// docs/KAKAO_SETUP.md) so the real Kakao native app key never has to be
// hardcoded in a committed file. Used below for the Kakao Login manifest
// placeholder (AndroidManifest.xml's redirect URI scheme).
// Release signing. key.properties and the keystore itself are git-ignored
// and live only on the machine that publishes, so a checkout without them
// still builds -- it just falls back to the debug key, which the Play Store
// refuses. The warning below is there because that fallback is silent
// otherwise, and an unsigned-looking build is only noticed at upload time.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        // Read as UTF-8, not with load(InputStream) -- that one decodes
        // ISO-8859-1, so a keystore path under a Korean user folder came
        // back mojibake and the build failed with "Keystore file not found".
        file.reader(Charsets.UTF_8).use { load(it) }
    }
}

fun readEnvValue(key: String): String {
    val envFile = rootProject.file("../.env")
    if (!envFile.exists()) return ""
    val match = envFile.readLines().firstOrNull { it.trim().startsWith("$key=") }
    return match?.trim()?.substringAfter("=")?.trim() ?: ""
}

android {
    namespace = "com.luckyvicky.voylog"
    // Pinned explicitly (rather than the flutter.compileSdkVersion default)
    // because kakao_map_plugin's webview_flutter_android dependency requires
    // compileSdk 36+. minSdk/targetSdk are left at Flutter's defaults.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.luckyvicky.voylog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Backs AndroidManifest.xml's ${kakaoNativeAppKey} placeholder, used
        // in the Kakao Login redirect intent-filter (scheme "kakao<key>").
        manifestPlaceholders["kakaoNativeAppKey"] = readEnvValue("KAKAO_NATIVE_APP_KEY")
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning == null) {
                logger.warn(
                    "[voylog] android/key.properties가 없어 릴리스 빌드를 디버그 키로 서명합니다. " +
                        "스토어에는 올릴 수 없는 빌드입니다 (docs/RELEASE.md 참고)."
                )
            }
            signingConfig = releaseSigning ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
