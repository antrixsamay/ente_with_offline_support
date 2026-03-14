import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photos/db/offline_files_db.dart';
import 'package:photos/services/offline_service.dart';

class OfflineTab extends StatefulWidget {
  const OfflineTab({super.key});

  @override
  State<OfflineTab> createState() => _OfflineTabState();
}

class _OfflineTabState extends State<OfflineTab> {
  late Future<List<OfflineFile>> _offlineFilesFuture;

  @override
  void initState() {
    super.initState();
    _loadOfflineFiles();
  }

  void _loadOfflineFiles() {
    setState(() {
      _offlineFilesFuture = OfflineFilesDB.instance.getAllFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OfflineFile>>(
      future: _offlineFilesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final offlineFiles = snapshot.data ?? [];
        if (offlineFiles.isEmpty) {
          return const Center(child: Text('No offline files.'));
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: offlineFiles.length,
          itemBuilder: (context, index) {
            final offlineFile = offlineFiles[index];
            return GestureDetector(
              onLongPress: () => _showDeleteConfirmation(offlineFile),
              child: GridTile(
                footer: GridTileBar(
                  backgroundColor: Colors.black45,
                  title: Text(
                    offlineFile.filename,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                child: Image.file(
                  File(offlineFile.thumbnailPath),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(OfflineFile offlineFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from offline?'),
        content: const Text(
            'This will remove the file from your offline storage, but it will still be available in your Ente account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await OfflineService.instance.unmarkAsOffline(offlineFile.id);
      _loadOfflineFiles();
    }
  }
}
