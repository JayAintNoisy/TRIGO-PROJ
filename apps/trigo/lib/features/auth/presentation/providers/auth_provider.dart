import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_repository.dart';

const String _kActiveMode = 'trigo_mode';

/// True once the user has committed to a passenger or driver role.
/// First-run users without a stored mode see the onboarding showcase.
Future<bool> hasStoredMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_kActiveMode);
}

Future<void> _persistMode(AppUserMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kActiveMode, mode.name);
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final String? role;
  final String? phone;
  final String? profilePhotoUrl;
  final AppUserMode activeMode;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.role,
    this.phone,
    this.profilePhotoUrl,
    this.activeMode = AppUserMode.customer,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    String? token,
    String? userId,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? profilePhotoUrl,
    AppUserMode? activeMode,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: clearError ? null : (error ?? this.error),
      token: clearUser ? null : (token ?? this.token),
      userId: clearUser ? null : (userId ?? this.userId),
      name: clearUser ? null : (name ?? this.name),
      email: clearUser ? null : (email ?? this.email),
      role: clearUser ? null : (role ?? this.role),
      phone: clearUser ? null : (phone ?? this.phone),
      profilePhotoUrl:
          clearUser ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      activeMode: activeMode ?? this.activeMode,
    );
  }

  static const empty = AuthState();
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  @override
  set state(AuthState newState) {
    authRedirectNotifier.value = newState.isAuthenticated;
    super.state = newState;
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.login(email, password);
      final activeMode = response.user.role == 'driver'
          ? AppUserMode.driver
          : AppUserMode.customer;
      await _persistMode(activeMode);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.accessToken,
        userId: response.user.id,
        name: response.user.name,
        email: response.user.email,
        role: response.user.role,
        phone: response.user.phone,
        profilePhotoUrl: response.user.profilePhotoUrl,
        activeMode: activeMode,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required bool asDriver,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
      // The registration choice commits the user's initial mode permanently
      final activeMode =
          asDriver ? AppUserMode.driver : AppUserMode.customer;
      await _persistMode(activeMode);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: response.accessToken,
        userId: response.user.id,
        name: response.user.name,
        email: response.user.email,
        role: response.user.role,
        phone: response.user.phone,
        profilePhotoUrl: response.user.profilePhotoUrl,
        activeMode: activeMode,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await tokenProvider.getToken();
    if (token == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.getCurrentUser();
      // Drivers resume in whichever mode they last used
      var activeMode =
          user.role == 'driver' ? AppUserMode.driver : AppUserMode.customer;
      if (user.role == 'driver' &&
          prefs.getString(_kActiveMode) == AppUserMode.customer.name) {
        activeMode = AppUserMode.customer;
      }
      // Persist so returning users skip the showcase on the next cold start
      if (!prefs.containsKey(_kActiveMode)) {
        await prefs.setString(_kActiveMode, activeMode.name);
      }
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        token: token,
        userId: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        profilePhotoUrl: user.profilePhotoUrl,
        activeMode: activeMode,
      );
    } catch (_) {
      state = const AuthState();
    }
  }

  void toggleMode(AppUserMode mode) {
    // Only approved drivers may enter driving mode; debug builds bypass the
    // guard so either UI can be previewed with any account
    if (!kDebugMode && mode == AppUserMode.driver && state.role != 'driver') {
      return;
    }
    state = state.copyWith(activeMode: mode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kActiveMode, mode.name);
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
