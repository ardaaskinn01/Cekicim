import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_ui/app_colors.dart';
import 'package:shared_services/agora_voice_service.dart';
import '../../providers/request_provider.dart';

class VoIPCallScreen extends ConsumerStatefulWidget {
  final String requestId;
  const VoIPCallScreen({super.key, required this.requestId});

  @override
  ConsumerState<VoIPCallScreen> createState() => _VoIPCallScreenState();
}

class _VoIPCallScreenState extends ConsumerState<VoIPCallScreen> with SingleTickerProviderStateMixin {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
  String _callStatus = "Bağlanıyor...";
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _checkPermissionsAndJoin();
  }

  Future<void> _checkPermissionsAndJoin() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _joinCall();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon izni verilmedi. Arama başlatılamıyor.'), backgroundColor: AppColors.error),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _joinCall() async {
    final channelId = 'call_${widget.requestId}';
    final uid = DateTime.now().millisecondsSinceEpoch % 100000;

    try {
      if (mounted) {
        setState(() {
          _callStatus = "Çalıyor...";
        });
      }

      await _voiceService.joinChannel(
        channelId,
        uid,
        onUserJoined: (remoteUid) {
          if (mounted) {
            setState(() {
              _isConnected = true;
              _callStatus = "00:00";
            });
            _startDurationTimer();
          }
        },
        onUserOffline: (remoteUid) {
          _endCall();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arama başlatılamadı (Lütfen .env dosyasında AGORA_APP_ID tanımlayın): $e'), backgroundColor: AppColors.error),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
          final minutes = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (_callDurationSeconds % 60).toString().padLeft(2, '0');
          _callStatus = "$minutes:$seconds";
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController?.dispose();
    _voiceService.leaveChannel();
    super.dispose();
  }

  void _endCall() async {
    await _voiceService.leaveChannel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _voiceService.toggleMute(_isMuted);
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      _voiceService.toggleSpeaker(_isSpeakerOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(requestStatusProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: requestAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (err, st) => Center(child: Text('Hata: $err', style: const TextStyle(color: AppColors.error))),
          data: (request) {
            const customerName = "Müşteri";

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // Security Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text(
                          'Maskeli Güvenli Arama (VoIP)',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Contact Name
                Center(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Call Status
                Center(
                  child: Text(
                    _callStatus,
                    style: TextStyle(
                      color: _isConnected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: _isConnected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

                const Spacer(),

                // Animated Pulse Visualizer
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse rings
                      if (!_isConnected)
                        ...List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _pulseController!,
                            builder: (context, child) {
                              final progress = (_pulseController!.value + index / 3) % 1.0;
                              return Container(
                                width: 120 + (160 * progress),
                                height: 120 + (160 * progress),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(1.0 - progress),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      // Audio visualizer lines when connected
                      if (_isConnected)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(10, (index) {
                            return AnimatedBuilder(
                              animation: _pulseController!,
                              builder: (context, child) {
                                final height = 15 + (45 * (index % 2 == 0 ? _pulseController!.value : (1.0 - _pulseController!.value)));
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 4,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      if (!_isConnected)
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Dialer Options (Mute, Speaker)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Mute
                      Column(
                        children: [
                          IconButton(
                            onPressed: _toggleMute,
                            icon: Icon(
                              _isMuted ? Icons.mic_off : Icons.mic,
                              color: _isMuted ? AppColors.error : AppColors.textPrimary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _isMuted ? AppColors.error.withOpacity(0.15) : AppColors.surface,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Sessiz', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                      // Speaker
                      Column(
                        children: [
                          IconButton(
                            onPressed: _toggleSpeaker,
                            icon: Icon(
                              _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                              color: _isSpeakerOn ? AppColors.accent : AppColors.textPrimary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _isSpeakerOn ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Hoparlör', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Decline Call Button
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: FloatingActionButton(
                      onPressed: _endCall,
                      backgroundColor: AppColors.error,
                      child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
