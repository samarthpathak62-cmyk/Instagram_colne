import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/widgets/veyro_auth_field.dart';
import 'package:instagram_clone/features/auth/presentation/widgets/veyro_auth_layout.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signup() {
    final auth = context.read<AuthBloc>();
    if (auth.state is AuthLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    auth.add(AuthSignupRequested(
      email: _email.text.trim(),
      password: _password.text,
      username: _username.text.trim(),
      fullName: _fullName.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            showAuthError(
                context, 'Could not create your account: ${state.message}');
          } else if (state is AuthEmailConfirmationRequired) {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).popUntil((route) => route.isFirst);
            messenger.showSnackBar(SnackBar(
              content: Text(
                  'Check ${state.email} to confirm your account, then log in.'),
            ));
          } else if (state is Authenticated) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return VeyroAuthLayout(
            heading: 'Join Veyro',
            description:
                'Create an account to share your moments and find your people.',
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
                      controller: _fullName,
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      autofillHint: AutofillHints.name,
                      enabled: !loading,
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Enter at least 2 characters.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    VeyroAuthField(
                      controller: _username,
                      label: 'Username',
                      icon: Icons.alternate_email_rounded,
                      autofillHint: AutofillHints.newUsername,
                      enabled: !loading,
                      validator: (value) {
                        final username = value?.trim() ?? '';
                        if (username.length < 3)
                          return 'Enter at least 3 characters.';
                        if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
                          return 'Use letters, numbers, periods, or underscores.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    VeyroAuthField(
                      controller: _password,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      autofillHint: AutofillHints.newPassword,
                      isPassword: true,
                      enabled: !loading,
                      validator: validateVeyroPassword,
                      onSubmit: _signup,
                    ),
                    const SizedBox(height: 20),
                    VeyroAuthSubmit(
                      label: 'Create account',
                      loading: loading,
                      onPressed: _signup,
                    ),
                  ],
                ),
              ),
            ),
            footer: VeyroAuthFooter(
              prompt: 'Already on Veyro?',
              action: 'Log in',
              onPressed:
                  loading ? null : () => Navigator.of(context).maybePop(),
            ),
          );
        },
      );
}
