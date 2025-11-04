import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/e621/e621_auth.dart';
import '../../../data/pixiv/pixiv_auth.dart';
import '../../../data/pixiv/pixiv_providers.dart';
import 'pixiv_login_screen.dart';

/// Settings hub with placeholders for upcoming configuration panels.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(e621AuthProvider);
    final pixivCredentials = ref.watch(pixivAuthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
          Card(
            child: ListTile(
              title: const Text('Pixiv 凭证'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pixivCredentials == null
                        ? '未配置，将使用示例内容'
                        : '刷新令牌已配置，访问令牌到期：${_formatExpiry(pixivCredentials.expiresAt)}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _startPixivLogin(context, ref),
                        child: const Text('登录获取'),
                      ),
                      TextButton(
                        onPressed: () => _editPixivCredentialsManual(
                          context,
                          ref,
                        ),
                        child: const Text('手动录入'),
                      ),
                    ],
                  ),
                ],
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

  String _formatExpiry(DateTime expiresAt) {
    final local = expiresAt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editE621Credentials(BuildContext context, WidgetRef ref) async {
    final credentials = ref.read(e621AuthProvider);
    final usernameController = TextEditingController(
      text: credentials?.username ?? '',
    );
    final apiKeyController = TextEditingController(
      text: credentials?.apiKey ?? '',
    );

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
                decoration: const InputDecoration(labelText: '用户名'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.clear),
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.cancel),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.save),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      usernameController.dispose();
      apiKeyController.dispose();
      return;
    }

    switch (result) {
      case _CredentialDialogResult.save:
        ref
            .read(e621AuthProvider.notifier)
            .update(
              username: usernameController.text,
              apiKey: apiKeyController.text,
            );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存 e621 凭证')));
        break;
      case _CredentialDialogResult.clear:
        ref.read(e621AuthProvider.notifier).clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清除 e621 凭证')));
        break;
      case _CredentialDialogResult.cancel:
        break;
      case null:
        break;
    }

    usernameController.dispose();
    apiKeyController.dispose();
  }

  Future<void> _startPixivLogin(BuildContext context, WidgetRef ref) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PixivLoginScreen(),
        fullscreenDialog: true,
      ),
    );
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已完成 Pixiv 登录')),
      );
    }
  }

  Future<void> _editPixivCredentialsManual(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final credentials = ref.read(pixivAuthProvider);
    final refreshTokenController = TextEditingController(
      text: credentials?.refreshToken ?? '',
    );

    final result = await showDialog<_CredentialDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('配置 Pixiv 凭证'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refreshTokenController,
                decoration: const InputDecoration(
                  labelText: 'Refresh Token',
                  helperText: '从 Pixiv 登录流程中获取的刷新令牌',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.clear),
              child: const Text('清除'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.cancel),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CredentialDialogResult.save),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      refreshTokenController.dispose();
      return;
    }

    switch (result) {
      case _CredentialDialogResult.save:
        final refreshToken = refreshTokenController.text.trim();
        if (refreshToken.isEmpty) {
          if (!context.mounted) break;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请输入有效的 Refresh Token')));
          break;
        }
        final messenger = ScaffoldMessenger.maybeOf(context);
        final oauthClient = ref.read(pixivOAuthClientProvider);
        try {
          final refreshed = await oauthClient.refreshToken(refreshToken);
          ref.read(pixivAuthProvider.notifier).setCredentials(refreshed);
          if (!context.mounted) break;
          messenger?.showSnackBar(
            const SnackBar(content: Text('已刷新 Pixiv 凭证')),
          );
        } catch (error) {
          if (!context.mounted) break;
          messenger?.showSnackBar(SnackBar(content: Text('刷新失败：$error')));
        }
        break;
      case _CredentialDialogResult.clear:
        ref.read(pixivAuthProvider.notifier).clear();
        if (!context.mounted) break;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('已清除 Pixiv 凭证')));
        break;
      case _CredentialDialogResult.cancel:
      case null:
        break;
    }

    refreshTokenController.dispose();
  }
}

enum _CredentialDialogResult { save, cancel, clear }
