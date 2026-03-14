import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photos/db/offline_files_db.dart';
import 'package:photos/models/file/file.dart';
import 'package:photos/utils/file_download_util.dart';
import 'package:photos/utils/thumbnail_util.dart';

class OfflineService {
  late Logger _logger;
  late OfflineFilesDB _offlineFilesDB;

  OfflineService._privateConstructor() {
    _logger = Logger("OfflineService");
    _offlineFilesDB = OfflineFilesDB.instance;
  }

  static final OfflineService instance = OfflineService._privateConstructor();

  Future<void> markAsOffline(EnteFile file) async {
    _logger.info("Marking file as offline: ${file.tag}");

    try {
      final decryptedFile = await downloadAndDecrypt(file);
      if (decryptedFile == null) {
        _logger.warning("Failed to download and decrypt file: ${file.tag}");
        return;
      }

      final offlineDir = await _getOfflineDirectory();
      final offlinePath = "${offlineDir.path}/${file.uploadedFileID}";

      await decryptedFile.rename(offlinePath);
      _logger.info("File moved to offline storage: $offlinePath");

      await getThumbnailFromServer(file);
      final cachedThumbnail = cachedThumbnailPath(file);
      final offlineThumbnailsDir = await _getOfflineThumbnailsDirectory();
      final offlineThumbnailPath =
          "${offlineThumbnailsDir.path}/${file.uploadedFileID}";
      await cachedThumbnail.copy(offlineThumbnailPath);
      _logger.info("Thumbnail moved to offline storage: $offlineThumbnailPath");

      final offlineFile = OfflineFile(
        id: file.uploadedFileID!,
        path: offlinePath,
        thumbnailPath: offlineThumbnailPath,
        filename: file.title ?? '',
        size: file.fileSize ?? 0,
        creationTime: file.creationTime,
      );
      await _offlineFilesDB.insert(offlineFile);
      _logger.info("Offline file metadata stored in DB");
    } catch (e, s) {
      _logger.severe("Failed to mark file as offline: ${file.tag}", e, s);
    }
  }

  Future<void> unmarkAsOffline(int id) async {
    _logger.info("Unmarking file as offline: $id");
    try {
      final offlineFile = await _offlineFilesDB.getFile(id);
      if (offlineFile == null) {
        _logger.warning("Offline file not found in DB: $id");
        return;
      }

      final file = File(offlineFile.path);
      if (await file.exists()) {
        await file.delete();
      }

      final thumbnail = File(offlineFile.thumbnailPath);
      if (await thumbnail.exists()) {
        await thumbnail.delete();
      }

      await _offlineFilesDB.delete(id);
      _logger.info("Offline file removed: $id");
    } catch (e, s) {
      _logger.severe("Failed to unmark file as offline: $id", e, s);
    }
  }

  Future<Directory> _getOfflineDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final offlineDir = Directory("${supportDir.path}/offline_files");
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  Future<Directory> _getOfflineThumbnailsDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final offlineDir = Directory("${supportDir.path}/offline_thumbnails");
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }
}
