import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use(::load)
}
fun local(key: String): String = localProps.getProperty(key) ?: ""

// Shared, platform-free assets live at the repository root. They are copied into generated
// asset and resource folders on every build, never by hand.
val repoRoot = rootProject.projectDir.parentFile
val generatedAssets = layout.buildDirectory.dir("generated/kelime/assets")
val generatedRes = layout.buildDirectory.dir("generated/kelime/res")

val copyContent by tasks.registering(Copy::class) {
    description = "Copies Content/cards.json (and Content/puzzles if present) into the app assets."
    from(File(repoRoot, "Content/cards.json")) { into("content") }
    from(File(repoRoot, "Content/puzzles")) {
        include("*.json")
        into("content/puzzles")
    }
    into(generatedAssets)
}

val copyFonts by tasks.registering(Copy::class) {
    description = "Copies Fonts/*.ttf into res/font with Android resource names."
    from(File(repoRoot, "Fonts")) {
        include("*.ttf")
        rename { name -> name.removeSuffix(".ttf").replace("-", "_").lowercase() + ".ttf" }
    }
    into(generatedRes.map { it.dir("font") })
}

android {
    namespace = "com.enesseval.kilitkelime"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.enesseval.kilitkelime"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "REVENUECAT_KEY", "\"${local("revenuecat.androidKey")}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${local("google.webClientId")}\"")
    }

    signingConfigs {
        create("release") {
            val store = local("kelime.keystore")
            if (store.isNotEmpty()) {
                storeFile = file(store)
                storePassword = local("kelime.keystorePassword")
                keyAlias = local("kelime.keyAlias")
                keyPassword = local("kelime.keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (local("kelime.keystore").isNotEmpty()) signingConfig = signingConfigs.getByName("release")
            buildConfigField("Boolean", "DEV_TOOLS", "false")
        }
        debug {
            applicationIdSuffix = ".debug"
            buildConfigField("Boolean", "DEV_TOOLS", "true")
        }
    }

    sourceSets["main"].assets.srcDir(generatedAssets)
    sourceSets["main"].res.srcDir(generatedRes)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    packaging {
        resources.excludes += listOf("/META-INF/{AL2.0,LGPL2.1}", "META-INF/versions/9/previous-compilation-data.bin")
    }
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

tasks.named("preBuild") { dependsOn(copyContent, copyFonts) }

dependencies {
    implementation(project(":core"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    debugImplementation(libs.compose.ui.tooling)
    implementation(libs.splashscreen)

    implementation(libs.glance.appwidget)
    implementation(libs.glance.material3)
    implementation(libs.work.runtime)
    implementation(libs.datastore.preferences)

    implementation(libs.credentials)
    implementation(libs.credentials.play)
    implementation(libs.googleid)
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.ktor.client.okhttp)

    implementation(libs.revenuecat)
    implementation(libs.telemetrydeck)

    testImplementation(libs.junit)
}
