import 'package:flutter/material.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/features/settings/data/datasources/settings_remote_datasource.dart';
import 'package:instagram_clone/features/settings/data/models/settings_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final SupabaseClient supabaseClient;

  SettingsRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<SettingsModel> getSettings(String userId) async {
    try {
      final row = await supabaseClient
          .from('settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null
          ? await _upsert(userId, const {})
          : SettingsModel.fromJson(row);
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load settings: ${error.message}');
    }
  }

  @override
  Future<void> updateLanguage(String userId, String language) async {
    await _upsert(userId, {'language': language});
  }

  @override
  Future<void> updateNotificationsEnabled(String userId, bool enabled) async {
    await _upsert(userId, {'notifications_enabled': enabled});
  }

  @override
  Future<void> updateThemeMode(String userId, ThemeMode themeMode) async {
    await _upsert(userId, {'theme_mode': themeMode.name});
  }

  Future<SettingsModel> _upsert(
      String userId, Map<String, dynamic> changes) async {
    try {
      final row = await supabaseClient
          .from('settings')
          .upsert({
            'user_id': userId,
            if (changes.isNotEmpty)
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            ...changes,
          }, onConflict: 'user_id', defaultToNull: false)
          .select()
          .single();
      return SettingsModel.fromJson(row);
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not save settings: ${error.message}');
    }
  }
}
