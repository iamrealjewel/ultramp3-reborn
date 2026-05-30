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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Inject fallback namespaces dynamically for older plugins to support AGP 8.x+
subprojects {
    val configureNamespace = {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android")
            if (android != null) {
                // 1. Process AndroidManifest.xml to strip package and extract namespace
                var manifestPackageName: String? = null
                try {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        val match = Regex("""package\s*=\s*"([^"]+)"""").find(content)
                        if (match != null) {
                            manifestPackageName = match.groupValues[1]
                            // Strip package attribute to avoid AGP 8.x+ errors
                            val updatedContent = content.replace(Regex("""\s*package\s*=\s*"[^"]*""""), "")
                            manifestFile.writeText(updatedContent)
                            logger.quiet("Dynamically stripped package attribute from :${project.name}'s Manifest (package: $manifestPackageName)")
                        }
                    }
                } catch (e: Exception) {
                    // Ignore manifest modification issues
                }

                // 2. Set fallback namespace for AGP 8.x
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val namespace = getNamespace.invoke(android) as? String
                    if (namespace.isNullOrEmpty()) {
                        val packageName = manifestPackageName ?: ("com.ultramp3." + project.name.replace("-", "_").replace(".", "_"))
                        setNamespace.invoke(android, packageName)
                        logger.quiet("Dynamically set namespace to $packageName for project :${project.name}")
                    }
                } catch (e: Exception) {
                    // Fallback
                }

                // 3. Only upgrade compileSdk if it is below 34 (satisfies modern androidx constraints without downgrading advanced modules)
                try {
                    val getCompileSdk = android.javaClass.getMethod("getCompileSdk")
                    val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                    val currentSdk = getCompileSdk.invoke(android) as? Int
                    if (currentSdk != null && currentSdk < 34) {
                        setCompileSdk.invoke(android, 34)
                        logger.quiet("Dynamically upgraded compileSdk from $currentSdk to 34 for project :${project.name}")
                    }
                } catch (e: Exception) {
                    try {
                        val getCompileSdkVersion = android.javaClass.getMethod("getCompileSdkVersion")
                        val currentSdkStr = getCompileSdkVersion.invoke(android)?.toString()
                        val currentSdk = currentSdkStr?.toIntOrNull()
                        if (currentSdk != null && currentSdk < 34) {
                            val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", java.lang.Integer::class.java)
                            setCompileSdkVersion.invoke(android, 34)
                            logger.quiet("Dynamically upgraded compileSdkVersion from $currentSdk to 34 for project :${project.name}")
                        }
                    } catch (e2: Exception) {
                        // Ignore
                    }
                }
                // 4. Dynamically force a valid NDK version for plugin build stability
                try {
                    val setNdkVersion = android.javaClass.getMethod("setNdkVersion", String::class.java)
                    setNdkVersion.invoke(android, "27.0.12077973")
                    logger.quiet("Dynamically forced ndkVersion to 27.0.12077973 for project :${project.name}")
                } catch (e: Exception) {
                    // Ignore
                }

                // 5. Upgrade minSdk to 21 if it is below 21 to satisfy NDK 27 requirements
                try {
                    val defaultConfig = android.javaClass.getMethod("getDefaultConfig").invoke(android)
                    val getMinSdk = defaultConfig.javaClass.getMethod("getMinSdk")
                    val currentMinSdk = getMinSdk.invoke(defaultConfig)
                    var currentMinSdkVal = 0
                    if (currentMinSdk != null) {
                        if (currentMinSdk is Number) {
                            currentMinSdkVal = currentMinSdk.toInt()
                        } else {
                            try {
                                val getApiLevel = currentMinSdk.javaClass.getMethod("getApiLevel")
                                currentMinSdkVal = getApiLevel.invoke(currentMinSdk) as Int
                            } catch (_: Exception) {}
                        }
                    }
                    if (currentMinSdkVal < 21) {
                        val setMinSdk = defaultConfig.javaClass.getMethod("setMinSdk", java.lang.Integer::class.java)
                        setMinSdk.invoke(defaultConfig, 21)
                        logger.quiet("Dynamically upgraded minSdk from $currentMinSdkVal to 21 for project :${project.name}")
                    }
                } catch (e: Exception) {
                    try {
                        val defaultConfig = android.javaClass.getMethod("getDefaultConfig").invoke(android)
                        val setMinSdkVersion = defaultConfig.javaClass.getMethod("setMinSdkVersion", java.lang.Integer::class.java)
                        setMinSdkVersion.invoke(defaultConfig, 21)
                        logger.quiet("Dynamically upgraded minSdkVersion to 21 (fallback) for project :${project.name}")
                    } catch (e2: Exception) {
                        // Ignore
                    }
                }
            }
        }
    }
    
    if (project.state.executed) {
        configureNamespace()
    } else {
        project.afterEvaluate {
            configureNamespace()
        }
    }

    // Enforce Java/Kotlin 17 at Android plugin level for all app/library modules.
    // This catches plugin modules such as :permission_handler_android reliably.
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
                logger.quiet("Force set Java compile compatibility to 17 for Android library :${project.name}")
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    plugins.withId("com.android.application") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
                logger.quiet("Force set Java compile compatibility to 17 for Android app :${project.name}")
            } catch (_: Exception) {
                // Ignore
            }
        }
    }

    // Force all Java compile tasks to target JVM 17 for consistent compilation
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
        logger.quiet("Force set Java compile compatibility to 17 for task :${project.name}:${this.name}")
    }

    tasks.configureEach {
        if (this.name.startsWith("compile") && this.name.endsWith("Kotlin")) {
            try {
                // For modern KGP versions (compilerOptions.jvmTarget Property)
                val compilerOptions = this.javaClass.getMethod("getCompilerOptions").invoke(this)
                val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                val setMethod = jvmTargetProp.javaClass.getMethod("set", Any::class.java)
                val jvmTargetClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val jvmEnum = jvmTargetClass.getField("JVM_17").get(null)
                setMethod.invoke(jvmTargetProp, jvmEnum)
                logger.quiet("Force set Kotlin compile compatibility to 17 for task :${project.name}:${this.name}")
            } catch (e1: Exception) {
                try {
                    val setJvmTarget = this.javaClass.getMethod("setJvmTarget", String::class.java)
                    setJvmTarget.invoke(this, "17")
                    logger.quiet("Force set Kotlin compile compatibility to 17 (fallback) for task :${project.name}:${this.name}")
                } catch (e2: Exception) {
                    // Ignore
                }
            }
        }
    }
}
