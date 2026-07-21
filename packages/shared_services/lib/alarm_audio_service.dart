import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service to manage looping foreground alarm playback (e.g. bg_alarm2.mp3)
class AlarmAudioService {
  static final AlarmAudioService _instance = AlarmAudioService._internal();
  factory AlarmAudioService() => _instance;
  AlarmAudioService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Plays the alarm sound in a continuous loop at full volume until stopped.
  Future<void> startAlarm() async {
    if (_isPlaying) return;
    try {
      _isPlaying = true;
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(1.0);
      await _player!.play(AssetSource('bg_alarm2.mp3'));
      debugPrint('[AlarmAudioService] Started looping alarm sound.');
    } catch (e) {
      debugPrint('[AlarmAudioService] Error playing alarm audio: $e');
      _isPlaying = false;
    }
  }

  /// Stops the alarm sound immediately.
  Future<void> stopAlarm() async {
    try {
      _isPlaying = false;
      await _player?.stop();
      debugPrint('[AlarmAudioService] Stopped alarm sound.');
    } catch (e) {
      debugPrint('[AlarmAudioService] Error stopping alarm audio: $e');
    }
  }

  Future<void> dispose() async {
    await stopAlarm();
    await _player?.dispose();
    _player = null;
  }
}
