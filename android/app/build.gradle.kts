plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_review"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // 👇 هنا المكان الصحيح لـ compileOptions (داخل android)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // تفعيل Desugaring هنا
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_review"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // تفعيل MultiDex (اختياري ولكنه مفيد)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 👇 استخدام النسخة الأحدث المتوافقة مع Java 17
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}