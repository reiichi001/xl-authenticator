import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material is read from android/key.properties (gitignored) when
// it is present, and falls back to the OTPAPP_* environment variables used by CI.
// The keystore itself must never be committed: it lived in this repo publicly
// until 1.0.6 and that key has to be treated as compromised.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, envName: String): String? =
    keystoreProperties.getProperty(propertyName) ?: System.getenv(envName)

val releaseStorePath = signingValue("storeFile", "OTPAPP_STORE_PATH")

android {
    namespace = "com.goatsoft.xl_otpsend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.goatsoft.xl_otpsend"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStorePath != null) {
            create("release") {
                storeFile = file(releaseStorePath)
                storePassword = signingValue("storePassword", "OTPAPP_STORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "OTPAPP_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "OTPAPP_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Without release signing material (a local build, say) fall back to the
            // debug key so `flutter build apk --release` still works.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
