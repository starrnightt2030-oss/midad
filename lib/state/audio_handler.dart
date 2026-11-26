import 'package:audio_service/audio_service.dart';

/// يربط المشغّل بنظام أندرويد: إشعار التشغيل، أزرار شاشة القفل،
/// سماعات البلوتوث، واستمرار الصوت والشاشة مقفولة.
///
/// لا يملك صوتًا بنفسه؛ يوجّه الأوامر إلى [PlayerController] عبر الدوال المسجّلة.
class AtheerAudioHandler extends BaseAudioHandler with SeekHandler {
  void Function()? onPlay;
  void Function()? onPause;
  void Function(Duration)? onSeek;
  void Function(int seconds)? onSkip;

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> stop() async {
    onPause?.call();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
  }

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  @override
  Future<void> fastForward() async => onSkip?.call(15);

  @override
  Future<void> rewind() async => onSkip?.call(-15);

  @override
  Future<void> skipToNext() async => onSkip?.call(15);

  @override
  Future<void> skipToPrevious() async => onSkip?.call(-15);

  /// يحدّث بيانات القصة المعروضة في الإشعار وشاشة القفل.
  void showItem({required String id, required String title, String? album, String? artist, Duration? duration, Uri? artUri}) {
    mediaItem.add(MediaItem(id: id, title: title, album: album, artist: artist, duration: duration, artUri: artUri));
  }

  /// يحدّث حالة التشغيل (يُستدعى عند التشغيل/الإيقاف/التقديم فقط، والنظام يحسب الموضع بين التحديثات).
  void showState({required bool playing, required bool loading, required Duration position, required double speed}) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: loading ? AudioProcessingState.loading : AudioProcessingState.ready,
      playing: playing,
      updatePosition: position,
      speed: speed,
    ));
  }
}

/// يهيّئ خدمة الصوت. لو فشلت (جهاز غير مدعوم مثلًا) يكمل التطبيق بدونها.
Future<AtheerAudioHandler?> initAudioHandler() async {
  try {
    return await AudioService.init(
      builder: AtheerAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.eldawly.atheer.playback',
        androidNotificationChannelName: 'تشغيل أثير',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidStopForegroundOnPause: true,
        fastForwardInterval: Duration(seconds: 15),
        rewindInterval: Duration(seconds: 15),
      ),
    );
  } catch (_) {
    return null;
  }
}
