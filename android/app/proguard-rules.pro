# kotlinx.serialization: keep generated serializers of our @Serializable classes.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class com.enesseval.kilitkelime.** {
    *** Companion;
}
-keepclasseswithmembers class com.enesseval.kilitkelime.** {
    kotlinx.serialization.KSerializer serializer(...);
}
# Supabase / Ktor
-dontwarn org.slf4j.**
-dontwarn io.ktor.**
