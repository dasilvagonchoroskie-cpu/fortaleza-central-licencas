import java.io.FileInputStream
import java.util.Properties

// Assinatura: a MESMA chave da Central 2.x (segredo do GitHub), para a
// versao 3 instalar por cima. A esteira escreve este key.properties antes
// de compilar. Sem ele (montagem local), cai na chave de depuracao.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val temAssinaturaDeProducao = keystorePropertiesFile.exists()
if (temAssinaturaDeProducao) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.fortalezadigitalsecurity.licencas"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // O mesmo pacote da Central 2.x: a versao nova atualiza a antiga.
        applicationId = "br.com.fortalezadigitalsecurity.licencas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Bibliotecas nativas comprimidas: APK menor para mandar no chat.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        create("release") {
            if (temAssinaturaDeProducao) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeType = (keystoreProperties["storeType"] as String?) ?: "pkcs12"
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (temAssinaturaDeProducao) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Confere os pedidos novos em segundo plano (aviso de pedido).
    implementation("androidx.work:work-runtime:2.10.1")
}

flutter {
    source = "../.."
}
