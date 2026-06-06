// lib/core/database/database_provider.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_database.dart';

class DatabaseProvider {
  DatabaseProvider._();
  static final DatabaseProvider _instance = DatabaseProvider._();
  static DatabaseProvider get instance => _instance;

  late final AppDatabase db;

  /// Call this once in main() before runApp().
  /// Silently migrates DB from Documents\ to AppData\Roaming\ on first launch.
  Future<void> init() async {
    await _migrateIfNeeded();
    db = AppDatabase();
  }

  Future<void> _migrateIfNeeded() async {
    // Old location: Documents\pharmacy_app.sqlite
    final docsDir = await getApplicationDocumentsDirectory();
    final oldFile = File(p.join(docsDir.path, 'pharmacy_app.sqlite'));

    // New location: AppData\Roaming\pharmacy_app\pharmacy_app.sqlite
    final supportDir = await getApplicationSupportDirectory();
    final newFile = File(p.join(supportDir.path, 'pharmacy_app.sqlite'));

    // Only migrate if old file exists and new file doesn't yet
    if (oldFile.existsSync() && !newFile.existsSync()) {
      // Ensure target directory exists
      await newFile.parent.create(recursive: true);
      // Copy old → new (keep old as backup)
      await oldFile.copy(newFile.path);
    }
  }
}