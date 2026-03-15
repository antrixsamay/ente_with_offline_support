import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:photos/db/common/base.dart';
import 'package:photos/models/file/file.dart';
import 'package:sqlite_async/sqlite_async.dart';

class OfflineFile {
  final int id;
  final String path;
  final String thumbnailPath;
  final String filename;
  final int size;
  final int creationTime;

  OfflineFile({
    required this.id,
    required this.path,
    required this.thumbnailPath,
    required this.filename,
    required this.size,
    required this.creationTime,
  });

  factory OfflineFile.fromMap(Map<String, dynamic> map) {
    return OfflineFile(
      id: map['id'] as int,
      path: map['path'] as String,
      thumbnailPath: map['thumbnail_path'] as String,
      filename: map['filename'] as String,
      size: map['size'] as int,
      creationTime: map['creation_time'] as int,
    );
  }
}

class OfflineFilesDB with SqlDbBase {
  static final Logger _logger = Logger("OfflineFilesDB");

  static const _databaseName = "ente_offline_files.db";
  static const _tableName = "offline_files";
  static const _localIdTableName = "local_ids";

  OfflineFilesDB._privateConstructor();

  static final OfflineFilesDB instance = OfflineFilesDB._privateConstructor();

  static const List<String> _migrationScripts = [
    '''
    CREATE TABLE IF NOT EXISTS $_tableName (
      id INTEGER PRIMARY KEY,
      path TEXT NOT NULL,
      thumbnail_path TEXT NOT NULL,
      filename TEXT NOT NULL,
      size INTEGER NOT NULL,
      creation_time INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $_localIdTableName (
      local_int_id INTEGER PRIMARY KEY AUTOINCREMENT,
      local_string_id TEXT NOT NULL UNIQUE
    )
    ''',
  ];

  Future<SqliteDatabase>? _sqliteAsyncDBFuture;

  Future<SqliteDatabase> get asyncDB async {
    _sqliteAsyncDBFuture ??= _initSqliteAsyncDatabase();
    return _sqliteAsyncDBFuture!;
  }

  Future<SqliteDatabase> _initSqliteAsyncDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final String databaseDirectory =
        join(documentsDirectory.path, _databaseName);
    _logger.info("Opening offline files DB at $databaseDirectory");
    final asyncDBConnection =
        SqliteDatabase(path: databaseDirectory, maxReaders: 2);
    await migrate(asyncDBConnection, _migrationScripts);
    return asyncDBConnection;
  }

  Future<void> insert(OfflineFile file) async {
    final db = await asyncDB;
    await db.execute(
      'INSERT INTO $_tableName (id, path, thumbnail_path, filename, size, creation_time) VALUES (?, ?, ?, ?, ?, ?)',
      [
        file.id,
        file.path,
        file.thumbnailPath,
        file.filename,
        file.size,
        file.creationTime
      ],
    );
  }

  Future<OfflineFile?> getFile(int id) async {
    final db = await asyncDB;
    final results = await db.getAll(
      'SELECT * FROM $_tableName WHERE id = ?',
      [id],
    );
    if (results.isEmpty) {
      return null;
    }
    return OfflineFile.fromMap(results.first);
  }

  Future<List<OfflineFile>> getAllFiles() async {
    final db = await asyncDB;
    final results = await db.getAll('SELECT * FROM $_tableName');
    return results.map((map) => OfflineFile.fromMap(map)).toList();
  }

  Future<bool> isOffline(int id) async {
    final db = await asyncDB;
    final results = await db.getAll(
      'SELECT id FROM $_tableName WHERE id = ?',
      [id],
    );
    return results.isNotEmpty;
  }

  Future<void> delete(int id) async {
    final db = await asyncDB;
    await db.execute('DELETE FROM $_tableName WHERE id = ?', [id]);
  }

  Future<Map<String, int>> getLocalIntIdsForLocalIds(
      List<String> localIds) async {
    final db = await asyncDB;
    if (localIds.isEmpty) {
      return {};
    }
    final results = await db.getAll(
        'SELECT local_string_id, local_int_id FROM $_localIdTableName WHERE local_string_id IN (${localIds.map((_) => '?').join(',')})',
        localIds);
    return {
      for (var row in results) row['local_string_id']: row['local_int_id']
    };
  }

  Future<Map<int, String>> getLocalIdsForIntIds(List<int> localIntIds) async {
    final db = await asyncDB;
    if (localIntIds.isEmpty) {
      return {};
    }
    final results = await db.getAll(
        'SELECT local_int_id, local_string_id FROM $_localIdTableName WHERE local_int_id IN (${localIntIds.map((_) => '?').join(',')})',
        localIntIds);
    return {
      for (var row in results) row['local_int_id']: row['local_string_id']
    };
  }

  Future<Map<String, int>> ensureLocalIntIds(List<String> localIds) async {
    if (localIds.isEmpty) {
      return {};
    }
    final existing = await getLocalIntIdsForLocalIds(localIds);
    final missing =
        localIds.where((element) => !existing.containsKey(element)).toList();
    if (missing.isEmpty) {
      return existing;
    }
    final db = await asyncDB;
    await db.writeTransaction((tx) async {
      for (final id in missing) {
        await tx.execute(
            'INSERT INTO $_localIdTableName (local_string_id) VALUES (?)',
            [id]);
      }
    });

    return getLocalIntIdsForLocalIds(localIds);
  }

  Future<int?> getOrCreateLocalIntId(String localId) async {
    final res = await ensureLocalIntIds([localId]);
    return res[localId];
  }

  Future<String?> getLocalIdForIntId(int localIntId) async {
    final res = await getLocalIdsForIntIds([localIntId]);
    return res[localIntId];
  }
}
