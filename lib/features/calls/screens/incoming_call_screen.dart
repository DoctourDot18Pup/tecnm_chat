import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/features/calls/controllers/calls_controller.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String channelName;
  final String callerUid;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.callerUid,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  Future<void> _accept() async {
    await ref
        .read(callsControllerProvider.notifier)
        .joinCall(widget.callId, widget.channelName);
    if (mounted) {
      // isReceiver: true → CallScreen no llama startCall() de nuevo
      context.go(
        '/call/${widget.callerUid}',
        extra: {'isReceiver': true},
      );
    }
  }

  Future<void> _reject() async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'ended'});
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final callerAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 80),
            callerAsync.when(
              loading: () => const CircleAvatar(
                radius: 60,
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => const CircleAvatar(
                radius: 60,
                child: Icon(Icons.person, size: 60),
              ),
              data: (user) => const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Llamada entrante',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ITC Conecta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: _reject,
                      child: const CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.call_end, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rechazar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: _accept,
                      child: const CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.call, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aceptar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
