import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthCodeSent extends AuthState {
  const AuthCodeSent();
}

class AuthSuccess extends AuthState {
  final bool isNewUser;
  const AuthSuccess({required this.isNewUser});
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthInitial());

  String? _verificationId;
  int? _resendToken;

  Future<void> sendOtp(String phoneNumber) async {
    state = const AuthLoading();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signIn(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        final msg = _mapAuthError(e.code);
        state = AuthError(msg);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        state = const AuthCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      forceResendingToken: _resendToken,
    );
  }

  Future<void> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      state = const AuthError('Debes solicitar primero el código OTP.');
      return;
    }

    state = const AuthLoading();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _signIn(credential);
    } on FirebaseAuthException catch (e) {
      state = AuthError(_mapAuthError(e.code));
    } catch (e) {
      state = AuthError('Error inesperado: ${e.toString()}');
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      state = AuthSuccess(isNewUser: !doc.exists);
    } on FirebaseAuthException catch (e) {
      state = AuthError(_mapAuthError(e.code));
    } catch (e) {
      state = AuthError('Error al iniciar sesión: ${e.toString()}');
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'El número de teléfono no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento antes de intentar de nuevo.';
      case 'invalid-verification-code':
        return 'El código OTP es incorrecto. Verifica e intenta de nuevo.';
      case 'session-expired':
        return 'El código OTP ha expirado. Solicita uno nuevo.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'network-request-failed':
        return 'Error de red. Verifica tu conexión a internet.';
      default:
        return 'Error de autenticación ($code). Intenta de nuevo.';
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (_) => AuthController(),
);

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
