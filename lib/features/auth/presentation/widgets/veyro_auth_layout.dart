import 'package:flutter/material.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

/// Uses the same quiet canvas and simple white card as the social screens.
class VeyroAuthLayout extends StatelessWidget {
  final String heading;
  final String description;
  final Widget form;
  final Widget footer;

  const VeyroAuthLayout(
      {super.key,
      required this.heading,
      required this.description,
      required this.form,
      required this.footer});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SafeArea(child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final vertical = wide ? 36.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: wide ? 32 : 14, vertical: vertical),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - vertical * 2)
                      .clamp(0.0, double.infinity)
                      .toDouble()),
              child: Center(
                  child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 918 : 430),
                child: wide
                    ? Row(children: [
                        const Expanded(flex: 6, child: _BrandIntro(wide: true)),
                        const SizedBox(width: 40),
                        Expanded(flex: 5, child: _panel(context)),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        const _BrandIntro(wide: false),
                        const SizedBox(height: 14),
                        _panel(context),
                      ]),
              )),
            ),
          );
        },
      )));

  Widget _panel(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 23, 22, 13),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                    header: true,
                    child:
                        Text(heading, style: context.veyroText.headlineMedium)),
                const SizedBox(height: 7),
                Text(description,
                    style: context.veyroText.bodyMedium?.copyWith(
                        color: context.veyroColors.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 22),
                form,
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 6),
                footer,
              ]),
        ),
      ));
}

class _BrandIntro extends StatelessWidget {
  final bool wide;
  const _BrandIntro({required this.wide});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          VeyroWordmark(
              size: wide ? 58 : 33, color: context.veyroColors.primary),
          if (wide) ...[
            const SizedBox(height: 6),
            Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Text(
                  'Keep up with your people.',
                  style: context.veyroText.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                )),
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 14, 0),
                child: Text(
                  AppConstants.appDescription,
                  style: context.veyroText.bodyLarge?.copyWith(
                      color: context.veyroColors.onSurfaceVariant,
                      height: 1.55),
                )),
          ],
        ],
      );
}

class VeyroAuthFooter extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  const VeyroAuthFooter({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            prompt,
            style: context.veyroText.bodyMedium?.copyWith(
              color: context.veyroColors.onSurfaceVariant,
            ),
          ),
          TextButton(onPressed: onPressed, child: Text(action)),
        ],
      );
}

class VeyroAuthSubmit extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const VeyroAuthSubmit({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Please wait',
                ),
              )
            : Text(label),
      );
}

void showAuthError(BuildContext context, String message) {
  final colors = context.veyroColors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: colors.errorContainer,
      content: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    ));
}
