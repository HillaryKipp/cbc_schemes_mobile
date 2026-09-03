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

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('GuestStorageService must be initialized before use');
    }
    return _prefs!;
  }

  /// Get all guest schemes stored locally
  List<GuestScheme> getGuestSchemes() {
    try {
      final jsonStr = prefs.getString(AppConfig.guestSchemesKey);
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

  /// Save or replace a guest scheme
  Future<void> saveGuestScheme(GuestScheme scheme) async {
    try {
      final list = getGuestSchemes();
      final index = list.indexWhere((s) => s.id == scheme.id);
      if (index >= 0) {
        list[index] = scheme.copyWith(updatedAt: DateTime.now());
      } else {
        list.insert(0, scheme);
      }
      final jsonStr = jsonEncode(list.map((s) => s.toJson()).toList());
      await prefs.setString(AppConfig.guestSchemesKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving guest scheme: $e');
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
}
