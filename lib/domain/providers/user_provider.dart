import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/user_datasource.dart';
import '../../data/models/user.dart';
import '../../data/repositories/user_repository.dart';
import 'auth_provider.dart';

final userDataSourceProvider = Provider<UserDataSource>((ref) {
  return UserDataSource(ref.watch(dioClientProvider).dio);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(userDataSourceProvider));
});

class UserState {
  final User? user;
  final bool isLoading;
  final String? error;

  const UserState({this.user, this.isLoading = false, this.error});

  UserState copyWith({User? user, bool? isLoading, String? error}) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final UserRepository _repository;
  final Ref _ref;

  UserNotifier(this._repository, this._ref) : super(const UserState());

  Future<void> loadCurrentUser() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      // If the server explicitly rejects the token (4xx), force logout.
      if (e is DioException &&
          e.response != null &&
          e.response!.statusCode != null &&
          e.response!.statusCode! >= 400 &&
          e.response!.statusCode! < 500) {
        await _ref.read(authProvider.notifier).logout();
        return;
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Returns true on success.
  Future<bool> updateUser(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateUser(data);
      final user = await _repository.getCurrentUser();
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Returns the S3 URL on success, null on failure.
  Future<String?> uploadProfileImage(String filePath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = await _repository.uploadProfileImage(filePath);
      final user = await _repository.getCurrentUser();
      state = state.copyWith(isLoading: false, user: user);
      return url;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void clearUser() {
    state = const UserState();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final notifier = UserNotifier(ref.watch(userRepositoryProvider), ref);

  // Auto-fetch user when authenticated; clear when logged out.
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
      notifier.loadCurrentUser();
    } else if (!next.isAuthenticated) {
      notifier.clearUser();
    }
  });

  // Fetch immediately if already authenticated when provider is first read.
  if (ref.read(authProvider).isAuthenticated) {
    Future.microtask(notifier.loadCurrentUser);
  }

  return notifier;
});
