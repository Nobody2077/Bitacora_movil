import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("signing.properties")
if (releaseSigningPropertiesFile.isFile) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    providers.environmentVariable(environmentName).orNull
        ?: releaseSigningProperties.getProperty(propertyName)?.takeIf(String::isNotBlank)

val releaseStoreFile =
    releaseSigningValue("storeFile", "BITACORA_RELEASE_STORE_FILE")
val releaseStorePassword =
    releaseSigningValue("storePassword", "BITACORA_RELEASE_STORE_PASSWORD")
val releaseKeyAlias =
    releaseSigningValue("keyAlias", "BITACORA_RELEASE_KEY_ALIAS")
val releaseKeyPassword =
    releaseSigningValue("keyPassword", "BITACORA_RELEASE_KEY_PASSWORD")
val releaseSigningValues =
    listOf(
        releaseStoreFile,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    )
val releaseSigningConfigured = releaseSigningValues.all { !it.isNullOrBlank() }
val releaseSigningPartiallyConfigured =
    releaseSigningValues.any { !it.isNullOrBlank() } && !releaseSigningConfigured

android {
    namespace = "com.jcyq.bitacorarpg"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jcyq.bitacorarpg"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Bitácora RPG DEV")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Bitácora RPG Personal")
        }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    lint {
        lintConfig = rootProject.file("lint.xml")
    }
}

gradle.taskGraph.whenReady {
    val requestsReleaseArtifact = allTasks.any { task ->
        task.project == project &&
            task.name in
            setOf(
                "assembleDevRelease",
                "assembleProdRelease",
                "bundleDevRelease",
                "bundleProdRelease",
            )
    }
    if (requestsReleaseArtifact && !releaseSigningConfigured) {
        val detail =
            if (releaseSigningPartiallyConfigured) {
                "La configuracion de firma esta incompleta."
            } else {
                "No se encontro configuracion de firma."
            }
        throw GradleException(
            "$detail Define android/signing.properties o las variables " +
                "BITACORA_RELEASE_STORE_FILE, BITACORA_RELEASE_STORE_PASSWORD, " +
                "BITACORA_RELEASE_KEY_ALIAS y BITACORA_RELEASE_KEY_PASSWORD. " +
                "A8 prohibe firmar release con la llave debug.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
