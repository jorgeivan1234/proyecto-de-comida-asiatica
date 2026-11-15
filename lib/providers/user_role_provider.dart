import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRoleProvider extends ChangeNotifier {
  UserRoleProvider() {
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      refresh();
    });
    refresh();
  }

  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSubscription;
  int _requestId = 0;
  String? _role;
  Object? _error;
  bool _isLoading = true;

  String? get role => _role;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> refresh() async {
    final requestId = ++_requestId;
    final user = _client.auth.currentUser;

    _role = null;
    _error = null;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'];
      if (role is! String || !{'client', 'admin'}.contains(role)) {
        throw const FormatException('El perfil no contiene un rol válido.');
      }

      if (requestId == _requestId) {
        _role = role;
      }
    } catch (error) {
      if (requestId == _requestId) {
        _error = error;
      }
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
