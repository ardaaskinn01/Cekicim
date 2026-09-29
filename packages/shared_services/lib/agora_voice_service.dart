import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'supabase_service.dart';

class AgoraVoiceService {
  RtcEngine? _engine;
  bool _isInitialized = false;

  RtcEngine? get engine => _engine;

  /// Agora Edge Function'dan güvenli, tek kullanımlık RTC Token alır.
  Future<Map<String, dynamic>> _fetchToken(String channelId, int uid) async {
    final response = await SupabaseService.instance.client.functions.invoke(
      'get-rtc-token',
      body: {
        'channel_name': channelId,
        'uid': uid,
      },
    );

    if (response.status != 200 || response.data == null) {
      throw Exception('Token alınamadı: ${response.data?['error'] ?? 'Bilinmeyen hata'}');
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> initialize(String appId) async {
    if (_isInitialized) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await _engine!.enableAudio();
    _isInitialized = true;
  }

  Future<void> joinChannel(
    String channelId,
    int uid, {
    Function(int uid)? onUserJoined,
    Function(int uid)? onUserOffline,
  }) async {
    // 1. Supabase Edge Function'dan güvenli token ve App ID al
    final tokenData = await _fetchToken(channelId, uid);
    final token = tokenData['token'] as String;
    final appId = tokenData['appId'] as String;

    // 2. Agora motorunu üretim modunda başlat
    await initialize(appId);

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Kanala başarıyla bağlanıldı: ${connection.channelId}");
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Kullanıcı bağlandı: $remoteUid");
          if (onUserJoined != null) onUserJoined(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Kullanıcı ayrıldı: $remoteUid");
          if (onUserOffline != null) onUserOffline(remoteUid);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String newToken) async {
          // Token süresi dolmak üzere: otomatik yenile
          final refreshed = await _fetchToken(channelId, uid);
          await _engine?.renewToken(refreshed['token'] as String);
        },
      ),
    );

    // 3. Production token ile odaya katıl
    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  Future<void> toggleMute(bool mute) async {
    if (_engine != null) {
      await _engine!.muteLocalAudioStream(mute);
    }
  }

  Future<void> toggleSpeaker(bool speaker) async {
    if (_engine != null) {
      await _engine!.setEnableSpeakerphone(speaker);
    }
  }

  Future<void> leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
    }
  }
}
