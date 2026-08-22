import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/utils/app_snackbar.dart';

class PassengerRegisterScreen extends ConsumerStatefulWidget {
  const PassengerRegisterScreen({super.key});

  @override
  ConsumerState<PassengerRegisterScreen> createState() =>
      _PassengerRegisterScreenState();
}

class _PassengerRegisterScreenState
    extends ConsumerState<PassengerRegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _fieldError = 'Please fill in all fields');
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateFields()) return;

    await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          asDriver: false,
        );
    final state = ref.read(authProvider);
    if (!state.isAuthenticated) {
      if (mounted) {
        showAppSnackBar(context,
            message: state.error ?? 'Registration failed', isError: true);
        ref.read(authProvider.notifier).state =
            ref.read(authProvider).copyWith(clearError: true);
      }
      return;
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join TriGo',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Create your passenger account',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              AppInput(
                label: 'Full Name',
                hint: 'Juan Dela Cruz',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Email Address',
                hint: 'user@trigo.ph',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Mobile Phone',
                hint: '+63 917 123 4567',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Password',
                hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                controller: _passwordController,
                isPassword: true,
              ),
              if (_fieldError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _fieldError!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              AppButton(
                label: 'Create Account',
                onPressed: authState.isLoading ? null : _handleRegister,
                isLoading: authState.isLoading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style:
                        TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
