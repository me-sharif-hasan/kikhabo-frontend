import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/datasources/dio_client.dart';
import '../../data/datasources/auth_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';

// Dependency Injection
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(ref.watch(secureStorageProvider));
});

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  return AuthDataSource(ref.watch(dioClientProvider).dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authDataSourceProvider));
});

// Auth State
class AuthState {
  final bool isLoading;
  final User? user;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? error,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._repository, this._storage) : super(const AuthState());

  /// Verifies auth by calling the server with the stored token.
  /// - No token locally → not authenticated
  /// - Server returns 4xx → token expired/invalid → not authenticated (clears stored token)
  /// - Server returns 2xx → authenticated
  /// - Network error → falls back to trusting the local token (offline support)
  Future<void> checkAuthStatus() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    debugPrint('[Auth] checkAuthStatus: local token=${token != null ? "found" : "null"}');

    if (token == null) {
      debugPrint('[Auth] checkAuthStatus: no token → not authenticated');
      return;
    }

    try {
      final valid = await _repository.verifyAuth();
      if (valid) {
        debugPrint('[Auth] checkAuthStatus: server verified ✓');
        state = state.copyWith(isAuthenticated: true);
      } else {
        // 4xx — token rejected by server, clear it
        debugPrint('[Auth] checkAuthStatus: server rejected token → clearing');
        await _storage.delete(key: AppConstants.tokenKey);
      }
    } catch (e) {
      // Network error — trust the local token so the app works offline
      debugPrint('[Auth] checkAuthStatus: network error ($e) → trusting local token');
      state = state.copyWith(isAuthenticated: true);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.login(email, password);
      await _storage.write(key: AppConstants.tokenKey, value: response.token);
      state = state.copyWith(isLoading: false, isAuthenticated: true);
      _registerFcmToken();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _registerFcmToken() async {
    final token = await NotificationService.instance.getToken();
    if (token != null) {
      await _repository.registerFcmToken(token);
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 1. Sign out any cached Google session so the account picker always appears
      final _googleSignIn = GoogleSignIn();
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled — not an error
        state = state.copyWith(isLoading: false);
        return;
      }

      // 2. Get auth details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a Firebase credential and sign in
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 4. Get the Firebase ID token — this is what the backend needs
      final String? firebaseIdToken =
          await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw Exception('Failed to get Firebase ID token');
      }

      // 5. Exchange with our backend for a JWT
      final response = await _repository.socialLogin(firebaseIdToken);
      await _storage.write(key: AppConstants.tokenKey, value: response.token);
      state = state.copyWith(isLoading: false, isAuthenticated: true);
      _registerFcmToken();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(UserDto userDto) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.register(userDto);
      state = state.copyWith(isLoading: false);
      // Registration successful, usually navigate to login or auto-login
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    final token = await NotificationService.instance.getToken();
    if (token != null) {
      await _repository.deleteFcmToken(token);
    }
    await _storage.delete(key: AppConstants.tokenKey);
    state = const AuthState(isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(secureStorageProvider),
  );
});
