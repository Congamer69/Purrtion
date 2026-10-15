plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.1.0" apply false
    id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
}

// The project lives in an iCloud-synced folder: keep the (large, fast-changing) build output outside of it.
val buildRoot = File(System.getProperty("java.io.tmpdir"), "purrtion-android-build")
allprojects {
    layout.buildDirectory.set(File(buildRoot, name))
}
