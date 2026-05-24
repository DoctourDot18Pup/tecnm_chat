import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/features/calls/controllers/calls_controller.dart';

class CallScreen extends ConsumerStatefulWidget {
  /// UID del otro participante (receptor si somos caller, caller si somos receptor).
  final String otherUid;

  /// true cuando este dispositivo está aceptando una llamada entrante.
  /// false (default) cuando este dispositivo inició la llamada.
  final bool isReceiver;

  const CallScreen({
    super.key,
    required this.otherUid,
    this.isReceiver = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    // Solo el emisor inicia la llamada; el receptor ya ejecutó joinCall()
    // en IncomingCallScreen._accept() antes de navegar aquí.
    if (!widget.isReceiver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(callsControllerProvider.notifier)
            .startCall(widget.otherUid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CallState>(callsControllerProvider, (_, state) {
      if (state is CallEnded) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      } else if (state is CallError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    });

    final callState = ref.watch(callsControllerProvider);
    final controller = ref.read(callsControllerProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Video remoto (pantalla completa)
              if (callState is CallActive && callState.remoteUid != null)
                _RemoteView(
                  engine: controller.engine!,
                  remoteUid: callState.remoteUid!,
                  channelName: controller.channelName ?? '',
                ),

              // Conectando...
              if (callState is CallConnecting ||
                  (callState is CallActive && callState.remoteUid == null))
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Conectando...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),

              // Vista local (miniatura en esquina)
              if (callState is CallActive && controller.engine != null)
                Positioned(
                  top: 16,
                  right: 16,
                  width: 120,
                  height: 180,
                  child: _LocalView(engine: controller.engine!),
                ),

              // Controles
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: _buildControls(callState, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(CallState callState, CallsController controller) {
    final isMuted = callState is CallActive && callState.muted;
    final isCameraOff = callState is CallActive && callState.cameraOff;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallButton(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Activar mic' : 'Silenciar',
          color: isMuted ? Colors.red.shade400 : Colors.white24,
          onTap: controller.toggleMute,
        ),
        _CallButton(
          icon: Icons.call_end,
          label: 'Colgar',
          color: Colors.red,
          size: 64,
          onTap: controller.endCall,
        ),
        _CallButton(
          icon: isCameraOff ? Icons.videocam_off : Icons.cameraswitch,
          label: isCameraOff ? 'Activar cam' : 'Cambiar cam',
          color: isCameraOff ? Colors.red.shade400 : Colors.white24,
          onTap: isCameraOff ? controller.toggleCamera : controller.switchCamera,
        ),
      ],
    );
  }
}

class _RemoteView extends StatelessWidget {
  final RtcEngine engine;
  final int remoteUid;
  final String channelName;

  const _RemoteView({
    required this.engine,
    required this.remoteUid,
    required this.channelName,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      ),
    );
  }
}

class _LocalView extends StatelessWidget {
  final RtcEngine engine;

  const _LocalView({required this.engine});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: size / 2,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
