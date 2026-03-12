// DIAGNOSTIC SCRIPT - Run this to check SharedPreferences
// lib/utils/debug_sharedprefs.dart

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsDebugger {
  static Future<void> printAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    print('════════════════════════════════════════');
    print('📦 ALL SharedPreferences Keys & Values:');
    print('════════════════════════════════════════');
    
    final keys = prefs.getKeys();
    if (keys.isEmpty) {
      print('⚠️ NO KEYS FOUND - SharedPreferences is EMPTY!');
    } else {
      for (final key in keys) {
        final value = prefs.get(key);
        print('  $key: "$value"');
      }
    }
    
    print('════════════════════════════════════════');
    print('🔍 Looking for critical keys:');
    print('════════════════════════════════════════');
    
    // Check for elderly user ID
    final elderlyKeys = [
      'elderly_user_uid',
      'elderly_user_id', 
      'elderly_user_name',
      'elderlyUserId',
    ];
    
    bool foundElderlyId = false;
    for (final key in elderlyKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        print('  ✅ $key: "$value"');
        foundElderlyId = true;
      } else {
        print('  ❌ $key: NOT FOUND');
      }
    }
    
    if (!foundElderlyId) {
      print('  ⚠️ NO ELDERLY USER ID FOUND!');
    }
    
    // Check for caretaker ID
    final caretakerKeys = [
      'caretaker_id',
      'caretaker_user_id',
      'caretakerId',
    ];
    
    bool foundCaretakerId = false;
    for (final key in caretakerKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        print('  ✅ $key: "$value"');
        foundCaretakerId = true;
      } else {
        print('  ❌ $key: NOT FOUND');
      }
    }
    
    if (!foundCaretakerId) {
      print('  ⚠️ NO CARETAKER ID FOUND!');
    }
    
    print('════════════════════════════════════════\n');
  }
  
  /// Set caretaker ID if missing
  static Future<void> setCaretakerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caretaker_id', id);
    await prefs.setString('caretaker_user_id', id);
    print('✅ Set caretaker_id to: $id');
  }
  
  /// Set elderly user ID if missing
  static Future<void> setElderlyUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('elderly_user_uid', id);
    await prefs.setString('elderly_user_id', id);
    await prefs.setString('elderlyUserId', id);
    print('✅ Set elderly_user_id to: $id');
  }
}

// HOW TO USE:
// 1. Import in your screen:
//    import 'package:elderly_care_app/utils/debug_sharedprefs.dart';
//
// 2. Call in initState or a button:
//    await SharedPrefsDebugger.printAllKeys();
//
// 3. If IDs are missing, set them:
//    await SharedPrefsDebugger.setCaretakerId('your_caretaker_id');
//    await SharedPrefsDebugger.setElderlyUserId('gg');