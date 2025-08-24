# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Security: Obfuscate class names
-obfuscationdictionary obfuscation-dictionary.txt
-classobfuscationdictionary obfuscation-dictionary.txt
-packageobfuscationdictionary obfuscation-dictionary.txt

# Security: Remove debug information
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Security: Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Security: Remove stack traces
-keepattributes !StackMapTable

# Security: Obfuscate string constants
-adaptclassstrings
-adaptresourcefilenames
-adaptresourcefilecontents

# Security: Remove unused code
-dontwarn **
-ignorewarnings

# Security: Protect native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Security: Protect reflection
-keepattributes *Annotation*
-keep class * implements java.lang.reflect.InvocationHandler {
    private java.lang.Object invoke(java.lang.Object, java.lang.reflect.Method, java.lang.Object[]);
}

# Security: Remove debug symbols
-keepattributes !LocalVariableTable
-keepattributes !LocalVariableTypeTable
-keepattributes !LineNumberTable
-keepattributes !SourceFile

# Security: Protect sensitive classes
-keep class ru.hlvm.hlvmapp.hlvm_mobileapp.** { *; }
-keep class ru.hlvm.** { *; }

# Security: Remove source file names
-renamesourcefileattribute SourceFile

# Security: Optimize and obfuscate
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
