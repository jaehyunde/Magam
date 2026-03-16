// 1. 맨 위에 임포트 문을 추가해서 'util'을 찾게 해줍니다.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 2. 변수 정의를 android 블록 '밖'에서 확실히 해줍니다.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.company.magam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // 🚀 이미지에 나온 jvmTarget 경고를 해결하는 신형 문법입니다.
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.company.magam"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // 🚀 이제 flutterVersionCode를 확실히 인식합니다.
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        getByName("release") {
            // release 빌드도 테스트를 위해 debug 서명을 쓰도록 설정
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
