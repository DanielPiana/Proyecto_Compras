import 'package:flutter/cupertino.dart';

class UserProvider with ChangeNotifier {
  String? _uuid;
  String? get uuid => _uuid;

  void setUuid(String? uuid) {
    _uuid = uuid;
    notifyListeners();
  }
}