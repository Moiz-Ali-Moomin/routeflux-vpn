plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.routeflux.vpn"
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.routeflux.vpn"

        minSdk = flutter.minSdkVersion
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ABI restriction — APK & CMake
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("routeflux.jks")
            storePassword = "routeflux123"
            keyAlias = "routeflux"
            keyPassword = "routeflux123"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += "**/libtun2socks.so"
        }
    }
}

flutter {
    source = "../.."
}
