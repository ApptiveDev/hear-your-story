import java.util.Base64
import java.util.Properties
import java.net.URI

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

// 실제 값은 Git에서 제외된 android/key.properties에만 둔다.
val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = signingFields.all { !signingProperties.getProperty(it).isNullOrBlank() }

val validateReleaseConfiguration = tasks.register("validateReleaseConfiguration") {
    doLast {
        check(hasReleaseSigning) { "Release signing requires android/key.properties. See RELEASE.md." }
        check(rootProject.file(signingProperties.getProperty("storeFile")).isFile) {
            "Release keystore file does not exist."
        }
        check(dartDefines["APP_ENV"] in listOf("staging", "production")) {
            "Release requires APP_ENV=staging or production."
        }
        check(dartDefines["USE_MOCK"] == "false" && dartDefines["KAKAO_FAKE_LOGIN"] == "false") {
            "Release requires USE_MOCK=false and KAKAO_FAKE_LOGIN=false."
        }
        val apiUri = runCatching { URI(dartDefines["API_BASE_URL"].orEmpty()) }.getOrNull()
        check(apiUri != null && apiUri.scheme == "https" && !apiUri.host.isNullOrBlank() &&
            apiUri.userInfo == null && apiUri.query == null && apiUri.fragment == null &&
            apiUri.path.trimEnd('/') == "/api/v1" && !apiUri.host.endsWith(".invalid")) {
            "Release requires an HTTPS API_BASE_URL ending in /api/v1, without credentials or query."
        }
        check("KAKAO_AUTH" !in dartDefines) {
            "Remove obsolete KAKAO_AUTH. Real builds always use Kakao authentication."
        }
        check(!dartDefines["KAKAO_NATIVE_APP_KEY"].isNullOrBlank()) {
            "Release requires KAKAO_NATIVE_APP_KEY."
        }
        for (flag in listOf("STORIES_MONTH_API", "ACCOUNT_DELETION_API")) {
            check(dartDefines[flag] in listOf("true", "false")) {
                "Release requires an explicit true/false value for $flag."
            }
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateReleaseConfiguration)
}

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

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 설정이 없을 때 debug 키로 대체하지 않는다.
            signingConfig = signingConfigs.findByName("release")
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
