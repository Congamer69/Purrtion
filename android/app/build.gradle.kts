plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
}

// Shared with the iOS app: food databases and the Firebase config of the friends page.
val iosResources = rootProject.file("../Purrtion/Resources")

/**
 * Builds with `-Ppurrtion.public=true` (build-apk.sh --no-server) carry no server data; release builds include the
 * Firebase.plist server since 3.0.
 */
val publicBuild = (findProperty("purrtion.public") as String?) == "true"

/** Reads a string value from the (gitignored) iOS Firebase.plist – empty when it is missing or for public builds. */
fun firebaseValue(key: String): String {
    if (publicBuild) return ""
    val plist = File(iosResources, "Firebase.plist")
    if (!plist.exists()) return ""
    val text = plist.readText()
    val match = Regex("<key>$key</key>\\s*<string>([^<]*)</string>").find(text) ?: return ""
    return match.groupValues[1].trim()
}

/** MARKETING_VERSION / CURRENT_PROJECT_VERSION of the iOS project, so both apps share one version. */
fun iosSetting(key: String, fallback: String): String {
    val pbx = rootProject.file("../Purrtion.xcodeproj/project.pbxproj")
    if (!pbx.exists()) return fallback
    return Regex("$key = ([^;]+);").find(pbx.readText())?.groupValues?.get(1)?.trim() ?: fallback
}

android {
    namespace = "de.purrtion.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "de.purrtion.app"
        minSdk = 28
        targetSdk = 35
        versionCode = iosSetting("CURRENT_PROJECT_VERSION", "1").toInt()
        versionName = iosSetting("MARKETING_VERSION", "1.0")
        // ML Kit ships big native libraries per CPU type. Every phone with Android 9+ worth supporting is arm64.
        ndk { abiFilters += listOf("arm64-v8a") }
        buildConfigField("String", "FIREBASE_API_KEY", "\"${firebaseValue("APIKey")}\"")
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"${firebaseValue("ProjectID")}\"")
        buildConfigField("String", "FIREBASE_INVITE_URL", "\"${firebaseValue("InviteURL")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Signed with the debug key so a release build can be installed right away (personal use).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/foodAssets"))
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

// Copies bls.json and swiss.json from the iOS project into the app assets.
val copyFoodDatabases by tasks.registering(Copy::class) {
    from(iosResources) { include("*.json") }
    into(layout.buildDirectory.dir("generated/foodAssets"))
}
tasks.named("preBuild") { dependsOn(copyFoodDatabases) }

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.animation:animation")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.5")

    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    implementation("androidx.work:work-runtime-ktx:2.10.0")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.health.connect:connect-client:1.1.0-alpha10")

    implementation("androidx.camera:camera-camera2:1.4.1")
    implementation("androidx.camera:camera-lifecycle:1.4.1")
    implementation("androidx.camera:camera-view:1.4.1")
    implementation("com.google.guava:guava:33.3.1-android")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("com.google.mlkit:image-labeling:17.0.9")

    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
}
