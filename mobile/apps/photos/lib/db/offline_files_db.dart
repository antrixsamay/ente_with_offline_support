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
    await db.insert(
      _tableName,
      {
        'id': file.id,
        'path': file.path,
        'thumbnail_path': file.thumbnailPath,
        'filename': file.filename,
        'size': file.size,
        'creation_time': file.creationTime,
      },
    );
  }

  Future<OfflineFile?> getFile(int id) async {
    final db = await asyncDB;
    final results = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) {
      return null;
    }
    return OfflineFile.fromMap(results.first);
  }

  Future<List<OfflineFile>> getAllFiles() async {
    final db = await asyncDB;
    final results = await db.query(_tableName);
    return results.map((map) => OfflineFile.fromMap(map)).toList();
  }

  Future<bool> isOffline(int id) async {
    final db = await asyncDB;
    final results = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty;
  }

  Future<void> delete(int id) async {
    final db = await asyncDB;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
