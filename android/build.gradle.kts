// android/build.gradle.kts

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // W Kotlin DSL używamy `classpath()` zamiast `classpath` jako metody
        // Wersja Gradle Plugin dla Androida
        classpath("com.android.tools.build:gradle:8.1.0") // Upewnij się, że to jest aktualna wersja Gradle

        // Wersja wtyczki Kotlin Gradle. Upewnij się, że to jest co najmniej 1.8.0, np. 1.9.0 lub 2.0.0
        // Definiujemy ją tutaj bezpośrednio, bez zmiennej 'kotlin_version' w 'ext'
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // UPEWNIJ SIĘ, ŻE TO JEST 1.9.0 LUB NOWSZA
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Reszta Twojego kodu, którą podałeś, pozostaje bez zmian
val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
