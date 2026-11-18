import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VeyroTheme.ink,
        body: VeyroAtmosphere(
          rings: true,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VeyroMark(size: 176),
                      const VeyroWordmark(
                          size: 43, showMark: false, color: VeyroTheme.frost),
                      const SizedBox(height: 14),
                      const VeyroTagline(color: VeyroTheme.lavender),
                      const SizedBox(height: 36),
                      Container(
                        width: 60,
                        height: 4,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4)),
                        child: const LinearProgressIndicator(
                          color: VeyroTheme.lavender,
                          backgroundColor: Color(0xFF39265C),
                          semanticsLabel: 'Loading Veyro',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
