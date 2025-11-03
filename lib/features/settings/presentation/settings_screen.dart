import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/e621/e621_auth.dart';

/// Settings hub with placeholders for upcoming configuration panels.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(e621AuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('e621 凭证'),
              subtitle: Text(
                credentials == null
                    ? '未配置，使用匿名访问'
                    : '已配置：${credentials.username}',
              ),
              trailing: TextButton(
                onPressed: () => _editE621Credentials(context, ref),
                child: const Text('配置'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              title: Text('网络策略'),
              subtitle: Text('DoH/代理、SNI 防护等功能即将上线'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editE621Credentials(BuildContext context, WidgetRef ref) async {
    final credentials = ref.read(e621AuthProvider);
    final usernameController = TextEditingController(text: credentials?.username ?? '');
    final apiKeyController = TextEditingController(text: credentials?.apiKey ?? '');

    final result = await showDialog<_CredentialDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('配置 e621 凭证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_CredentialDialogResult.clear),
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_CredentialDialogResult.cancel),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_CredentialDialogResult.save),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    switch (result) {
      case _CredentialDialogResult.save:
        ref.read(e621AuthProvider.notifier).update(
              username: usernameController.text,
              apiKey: apiKeyController.text,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存 e621 凭证')),
        );
        break;
      case _CredentialDialogResult.clear:
        ref.read(e621AuthProvider.notifier).clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除 e621 凭证')),
        );
        break;
      case _CredentialDialogResult.cancel:
        break;
      case null:
        break;
    }

    usernameController.dispose();
    apiKeyController.dispose();
  }
}

enum _CredentialDialogResult { save, cancel, clear }
