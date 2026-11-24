import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("org.jetbrains.kotlin.android") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// file_picker 11.x skips applying Kotlin on AGP 9 even when the
// project's Flutter compatibility mode explicitly disables built-in Kotlin.
// Scope this upstream-documented workaround to this single library.
// Remove when migrating to a compatible federated picker and storage stack.
subprojects {
    if (name == "file_picker" &&
        providers.gradleProperty("android.builtInKotlin").orNull == "false") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
