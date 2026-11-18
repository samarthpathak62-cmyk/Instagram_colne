import 'package:flutter/material.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

/// Responsive entry point: an editorial brand cover beside the form on wide
/// screens and behind the compact wordmark on phones.
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
          final wide = constraints.maxWidth >= 840;
          final vertical = wide ? 28.0 : 18.0;
          return Stack(fit: StackFit.expand, children: [
            if (!wide && context.veyroColors.brightness == Brightness.dark) ...[
              const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 300,
                  child: VeyroOrbitArtwork(alignment: Alignment(0, -.36))),
              const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 305,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                          Color(0x8A100D17),
                          Color(0xCD100D17),
                          VeyroTheme.midnight
                        ])),
                  )),
            ],
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: wide ? 28 : 15, vertical: vertical),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - vertical * 2)
                        .clamp(0.0, double.infinity)
                        .toDouble()),
                child: Center(
                    child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1008 : 444),
                  child: wide
                      ? Row(children: [
                          const Expanded(flex: 6, child: _BrandCover()),
                          const SizedBox(width: 25),
                          Expanded(flex: 5, child: _panel(context)),
                        ])
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          const VeyroWordmark(size: 36),
                          const SizedBox(height: 3),
                          const VeyroTagline(),
                          const SizedBox(height: 20),
                          _panel(context),
                        ]),
                )),
              ),
            ),
          ]);
        },
      )));

  Widget _panel(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 13),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VeyroEyebrow('Your Veyro'),
                const SizedBox(height: 7),
                Semantics(
                    header: true,
                    child:
                        Text(heading, style: context.veyroText.headlineMedium)),
                const SizedBox(height: 7),
                Text(description,
                    style: context.veyroText.bodyMedium?.copyWith(
                        color: context.veyroColors.onSurfaceVariant,
                        height: 1.5)),
                const SizedBox(height: 21),
                form,
                const SizedBox(height: 15),
                const Divider(),
                const SizedBox(height: 6),
                footer,
              ]),
        ),
      ));
}

class _BrandCover extends StatelessWidget {
  const _BrandCover();

  @override
  Widget build(BuildContext context) => Material(
        color: VeyroTheme.midnight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFF433052))),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          const Positioned.fill(
              child: VeyroOrbitArtwork(alignment: Alignment.topCenter)),
          const Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x50100D17),
              Colors.transparent,
              Color(0xB0100D17),
              VeyroTheme.midnight
            ],
            stops: [0, .28, .72, 1],
          )))),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 560),
            child: Padding(
                padding: const EdgeInsets.all(29),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const VeyroWordmark(size: 34, color: VeyroTheme.frost),
                    const SizedBox(height: 233),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const VeyroEyebrow('Connect. Share. Explore.',
                              color: VeyroTheme.lilac),
                          const SizedBox(height: 9),
                          Text('Share life in\nyour own orbit.',
                              style: context.veyroText.headlineLarge?.copyWith(
                                  color: VeyroTheme.frost,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.4,
                                  height: 1.02)),
                          const SizedBox(height: 12),
                          Text(AppConstants.appDescription,
                              style: context.veyroText.bodyMedium?.copyWith(
                                  color: const Color(0xFFDCCDEB),
                                  height: 1.55)),
                        ]),
                  ],
                )),
          ),
        ]),
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
