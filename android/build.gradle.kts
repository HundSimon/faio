import com.android.build.gradle.LibraryExtension

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
val namespaceOverrides = mapOf(
    "isar_flutter_libs" to "com.isar.flutter.libs",
    "uni_links" to "dev.faio.uni_links",
)

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            val desiredSdk = 34
            compileSdk = desiredSdk
            defaultConfig {
                targetSdk = desiredSdk
            }
            if (namespace.isNullOrBlank()) {
                namespace = namespaceOverrides[name]
                    ?: "dev.faio.generated.${name.replace('-', '_')}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
