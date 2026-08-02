import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_repository.dart';

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
        activeMode: response.user.role == 'driver'
            ? AppUserMode.driver
            : AppUserMode.customer,
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
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
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
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> tryAutoLogin() async {
    final token = await tokenProvider.getToken();
    if (token == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.getCurrentUser();
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
        activeMode: user.role == 'driver'
            ? AppUserMode.driver
            : AppUserMode.customer,
      );
    } catch (_) {
      state = const AuthState();
    }
  }

  void toggleMode(AppUserMode mode) {
    state = state.copyWith(activeMode: mode);
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
