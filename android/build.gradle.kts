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
subprojects {
    project.evaluationDependsOn(":app")
}

// Some older Flutter plugins do not declare an Android Gradle Plugin (AGP)
// `namespace`, which is required on AGP 8+. Configure it here so builds don't
// require patching files under ~/.pub-cache.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
