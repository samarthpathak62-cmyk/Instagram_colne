import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/settings/domain/entities/settings.dart';
import 'package:instagram_clone/features/settings/presentation/bloc/settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  final String userId;

  const SettingsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SettingsBloc>();
    final colors = context.veyroColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsError) {
            return CustomErrorWidget(
              message: state.message,
              onRetry: () => bloc.add(GetSettingsEvent(userId: userId)),
            );
          }
          if (state is! SettingsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = state.settings;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                children: [
                  _section(
                    context,
                    'Appearance',
                    RadioGroup<AppThemeMode>(
                      groupValue: settings.themeMode,
                      onChanged: (value) {
                        if (value != null)
                          bloc.add(UpdateThemeModeEvent(
                              userId: userId, themeMode: value));
                      },
                      child: const Column(children: [
                        RadioListTile(
                            value: AppThemeMode.dark,
                            title: Text('Veyro Midnight')),
                        RadioListTile(
                            value: AppThemeMode.light,
                            title: Text('Veyro Light')),
                        RadioListTile(
                            value: AppThemeMode.system,
                            title: Text('Use device setting')),
                      ]),
                    ),
                  ),
                  _section(
                    context,
                    'Language',
                    RadioGroup<String>(
                      groupValue: settings.language,
                      onChanged: (value) {
                        if (value != null)
                          bloc.add(UpdateLanguageEvent(
                              userId: userId, language: value));
                      },
                      child: const Column(children: [
                        RadioListTile(value: 'en', title: Text('English')),
                        RadioListTile(value: 'ar', title: Text('العربية')),
                      ]),
                    ),
                  ),
                  _section(
                    context,
                    'Notifications',
                    SwitchListTile(
                      title: const Text('Enable notifications'),
                      value: settings.notificationsEnabled,
                      onChanged: (value) => bloc.add(
                          UpdateNotificationsEnabledEvent(
                              userId: userId, enabled: value)),
                    ),
                  ),
                  _section(
                    context,
                    'About',
                    ListTile(
                      leading: const VeyroMark(size: 38),
                      title: const Text('About Veyro'),
                      subtitle:
                          const Text('Version ${AppConstants.appVersion}'),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationIcon: const VeyroMark(size: 52),
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                        children: const [Text(AppConstants.appDescription)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: colors.error),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                    label: const Text('Log out'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 5, bottom: 7),
              child: Text(title, style: context.veyroText.titleMedium),
            ),
            Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: child),
          ],
        ),
      );

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of Veyro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log out',
                style: TextStyle(color: context.veyroColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }
}
