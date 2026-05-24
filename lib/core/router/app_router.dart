import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/features/auth/screens/otp_verify_screen.dart';
import 'package:tecnm_chat/features/auth/screens/phone_input_screen.dart';
import 'package:tecnm_chat/features/calls/screens/call_screen.dart';
import 'package:tecnm_chat/features/calls/screens/incoming_call_screen.dart';
import 'package:tecnm_chat/features/chat/screens/chat_screen.dart';
import 'package:tecnm_chat/features/contacts/screens/add_contact_screen.dart';
import 'package:tecnm_chat/features/contacts/screens/contacts_list_screen.dart';
import 'package:tecnm_chat/features/conversations/screens/conversations_screen.dart';
import 'package:tecnm_chat/features/groups/screens/create_group_screen.dart';
import 'package:tecnm_chat/features/groups/screens/group_detail_screen.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';
import 'package:tecnm_chat/features/profile/screens/profile_edit_screen.dart';
import 'package:tecnm_chat/features/profile/screens/profile_setup_screen.dart';
import 'package:tecnm_chat/features/board/screens/academic_board_screen.dart';
import 'package:tecnm_chat/features/stories/screens/add_story_screen.dart';
import 'package:tecnm_chat/features/stories/screens/story_view_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/auth/phone',
    refreshListenable: authNotifier,
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final isAuthenticated = user != null;
      final isOnAuth = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isOnAuth) {
        return '/auth/phone';
      }

      if (isAuthenticated && state.matchedLocation == '/auth/phone') {
        final userDoc = await ref.read(currentUserProvider.future);
        if (userDoc == null) return '/auth/profile-setup';
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/phone',
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) => const OtpVerifyScreen(),
      ),
      GoRoute(
        path: '/auth/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsListScreen(),
      ),
      GoRoute(
        path: '/contacts/add',
        builder: (context, state) => const AddContactScreen(),
      ),
      GoRoute(
        path: '/group/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/call/:id',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final isReceiver = extra?['isReceiver'] as bool? ?? false;
          return CallScreen(
            otherUid: state.pathParameters['id']!,
            isReceiver: isReceiver,
          );
        },
      ),
      GoRoute(
        path: '/story/add',
        builder: (context, state) => const AddStoryScreen(),
      ),
      GoRoute(
        path: '/story/:uid',
        builder: (context, state) => StoryViewScreen(
          authorUid: state.pathParameters['uid']!,
        ),
      ),
      GoRoute(
        path: '/board',
        builder: (context, state) => const AcademicBoardScreen(),
      ),
      GoRoute(
        path: '/group/:id/detail',
        builder: (context, state) => GroupDetailScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/incoming-call/:callId/:channelName/:callerUid',
        builder: (context, state) => IncomingCallScreen(
          callId: state.pathParameters['callId']!,
          channelName: state.pathParameters['channelName']!,
          callerUid: state.pathParameters['callerUid']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Ruta no encontrada: ${state.error}'),
      ),
    ),
  );
});

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) : _ref = ref {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
  // ignore: unused_field
  final Ref _ref;
}
