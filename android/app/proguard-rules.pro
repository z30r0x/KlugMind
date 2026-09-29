# MediaPipe (flutter_gemma)
-dontwarn com.google.auto.value.extension.memoized.Memoized
-dontwarn com.google.mediapipe.proto.**
-keep class com.google.mediapipe.** { *; }

# ML Kit text recognition: optional script modules we don't bundle (Latin only)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**