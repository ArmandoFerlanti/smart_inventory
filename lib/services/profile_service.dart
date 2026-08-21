import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _supabase = Supabase.instance.client;

  String? _cachedRole;

  Future<String> getCurrentUserRole() async {
    if (_cachedRole != null) return _cachedRole!;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('ProfileService: nessun utente loggato');
      return 'membro';
    }

    debugPrint('ProfileService: cerco profilo per user ${user.id}');

    final result = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    debugPrint('ProfileService: risultato query = $result');

    _cachedRole = result?['role'] as String? ?? 'membro';
    debugPrint('ProfileService: ruolo = $_cachedRole');
    return _cachedRole!;
  }

  bool isAdmin() => _cachedRole == 'admin';
  bool isPresidente() => _cachedRole == 'presidente';

  void clearCache() {
    _cachedRole = null;
  }
}
