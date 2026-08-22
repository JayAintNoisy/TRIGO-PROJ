import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/input_validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_top_bar.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).register(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
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
      appBar: const AppTopBar(title: 'Create Account'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
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
              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      label: 'First Name',
                      hint: 'Juan',
                      controller: _firstNameController,
                      validator: InputValidators.required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppInput(
                      label: 'Last Name',
                      hint: 'Dela Cruz',
                      controller: _lastNameController,
                      validator: InputValidators.required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Email Address',
                hint: 'user@trigo.ph',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: InputValidators.email,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Mobile Phone',
                hint: '+63 917 123 4567',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: InputValidators.phone,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Password',
                hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                controller: _passwordController,
                isPassword: true,
                validator: (value) => InputValidators.minLength(
                    6, value, 'Password must be at least 6 characters'),
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Confirm Password',
                hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                controller: _confirmPasswordController,
                isPassword: true,
                validator: (value) => InputValidators.matches(
                    _passwordController.text, value),
              ),
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
    ),
    );
  }
}
