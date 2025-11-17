import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/e621/e621_auth.dart';
import '../../../data/pixiv/pixiv_auth.dart';
import '../../../data/pixiv/pixiv_providers.dart';
import '../../../core/theme/theme_mode_provider.dart';
import 'licenses_screen.dart';
import 'pixiv_login_screen.dart';
import 'tag_management_screen.dart';

/// Settings hub with placeholders for upcoming configuration panels.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentials = ref.watch(e621AuthProvider);
    final pixivCredentials = ref.watch(pixivAuthProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '界面主题',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择浅色、深色或跟随系统外观。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('跟随系统'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('浅色'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('深色'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selection.first);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                        onPressed: () =>
                            _editPixivCredentialsManual(context, ref),
                        child: const Text('手动录入'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('标签管理'),
              subtitle: const Text('配置喜欢或屏蔽的标签，过滤信息流内容'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TagManagementScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              title: Text('网络策略'),
              subtitle: Text('DoH/代理、SNI 防护等功能即将上线'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('开源许可与鸣谢'),
              subtitle: const Text('查看 GPL 3.0 说明以及 Credits'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicensesScreen()),
                );
              },
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
    final result = await showDialog<_E621CredentialDialogResult>(
      context: context,
      builder: (_) => _E621CredentialDialog(
        initialUsername: credentials?.username ?? '',
        initialApiKey: credentials?.apiKey ?? '',
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    switch (result.action) {
      case _CredentialDialogAction.save:
        ref
            .read(e621AuthProvider.notifier)
            .update(username: result.username, apiKey: result.apiKey);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存 e621 凭证')));
        break;
      case _CredentialDialogAction.clear:
        ref.read(e621AuthProvider.notifier).clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清除 e621 凭证')));
        break;
      case _CredentialDialogAction.cancel:
        break;
    }
  }

  Future<void> _startPixivLogin(BuildContext context, WidgetRef ref) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PixivLoginScreen(),
        fullscreenDialog: true,
      ),
    );
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已完成 Pixiv 登录')));
    }
  }

  Future<void> _editPixivCredentialsManual(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final credentials = ref.read(pixivAuthProvider);
    final result = await showDialog<_PixivCredentialDialogResult>(
      context: context,
      builder: (_) => _PixivCredentialDialog(
        initialRefreshToken: credentials?.refreshToken ?? '',
      ),
    );

    if (!context.mounted || result == null) {
      return;
    }

    switch (result.action) {
      case _CredentialDialogAction.save:
        final refreshToken = result.refreshToken.trim();
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
      case _CredentialDialogAction.clear:
        ref.read(pixivAuthProvider.notifier).clear();
        if (!context.mounted) break;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('已清除 Pixiv 凭证')));
        break;
      case _CredentialDialogAction.cancel:
        break;
    }
  }
}

class _E621CredentialDialog extends StatefulWidget {
  const _E621CredentialDialog({
    required this.initialUsername,
    required this.initialApiKey,
  });

  final String initialUsername;
  final String initialApiKey;

  @override
  State<_E621CredentialDialog> createState() => _E621CredentialDialogState();
}

class _E621CredentialDialogState extends State<_E621CredentialDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _apiKeyController = TextEditingController(text: widget.initialApiKey);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _handleSave() {
    Navigator.of(context).pop(
      _E621CredentialDialogResult(
        action: _CredentialDialogAction.save,
        username: _usernameController.text,
        apiKey: _apiKeyController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配置 e621 凭证'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: '用户名'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'API Key'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _E621CredentialDialogResult(
              action: _CredentialDialogAction.clear,
            ),
          ),
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _E621CredentialDialogResult(
              action: _CredentialDialogAction.cancel,
            ),
          ),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _handleSave, child: const Text('保存')),
      ],
    );
  }
}

class _E621CredentialDialogResult {
  const _E621CredentialDialogResult({
    required this.action,
    this.username = '',
    this.apiKey = '',
  });

  final _CredentialDialogAction action;
  final String username;
  final String apiKey;
}

class _PixivCredentialDialog extends StatefulWidget {
  const _PixivCredentialDialog({required this.initialRefreshToken});

  final String initialRefreshToken;

  @override
  State<_PixivCredentialDialog> createState() => _PixivCredentialDialogState();
}

class _PixivCredentialDialogState extends State<_PixivCredentialDialog> {
  late final TextEditingController _refreshTokenController;

  @override
  void initState() {
    super.initState();
    _refreshTokenController = TextEditingController(
      text: widget.initialRefreshToken,
    );
  }

  @override
  void dispose() {
    _refreshTokenController.dispose();
    super.dispose();
  }

  void _handleSave() {
    Navigator.of(context).pop(
      _PixivCredentialDialogResult(
        action: _CredentialDialogAction.save,
        refreshToken: _refreshTokenController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('配置 Pixiv 凭证'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _refreshTokenController,
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
          onPressed: () => Navigator.of(context).pop(
            const _PixivCredentialDialogResult(
              action: _CredentialDialogAction.clear,
            ),
          ),
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _PixivCredentialDialogResult(
              action: _CredentialDialogAction.cancel,
            ),
          ),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _handleSave, child: const Text('保存')),
      ],
    );
  }
}

class _PixivCredentialDialogResult {
  const _PixivCredentialDialogResult({
    required this.action,
    this.refreshToken = '',
  });

  final _CredentialDialogAction action;
  final String refreshToken;
}

enum _CredentialDialogAction { save, cancel, clear }
