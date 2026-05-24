import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:uuid/uuid.dart';

class CallModel {
  final String callId;
  final String callerUid;
  final String receiverUid;
  final String channelName;
  final String status;

  const CallModel({
    required this.callId,
    required this.callerUid,
    required this.receiverUid,
    required this.channelName,
    required this.status,
  });

  factory CallModel.fromJson(Map<String, dynamic> json, String docId) {
    return CallModel(
      callId: docId,
      callerUid: json['callerUid'] as String,
      receiverUid: json['receiverUid'] as String,
      channelName: json['channelName'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'callerUid': callerUid,
        'receiverUid': receiverUid,
        'channelName': channelName,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

sealed class CallState {
  const CallState();
}

class CallIdle extends CallState {
  const CallIdle();
}

class CallConnecting extends CallState {
  const CallConnecting();
}

class CallActive extends CallState {
  final int? remoteUid;
  final bool muted;
  final bool cameraOff;
  const CallActive({this.remoteUid, this.muted = false, this.cameraOff = false});

  CallActive copyWith({int? remoteUid, bool? muted, bool? cameraOff}) {
    return CallActive(
      remoteUid: remoteUid ?? this.remoteUid,
      muted: muted ?? this.muted,
      cameraOff: cameraOff ?? this.cameraOff,
    );
  }
}

class CallEnded extends CallState {
  const CallEnded();
}

class CallError extends CallState {
  final String message;
  const CallError(this.message);
}

class CallsController extends StateNotifier<CallState> {
  CallsController() : super(const CallIdle());

  RtcEngine? _engine;
  String? _currentCallId;
  String? _currentChannelName;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callStatusSub;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> startCall(String receiverUid) async {
    state = const CallConnecting();
    try {
      final myUid = _auth.currentUser!.uid;
      final channelName = const Uuid().v4();
      final callId = const Uuid().v4();

      final call = CallModel(
        callId: callId,
        callerUid: myUid,
        receiverUid: receiverUid,
        channelName: channelName,
        status: 'calling',
      );

      await _firestore.collection('calls').doc(callId).set(call.toJson());
      _currentCallId = callId;

      _listenCallStatus(callId);
      await _joinChannel(channelName);
    } catch (e) {
      state = CallError('Error al iniciar la llamada: ${e.toString()}');
    }
  }

  Future<void> joinCall(String callId, String channelName) async {
    state = const CallConnecting();
    try {
      _currentCallId = callId;
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ongoing',
      });
      _listenCallStatus(callId);
      await _joinChannel(channelName);
    } catch (e) {
      state = CallError('Error al unirse a la llamada: ${e.toString()}');
    }
  }

  /// Escucha el documento de la llamada en Firestore y finaliza si el otro cuelga.
  void _listenCallStatus(String callId) {
    _callStatusSub?.cancel();
    _callStatusSub = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final status = snap.data()?['status'] as String?;
      if (status == 'ended' && state is! CallEnded) {
        _cleanup();
        state = const CallEnded();
      }
    });
  }

  Future<void> _joinChannel(String channelName) async {
    // Request camera + microphone at runtime before touching Agora.
    await [Permission.camera, Permission.microphone].request();

    _currentChannelName = channelName;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      const RtcEngineContext(
        appId: AppConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (state is CallConnecting) state = const CallActive();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          final current = state;
          if (current is CallActive) {
            state = current.copyWith(remoteUid: remoteUid);
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (state is! CallEnded) endCall();
        },
        onError: (err, msg) {
          state = CallError('Error Agora (${err.name}): $msg');
        },
      ),
    );

    await _engine!.enableAudio();
    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: '',
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> toggleMute() async {
    final current = state;
    if (current is! CallActive) return;
    final newMuted = !current.muted;
    await _engine?.muteLocalAudioStream(newMuted);
    state = current.copyWith(muted: newMuted);
  }

  Future<void> toggleCamera() async {
    final current = state;
    if (current is! CallActive) return;
    final newCameraOff = !current.cameraOff;
    await _engine?.muteLocalVideoStream(newCameraOff);
    state = current.copyWith(cameraOff: newCameraOff);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> endCall() async {
    final callId = _currentCallId;
    _cleanup();
    if (callId != null) {
      try {
        await _firestore.collection('calls').doc(callId).update({
          'status': 'ended',
        });
      } catch (_) {}
    }
    state = const CallEnded();
  }

  void _cleanup() {
    _callStatusSub?.cancel();
    _callStatusSub = null;
    _engine?.leaveChannel();
    _engine?.release();
    _engine = null;
    _currentCallId = null;
    _currentChannelName = null;
  }

  RtcEngine? get engine => _engine;
  String? get channelName => _currentChannelName;

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// Sin autoDispose: el controlador persiste y mantiene el estado de la llamada
// mientras el usuario navega entre pantallas.
final callsControllerProvider =
    StateNotifierProvider<CallsController, CallState>(
  (_) => CallsController(),
);

final incomingCallProvider = StreamProvider<CallModel?>((ref) {
  final myUid = FirebaseAuth.instance.currentUser?.uid;
  if (myUid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('calls')
      .where('receiverUid', isEqualTo: myUid)
      .where('status', isEqualTo: 'calling')
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    return CallModel.fromJson(snap.docs.first.data(), snap.docs.first.id);
  });
});
