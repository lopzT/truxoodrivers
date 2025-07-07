plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.truxoo.truxoo"
    compileSdk = 35  
    ndkVersion = "27.0.12077973"  

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17  
        targetCompatibility = JavaVersion.VERSION_17  
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()  
    }

    defaultConfig {
        applicationId = "com.truxoo.truxoo"
        minSdk = 21  
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Add multidex support
    implementation("androidx.multidex:multidex:2.0.1")
}