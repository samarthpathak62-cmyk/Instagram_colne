import 'package:flutter/material.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

/// Shared sign-in and registration frame. On phones, branding becomes a
/// compact header so the form stays usable with the software keyboard open.
class VeyroAuthLayout extends StatelessWidget {
  final String heading;
  final String description;
  final Widget form;
  final Widget footer;

  const VeyroAuthLayout({
    super.key,
    required this.heading,
    required this.description,
    required this.form,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    return Scaffold(
      body: VeyroAtmosphere(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final vertical = wide ? 36.0 : 16.0;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 16,
                  vertical: vertical,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - vertical * 2)
                        .clamp(0.0, double.infinity)
                        .toDouble(),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1040 : 446),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x73040207),
                              blurRadius: 48,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: wide
                              ? _wideFrame(context)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _CompactBrand(),
                                    const Divider(),
                                    _panel(context, false),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // The form sets the height. The artwork fits that space instead of asking
  // a text field or an expanding render box to estimate its intrinsic height.
  Widget _wideFrame(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final artWidth = (constraints.maxWidth - 1) * 11 / 21;
          return Stack(
            children: [
              PositionedDirectional(
                start: 0,
                width: artWidth,
                top: 0,
                bottom: 0,
                child: const _BrandPanel(),
              ),
              PositionedDirectional(
                start: artWidth,
                width: 1,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: context.veyroColors.outlineVariant),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(start: artWidth + 1),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 518),
                  child: _panel(context, true),
                ),
              ),
            ],
          );
        },
      );

  Widget _panel(BuildContext context, bool wide) => ColoredBox(
        color: context.veyroColors.surfaceContainerLow,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 42 : 22,
              vertical: wide ? 40 : 26,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 370),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      heading,
                      style: context.veyroText.headlineMedium?.copyWith(
                        fontSize: wide ? 34 : 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: context.veyroText.bodyMedium?.copyWith(
                      color: context.veyroColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 27),
                  form,
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 8),
                  footer,
                ],
              ),
            ),
          ),
        ),
      );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => VeyroAtmosphere(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const VeyroMark(size: 70),
              const SizedBox(width: 3),
              const Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VeyroWordmark(
                        size: 28, showMark: false, color: VeyroTheme.frost),
                    SizedBox(height: 3),
                    VeyroTagline(color: Color(0xFFD5BFF3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => VeyroAtmosphere(
        rings: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 25),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const VeyroMark(size: 228),
                    const VeyroWordmark(
                        size: 64, showMark: false, color: VeyroTheme.frost),
                    const SizedBox(height: 14),
                    const VeyroTagline(color: VeyroTheme.lavender),
                    const SizedBox(height: 34),
                    Text(
                      AppConstants.appDescription,
                      style: context.veyroText.bodyMedium?.copyWith(
                        color: const Color(0xFFD5C6E8),
                        fontSize: 15,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
