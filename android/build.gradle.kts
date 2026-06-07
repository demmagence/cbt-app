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
subprojects {
    project.configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
    }
}
subprojects {
    val configureAndroidSubproject = {
        extensions.findByName("android")?.let {
            val android = it as? com.android.build.gradle.BaseExtension
            if (android != null && android.namespace == null) {
                android.namespace = "com.example.${project.name.replace("-", "_").replace(" ", "_")}"
            }
        }
        tasks.matching { it.name.startsWith("process") && it.name.endsWith("Manifest") }.configureEach {
            doFirst {
                val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var content = manifestFile.readText()
                    val regex = Regex("""package="[^"]*"""")
                    if (regex.containsMatchIn(content)) {
                        content = content.replace(regex, "")
                        manifestFile.writeText(content)
                        println("Removed package attribute from ${manifestFile.path}")
                    }
                }
            }
        }
    }
    if (state.executed) {
        configureAndroidSubproject()
    } else {
        afterEvaluate { configureAndroidSubproject() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
