import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/guest_scheme.dart';

class GuestStorageService {
  static GuestStorageService? _instance;
  static GuestStorageService get instance => _instance ??= GuestStorageService._();

  GuestStorageService._();

  SharedPreferences? _prefs;
  static const int maxGuestSchemes = 20;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _migrateLegacySchemesIfAny();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('GuestStorageService must be initialized before use');
    }
    return _prefs!;
  }

  void _migrateLegacySchemesIfAny() {
    try {
      final current = prefs.getString(AppConfig.guestSchemesKey);
      if (current == null || current.isEmpty) {
        final legacy = prefs.getString(AppConfig.legacyGuestSchemesKey);
        if (legacy != null && legacy.isNotEmpty) {
          prefs.setString(AppConfig.guestSchemesKey, legacy);
          prefs.remove(AppConfig.legacyGuestSchemesKey);
          debugPrint('Migrated legacy schemes to cbc:guest-schemes');
        }
      }
    } catch (e) {
      debugPrint('Legacy scheme migration check failed: $e');
    }
  }

  /// Get all guest schemes stored locally (keeps up to 20 schemes)
  List<GuestScheme> getGuestSchemes() {
    try {
      var jsonStr = prefs.getString(AppConfig.guestSchemesKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = prefs.getString(AppConfig.legacyGuestSchemesKey);
      }
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => GuestScheme.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading guest schemes: $e');
      return [];
    }
  }

  /// Get a single guest scheme by ID
  GuestScheme? getGuestScheme(String id) {
    final list = getGuestSchemes();
    try {
      return list.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get all companion schemes belonging to a specific bundleId
  List<GuestScheme> getSchemesForBundle(String bundleId) {
    return getGuestSchemes().where((s) => s.bundleId == bundleId).toList();
  }

  /// Save or replace a guest scheme (capped at 20 schemes)
  Future<void> saveGuestScheme(GuestScheme scheme) async {
    try {
      final list = getGuestSchemes();
      final index = list.indexWhere((s) => s.id == scheme.id);
      if (index >= 0) {
        list[index] = scheme.copyWith(updatedAt: DateTime.now().toIso8601String());
      } else {
        list.insert(0, scheme);
      }
      // Keep up to 20 schemes
      final cappedList = list.take(maxGuestSchemes).toList();
      final jsonStr = jsonEncode(cappedList.map((s) => s.toJson()).toList());
      await prefs.setString(AppConfig.guestSchemesKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving guest scheme: $e');
    }
  }

  /// Mark guest scheme as paid locally
  Future<void> markSchemePaid(String id) async {
    final scheme = getGuestScheme(id);
    if (scheme != null) {
      await saveGuestScheme(scheme.copyWith(isPaid: true));
    }
  }

  /// Remove a guest scheme after claiming or deleting
  Future<void> removeGuestScheme(String id) async {
    try {
      final list = getGuestSchemes();
      list.removeWhere((s) => s.id == id);
      final jsonStr = jsonEncode(list.map((s) => s.toJson()).toList());
      await prefs.setString(AppConfig.guestSchemesKey, jsonStr);
    } catch (e) {
      debugPrint('Error removing guest scheme: $e');
    }
  }

  /// Save default teacher profile info for fast prefill
  Future<void> saveTeacherProfile({
    String? schoolName,
    String? teacherName,
    String? tscNumber,
    String? hodName,
  }) async {
    final data = {
      'school_name': schoolName ?? '',
      'teacher_name': teacherName ?? '',
      'tsc_number': tscNumber ?? '',
      'hod_name': hodName ?? '',
    };
    await prefs.setString(AppConfig.teacherProfileKey, jsonEncode(data));
  }

  /// Load cached teacher profile info
  Map<String, String> getTeacherProfile() {
    try {
      final jsonStr = prefs.getString(AppConfig.teacherProfileKey);
      if (jsonStr == null) return {};
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// Save user account info
  Future<void> saveUserAccount(Map<String, dynamic> accountData) async {
    await prefs.setString(AppConfig.userAccountKey, jsonEncode(accountData));
  }

  /// Load cached user account info
  Map<String, dynamic>? getUserAccount() {
    try {
      final jsonStr = prefs.getString(AppConfig.userAccountKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear user account on logout
  Future<void> clearUserAccount() async {
    await prefs.remove(AppConfig.userAccountKey);
  }
}
