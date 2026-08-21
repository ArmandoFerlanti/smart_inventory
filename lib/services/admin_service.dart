import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  Future<dynamic> _call(String action, Map<String, dynamic> payload) async {
    final response = await _supabase.functions.invoke(
      'admin-users',
      body: {'action': action, ...payload},
    );
    final data = response.data;
    debugPrint('admin-users [$action] -> $data');
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final data = await _call('list', {});
    final list = (data['users'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createUser(String email, String password, String role) async {
    await _call('create', {
      'email': email,
      'password': password,
      'role': role,
    });
  }

  Future<void> updateUser(String userId, String email, String role) async {
    await _call('update', {
      'userId': userId,
      'email': email,
      'role': role,
    });
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    await _call('reset_password', {
      'userId': userId,
      'password': newPassword,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _call('delete', {'userId': userId});
  }

  String formatError(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      String? message;
      if (details is Map) {
        // Il body JSON è già decodificato dal client
        message = details['error']?.toString() ??
            details['message']?.toString() ??
            details['msg']?.toString();
      } else if (details is String && details.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) {
            message = decoded['error']?.toString() ??
                decoded['message']?.toString() ??
                decoded['msg']?.toString();
          }
        } catch (_) {
          message = details;
        }
      }
      if (message != null && message.trim().isNotEmpty) return message;
      return 'Errore ${e.status}: ${e.reasonPhrase ?? 'chiamata fallita'}';
    }
    return e.toString();
  }
}
