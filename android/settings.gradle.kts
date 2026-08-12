pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val propFile = file("local.properties")
            propFile.inputStream().use { properties.load(it) }
            var flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            if (flutterSdkPath.contains("Usuário") || flutterSdkPath.contains("Usurio") || flutterSdkPath.contains("UsuÃ¡rio")) {
                flutterSdkPath = "C:\\\\Users\\\\USURIO~2\\\\flutter"
                properties.setProperty("flutter.sdk", flutterSdkPath)
                
                var sdkDir = properties.getProperty("sdk.dir")
                if (sdkDir != null && (sdkDir.contains("Usuário") || sdkDir.contains("Usurio") || sdkDir.contains("UsuÃ¡rio"))) {
                    sdkDir = "C:\\\\Users\\\\USURIO~2\\\\AppData\\\\Local\\\\Android\\\\sdk"
                    properties.setProperty("sdk.dir", sdkDir)
                }
                
                propFile.outputStream().use { properties.store(it, "Fixed paths by settings.gradle.kts") }
            }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
