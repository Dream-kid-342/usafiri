allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Workaround for space in username "Enock Mumo" preventing build
rootProject.buildDir = file("C:/Users/Public/pm_pro_build")

subprojects {
    project.buildDir = file("C:/Users/Public/pm_pro_build/${project.name}")
}

/*
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
*/
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
