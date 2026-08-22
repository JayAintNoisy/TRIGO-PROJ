import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/input_validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/utils/app_snackbar.dart';

class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
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
          asDriver: true,
        );
    if (!mounted) return;

    final state = ref.read(authProvider);
    if (!state.isAuthenticated) {
      showAppSnackBar(context,
          message: state.error ?? 'Registration failed', isError: true);
      ref.read(authProvider.notifier).state =
          ref.read(authProvider).copyWith(clearError: true);
      return;
    }

    // Account created — next step is submitting tricycle details for review
    context.pushReplacement('/driver/apply');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: const AppTopBar(title: 'Driver Registration'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Start Earning Today',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Step 1 of 2 \u2014 create your driver account',
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
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.electric_rickshaw,
                        size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next, you will submit your tricycle details and '
                        'documents for verification by the municipal office.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Continue to Verification',
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
