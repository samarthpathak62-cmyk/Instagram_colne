import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_clone/generated/app_localizations.dart';

void main() {
  test('loads the English and Arabic translations', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final arabic = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(english.appName, 'Veyro');
    expect(arabic.appName, 'Veyro');
    expect(english.feedTitle, 'Veyro');
    expect(arabic.feedTitle, 'Veyro');
    expect(english.loginButton, 'Log In');
    expect(arabic.loginButton, 'تسجيل الدخول');
  });
}
