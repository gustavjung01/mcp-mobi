plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("MCP_ANDROID_KEYSTORE")?.trim().orEmpty()
val releaseStorePassword = System.getenv("MCP_ANDROID_KEYSTORE_PASSWORD")?.trim().orEmpty()
val releaseKeyAlias = System.getenv("MCP_ANDROID_KEY_ALIAS")?.trim().orEmpty()
val releaseKeyPassword = System.getenv("MCP_ANDROID_KEY_PASSWORD")?.trim().orEmpty()
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it.isNotBlank() }
val ciReleaseValidation = System.getenv("MCP_CI_RELEASE_VALIDATION") == "true"

android {
    namespace = "com.hungphat.mcpfield"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hungphat.mcpfield"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            when {
                hasReleaseSigning -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                ciReleaseValidation -> {
                    signingConfig = signingConfigs.getByName("debug")
                }
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.name.equals("assembleRelease", ignoreCase = true) ||
            task.name.equals("bundleRelease", ignoreCase = true)
    }
    if (releaseRequested && !hasReleaseSigning && !ciReleaseValidation) {
        throw GradleException(
            "Production release signing is not configured. " +
                "Set MCP_ANDROID_KEYSTORE, MCP_ANDROID_KEYSTORE_PASSWORD, " +
                "MCP_ANDROID_KEY_ALIAS and MCP_ANDROID_KEY_PASSWORD.",
        )
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
