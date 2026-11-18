import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VeyroTheme.midnight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: RadialGradient(
            colors: [Color(0xFF281741), VeyroTheme.midnight],
            radius: .75,
          )),
          child: SafeArea(
              child: Center(
                  child: Padding(
            padding: const EdgeInsets.all(20),
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const VeyroMark(size: 112),
                  VeyroWordmark(
                      size: 39, showMark: false, color: VeyroTheme.frost),
                  const SizedBox(height: 18),
                  const SizedBox(
                      width: 56,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: VeyroTheme.lilac,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        semanticsLabel: 'Loading Veyro',
                      )),
                ])),
          ))),
        ),
      );
}
