import 'package:flutter/material.dart';

/// Placeholder screen for user library, downloads, and history.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('库'),
      ),
      body: const Center(
        child: Text('收藏、下载与阅读历史将在这里展示'),
      ),
    );
  }
}
