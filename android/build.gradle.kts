allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = file("../build")
rootProject.buildDir = newBuildDir

subprojects {
    val newSubBuildDir = file("${newBuildDir}/${project.name}")
    project.buildDir = newSubBuildDir
}

subprojects {
    // This line is important for Firestore/Firebase
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.evaluationDependsOn(":app")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(newBuildDir)
}