plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStore = System.getenv("IDCOLDA_KEYSTORE")
val releaseStorePassword = System.getenv("IDCOLDA_STORE_PASSWORD")
val releaseAlias = System.getenv("IDCOLDA_KEY_ALIAS")
val releaseKeyPassword = System.getenv("IDCOLDA_KEY_PASSWORD")
val releaseSigningReady = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword).all { !it.isNullOrBlank() }

android {
    namespace = "com.techninxa.idcolda_ms"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.techninxa.idcolda_ms"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // CameraX requires Android 7.0 (API 24) or higher.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) create("idcoldaRelease") {
            storeFile = file(releaseStore!!)
            storePassword = releaseStorePassword
            keyAlias = releaseAlias
            keyPassword = releaseKeyPassword
        }
    }
    buildTypes {
        release {
            // Retain Flutter/AGP optimization; suppress only unused optional OCR classes.
            proguardFiles("proguard-rules.pro")
            if (releaseSigningReady) signingConfig = signingConfigs.getByName("idcoldaRelease")
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

// A release APK must use the permanent distribution key.
tasks.configureEach {
    if (name == "assembleRelease" || name == "bundleRelease" || name == "packageRelease") {
        doFirst { check(releaseSigningReady) { "Configure IDCOLDA release signing environment variables before building a release." } }
    }
}
dependencies { implementation("androidx.core:core:1.15.0") }
