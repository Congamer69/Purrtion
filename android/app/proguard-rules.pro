# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class de.purrtion.app.**$$serializer { *; }
-keepclassmembers class de.purrtion.app.** { *** Companion; }
-keepclasseswithmembers class de.purrtion.app.** { kotlinx.serialization.KSerializer serializer(...); }
-dontwarn org.slf4j.**
