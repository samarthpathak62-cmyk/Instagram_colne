import 'package:flutter/material.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';

class VeyroAuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final bool enabled;
  final String? autofillHint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?) validator;
  final VoidCallback? onSubmit;

  const VeyroAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.isPassword = false,
    this.enabled = true,
    this.autofillHint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmit,
  });

  @override
  State<VeyroAuthField> createState() => _VeyroAuthFieldState();
}

class _VeyroAuthFieldState extends State<VeyroAuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.onSubmit == null
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted:
            widget.onSubmit == null ? null : (_) => widget.onSubmit!(),
        autofillHints:
            widget.autofillHint == null ? null : [widget.autofillHint!],
        obscureText: widget.isPassword && !_visible,
        autocorrect: false,
        enableSuggestions: !widget.isPassword,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon, size: 19),
          errorMaxLines: 3,
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _visible ? 'Hide password' : 'Show password',
                  onPressed: !widget.enabled
                      ? null
                      : () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                )
              : null,
        ),
      );
}

String? validateVeyroEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateVeyroPassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter your password.';
  if (value.length < AppConstants.minPasswordLength) {
    return 'Use at least ${AppConstants.minPasswordLength} characters.';
  }
  return null;
}
