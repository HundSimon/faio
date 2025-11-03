import 'package:flutter/material.dart';

/// Placeholder for global settings such as network preferences and notifications.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: const Center(
        child: Text('内容过滤、账号、网络策略等设置将集中于此'),
      ),
    );
  }
}
