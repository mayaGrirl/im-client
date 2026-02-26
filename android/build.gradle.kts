allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // 抑制第三方插件的 Java 编译警告（source/target 8 过时、deprecation、unchecked）
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation", "-Xlint:-unchecked"))
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    // 为缺少 namespace 的旧版插件自动注入（AGP 8+ 要求所有模块声明 namespace）
    project.plugins.whenPluginAdded {
        if (this is com.android.build.gradle.LibraryPlugin) {
            val androidExt = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
            if (androidExt.namespace.isNullOrEmpty()) {
                // 从插件的 AndroidManifest.xml 读取 package name
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val packageName = Regex("package=\"([^\"]+)\"").find(manifestFile.readText())?.groupValues?.get(1)
                    if (!packageName.isNullOrEmpty()) {
                        androidExt.namespace = packageName
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
