plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Add this line for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.truxoo.truxoo"
    compileSdk = 36  
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
        minSdk = flutter.minSdkVersion  
        targetSdk = 36
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
    
    // Multidex support
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Firebase dependencies (these are usually added automatically by FlutterFire)
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    
    // Required for Firebase Auth
    implementation("androidx.browser:browser:1.7.0")
}
