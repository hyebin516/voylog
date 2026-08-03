plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Reads a single value out of the git-ignored ../.env file (see README.md /
// docs/KAKAO_SETUP.md) so the real Kakao native app key never has to be
// hardcoded in a committed file. Used below for the Kakao Login manifest
// placeholder (AndroidManifest.xml's redirect URI scheme).
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
