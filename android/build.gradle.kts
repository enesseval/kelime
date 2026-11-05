// The Kotlin plugins are put on the build classpath once, here, so :core and :app share them
// (Gradle warns when each subproject loads its own copy). The Android Gradle Plugin stays in
// :app only, so `-PcoreOnly=true` never needs Google's Maven repository.
plugins {
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
