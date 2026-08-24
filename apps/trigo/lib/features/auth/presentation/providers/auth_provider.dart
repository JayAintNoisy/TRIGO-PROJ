import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_response.dart';

const String _kOnboarded = 'trigo_onboarded';

/// True once the user has successfully logged in or registered; returning
/// users skip the onboarding showcase and land on Login.
Future<bool> hasOnboarded() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboarded) ?? false;
}

Future<void> _markOnboarded() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboarded, true);
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool isBootstrapped;
  final String? error;
  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final String? role;
  final String? phone;
  final String? profilePhotoUrl;
  final String? driverStatus;
  final AppUserMode activeMode;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isBootstrapped = false,
    this.error,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.role,
    this.phone,
    this.profilePhotoUrl,
    this.driverStatus,
    this.activeMode = AppUserMode.customer,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? isBootstrapped,
    String? error,
    String? token,
    String? userId,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? profilePhotoUrl,
    String? driverStatus,
    AppUserMode? activeMode,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isBootstrapped: isBootstrapped ?? this.isBootstrapped,
      error: clearError ? null : (error ?? this.error),
      token: clearUser ? null : (token ?? this.token),
      userId: clearUser ? null : (userId ?? this.userId),
      name: clearUser ? null : (name ?? this.name),
      email: clearUser ? null : (email ?? this.email),
      role: clearUser ? null : (role ?? this.role),
      phone: clearUser ? null : (phone ?? this.phone),
      profilePhotoUrl:
          clearUser ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      driverStatus: clearUser ? null : (driverStatus ?? this.driverStatus),
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
    authRedirectNotifier.value = newState;
    super.state = newState;
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.login(email, password);
      await _markOnboarded();
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
        driverStatus: response.user.driverStatus,
        activeMode: _modeFor(response.user),
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
    required String firstName,
    required String lastName,
    required String phone,
    required bool asDriver,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        asDriver: asDriver,
      );
      await _markOnboarded();
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
        driverStatus: response.user.driverStatus,
        activeMode: _modeFor(response.user),
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
    try {
      if (token == null) {
        state = const AuthState(isBootstrapped: true);
        return;
      }

      state = state.copyWith(isLoading: true);
      final user = await _repository.getCurrentUser();
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        isBootstrapped: true,
        token: token,
        userId: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        profilePhotoUrl: user.profilePhotoUrl,
        driverStatus: user.driverStatus,
        activeMode: _modeFor(user),
      );
    } catch (_) {
      state = const AuthState(isBootstrapped: true);
    }
  }

  /// Re-fetches the current user so role/status changes (e.g. an approval)
  /// reflect immediately without a full re-login.
  Future<void> refreshCurrentUser() async {
    try {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(
        userId: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        phone: user.phone,
        profilePhotoUrl: user.profilePhotoUrl,
        driverStatus: user.driverStatus,
        activeMode: _modeFor(user),
      );
    } catch (_) {
      // Keep the current session; a failed refresh is non-fatal.
    }
  }

  /// The mode is determined by the backend response: an account with a driver
  /// profile (any application status), a driver role, or a stored driver
  /// registration intent is a driver account; everyone else is a customer.
  /// Users cannot switch freely.
  AppUserMode _modeFor(UserData user) {
    return user.driverIntent ||
            user.driverStatus != null ||
            user.role == 'driver'
        ? AppUserMode.driver
        : AppUserMode.customer;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(isBootstrapped: true);
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
