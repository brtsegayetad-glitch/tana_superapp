allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
}

// This section fixes conflicts with older Flutter plugins
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.browser" && requested.name == "browser") {
                useVersion("1.8.0")
            }
            if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                useVersion("1.13.1")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}