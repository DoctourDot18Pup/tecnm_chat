import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/core/router/app_router.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/features/calls/controllers/calls_controller.dart';
import 'package:tecnm_chat/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: TecNMChatApp()));
}

class TecNMChatApp extends ConsumerWidget {
  const TecNMChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ITC Conecta',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en', 'US'),
      ],
      builder: (context, child) => _IncomingCallListener(
        router: router,
        child: child!,
      ),
    );
  }
}

/// Escucha llamadas entrantes en Firestore desde cualquier pantalla de la app.
class _IncomingCallListener extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;

  const _IncomingCallListener({required this.router, required this.child});

  @override
  ConsumerState<_IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<_IncomingCallListener> {
  String? _activeCallId;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CallModel?>>(incomingCallProvider, (_, next) {
      final call = next.valueOrNull;

      // Evita navegar dos veces por la misma llamada
      if (call == null || call.callId == _activeCallId) return;
      _activeCallId = call.callId;

      widget.router.push(
        '/incoming-call/${call.callId}/${call.channelName}/${call.callerUid}',
      );
    });

    return widget.child;
  }
}
