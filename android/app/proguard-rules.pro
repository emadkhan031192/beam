# Beam: keep the components R8 must not rename or strip, since they are
# referenced from the manifest and from Flutter platform channels.

-keep class com.afzal.beam.BeamTileService { *; }
-keep class com.afzal.beam.ShakeService { *; }
-keep class com.afzal.beam.TorchActionReceiver { *; }
-keep class com.afzal.beam.MainActivity { *; }
-keep class com.afzal.beam.TorchManager { *; }
-keepclassmembers class com.afzal.beam.TorchManager { *; }
