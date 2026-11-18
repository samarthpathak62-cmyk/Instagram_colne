import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/screens/signup_screen.dart';
import 'package:instagram_clone/features/auth/presentation/widgets/veyro_auth_field.dart';
import 'package:instagram_clone/features/auth/presentation/widgets/veyro_auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    final auth = context.read<AuthBloc>();
    if (auth.state is AuthLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    auth.add(AuthLoginRequested(
        email: _email.text.trim(), password: _password.text));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure &&
              ModalRoute.of(context)?.isCurrent == true) {
            showAuthError(context, 'Could not log in: ${state.message}');
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return VeyroAuthLayout(
            heading: 'Welcome back',
            description: 'Log in to catch up with your people.',
            form: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    VeyroAuthField(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      autofillHint: AutofillHints.email,
                      enabled: !loading,
                      validator: validateVeyroEmail,
                    ),
                    const SizedBox(height: 12),
                    VeyroAuthField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      autofillHint: AutofillHints.password,
                      isPassword: true,
                      enabled: !loading,
                      validator: validateVeyroPassword,
                      onSubmit: _login,
                    ),
                    const SizedBox(height: 20),
                    VeyroAuthSubmit(
                        label: 'Log in', loading: loading, onPressed: _login),
                  ],
                ),
              ),
            ),
            footer: VeyroAuthFooter(
              prompt: 'New to Veyro?',
              action: 'Create an account',
              onPressed: loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const SignupScreen()),
                      ),
            ),
          );
        },
      );
}
