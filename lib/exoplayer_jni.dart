/// ExoPlayer JNI — Flutter plugin exposing the full Media3 ExoPlayer API
/// from Dart via JNIgen-generated bindings (no MethodChannel overhead).
///
/// Usage:
/// ```dart
/// import 'package:exoplayer_jni/exoplayer_jni.dart';
///
/// final player = ExoPlayerController();
/// await player.init(context);
/// player.setMediaUrl('https://example.com/video.mp4');
/// player.play();
/// ```
library exoplayer_jni;

export 'src/exoplayer_controller.dart';
export 'src/exoplayer_view.dart';
export 'src/exoplayer_widget.dart';
export 'src/media_item_builder.dart';
export 'src/player_state.dart';
export 'src/track_selector_helper.dart';
export 'src/drm_config.dart';
export 'src/cache_config.dart';
