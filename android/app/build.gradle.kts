import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested && !releasePropertiesFile.exists()) {
    throw GradleException(
        "Release signing is not configured. Copy android/key.properties.example " +
            "to android/key.properties and point it to the project release keystore."
    )
}
val releaseProperties = Properties().apply {
    if (releasePropertiesFile.exists()) releasePropertiesFile.inputStream().use { load(it) }
}
val requiredReleaseProperties = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
if (releaseRequested && requiredReleaseProperties.any { releaseProperties.getProperty(it).isNullOrBlank() }) {
    throw GradleException("android/key.properties is incomplete. Required: ${requiredReleaseProperties.joinToString()}.")
}
if (releaseRequested && !file(releaseProperties.getProperty("storeFile")).isFile) {
    throw GradleException("Release keystore does not exist at the storeFile path in android/key.properties.")
}

android {
    namespace = "com.demmagence.cbtapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.demmagence.cbtapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releasePropertiesFile.exists()) {
            create("release") {
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releasePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
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
