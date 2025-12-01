plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.4.4" apply false

}
buildscript {
    dependencies {
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix build directory (Flutter Android restructure)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build")

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubBuildDir = newBuildDir.map { it.dir(project.name) }
    project.layout.buildDirectory.set(newSubBuildDir)
}

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
