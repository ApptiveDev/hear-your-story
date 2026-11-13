import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// flutter build의 --dart-define 값. Flutter가 base64로 묶어 넘긴다.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotEmpty() }
        ?.map { Base64.getDecoder().decode(it).toString(Charsets.UTF_8) }
        ?.associate { it.substringBefore("=") to it.substringAfter("=") }
        ?: emptyMap()

android {
    namespace = "com.apptive.life_record"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.apptive.life_record"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 카카오 로그인이 끝나면 돌아올 주소(kakao{네이티브 앱 키}://oauth).
        // 키 없이 빌드하면 아무 앱과도 겹치지 않는 값으로 둔다.
        val kakaoKey = dartDefines["KAKAO_NATIVE_APP_KEY"].orEmpty()
        manifestPlaceholders["kakaoScheme"] =
            if (kakaoKey.isEmpty()) "liferecordnokakaokey" else "kakao$kakaoKey"
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
