android {
    namespace = "com.tana.superapp"
    
    // 🔥 FIXED: Explicitly set to 35 for Android 15 stability. 
    // Using flutter.compileSdkVersion can sometimes point to 33, which lacks FGS Location types.
    compileSdk = 35 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Updated to Java 17 as recommended for Flutter 3.29+ and Android 14+
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Must match the compatibility version above
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.tana.superapp"
        
        // 🔥 REQUIRED: 23 is the minimum for modern GPS and Permission logic
        minSdk = 23 
        
        // 🔥 FIXED: Target 35 so the "Foreground Service Type" in manifest is respected
        targetSdk = 35
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Note: No extra code needed here for camera/gps specifically, 
        // as those are handled by the Manifest and runtime requests.
    }

    buildTypes {
        release {
            // Note: For a real SuperApp, you should eventually set 
            // isMinifyEnabled = true to protect your code.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}