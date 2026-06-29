plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mycompany.megadelivey" // Confirma se este é o teu ID correto
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ ATUALIZADO PARA JAVA 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ✅ ATUALIZADO PARA JAVA 17
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mycompany.megadelivey"
        minSdk = flutter.minSdkVersion // Subi para 23 para evitar erros com bibliotecas novas
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += "androidsupportmultidexversion.txt"
            excludes += "META-INF/**"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
