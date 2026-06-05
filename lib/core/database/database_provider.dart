// lib/core/database/database_provider.dart

import 'app_database.dart';

class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider _instance = DatabaseProvider._();
  static DatabaseProvider get instance => _instance;
  late final AppDatabase db = AppDatabase();
}
