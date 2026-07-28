import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore._();

  static Future<SharedPreferences> instance() => SharedPreferences.getInstance();
}
