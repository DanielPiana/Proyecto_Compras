import 'package:flutter/cupertino.dart';

/// Provider que gestiona el UUID del usuario actual en la aplicación
class UserProvider with ChangeNotifier {
  String? _uuid;
  String? get uuid => _uuid;

  /// Actualiza el UUID del usuario y notifica a los listeners
  void setUuid(String? uuid) {
    _uuid = uuid;
    notifyListeners();
  }
}