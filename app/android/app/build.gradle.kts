import java.io.IOException
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
val releaseSigningError = try {
    if (!releasePropertiesFile.isFile) {
        "Create app/android/key.properties from key.properties.example."
    } else {
        releasePropertiesFile.reader(Charsets.UTF_8).use { releaseProperties.load(it) }
        val missing = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
            .filter { releaseProperties.getProperty(it).isNullOrBlank() }
        when {
            missing.isNotEmpty() -> "Missing in app/android/key.properties: ${missing.joinToString()}."
            releaseProperties.getProperty("storePassword") == "YOUR_KEYSTORE_PASSWORD" ||
                releaseProperties.getProperty("keyPassword") == "YOUR_KEY_PASSWORD" ->
                "Replace the example passwords in app/android/key.properties."
            else -> null
        }
    }
} catch (e: IOException) {
    "Cannot read app/android/key.properties."
} catch (e: IllegalArgumentException) {
    "Invalid properties syntax in app/android/key.properties. Use forward slashes in storeFile."
}

val checkReleaseSigning = tasks.register("checkReleaseSigning") {
    val problem = releaseSigningError
    doLast {
        if (problem != null) throw GradleException("Android release signing: $problem")
    }
}

// Also guard packaging when AGP would otherwise produce an unsigned APK.
tasks.matching { it.name == "packageRelease" || it.name == "validateSigningRelease" }.configureEach {
    dependsOn(checkReleaseSigning)
}

android {
    namespace = "com.wkreho.geubsik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.wkreho.geubsik"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningError == null) {
                storeType = "JKS"
                storeFile = rootProject.file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
