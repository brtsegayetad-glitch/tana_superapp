allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = file("../build")

subprojects {
    project.buildDir = file("$newBuildDir/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(newBuildDir)
}