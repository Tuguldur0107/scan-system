allprojects {
    repositories {
        google()
        mavenCentral()
        // Chainway UHF AAR lives under app/libs/ and is consumed as a named
        // dependency (see app/build.gradle.kts).
        flatDir {
            dirs("${rootDir}/app/libs")
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
