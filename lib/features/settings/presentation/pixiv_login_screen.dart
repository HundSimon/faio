import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/pixiv/pixiv_auth.dart';
import '../../../data/pixiv/pixiv_auth_flow.dart';
import '../../../data/pixiv/pixiv_providers.dart';

class PixivLoginScreen extends ConsumerStatefulWidget {
  const PixivLoginScreen({super.key});

  @override
  ConsumerState<PixivLoginScreen> createState() => _PixivLoginScreenState();
}

class _PixivLoginScreenState extends ConsumerState<PixivLoginScreen> {
  PixivLoginSession? _session;
  StreamSubscription<Uri?>? _linkSubscription;
  bool _isInitializing = true;
  bool _isLaunching = false;
  bool _isExchanging = false;
  bool _handledAuthorization = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenForLinks();
    _startLogin();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _listenForLinks() {
    _linkSubscription = uriLinkStream.listen(
      (Uri? uri) {
        if (!mounted || uri == null) {
          return;
        }
        _handleIncomingUri(uri);
      },
      onError: (Object error) {
        debugPrint('Pixiv login link stream error: $error');
      },
    );

    // Handle the scenario where the app was launched by the callback link.
    Future<void>(() async {
      try {
        final initialUri = await getInitialUri();
        if (!mounted || initialUri == null) {
          return;
        }
        _handleIncomingUri(initialUri);
      } catch (error) {
        debugPrint('Pixiv login initial link error: $error');
      }
    });
  }

  Future<void> _startLogin() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _handledAuthorization = false;
    });

    try {
      final flow = ref.read(pixivAuthFlowProvider);
      final session = await flow.createSession();
      if (!mounted) {
        return;
      }
      _session = session;
      setState(() {
        _isInitializing = false;
      });
      if (_handledAuthorization) {
        return;
      }
      await _launchLogin(session.loginUri);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = '无法启动 Pixiv 登录：$error';
      });
    }
  }

  Future<void> _launchLogin(Uri uri) async {
    setState(() {
      _isLaunching = true;
      _errorMessage = null;
    });

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        setState(() {
          _errorMessage = '无法打开浏览器，请尝试手动复制链接。';
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = '无法打开浏览器：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  void _handleIncomingUri(Uri uri) {
    if (_handledAuthorization) {
      return;
    }

    if (!_isPixivCallback(uri)) {
      return;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      setState(() {
        _errorMessage = '授权回调缺少 code，请重试。';
      });
      return;
    }

    _handledAuthorization = true;
    _exchangeCode(code);
  }

  bool _isPixivCallback(Uri uri) {
    return uri.scheme == 'https' &&
        uri.host == 'app-api.pixiv.net' &&
        uri.path == '/web/v1/users/auth/pixiv/callback';
  }

  Future<void> _exchangeCode(String code) async {
    final session = _session;
    if (session == null) {
      setState(() {
        _errorMessage = '登录会话失效，请重新发起登录。';
        _handledAuthorization = false;
      });
      return;
    }

    setState(() {
      _isExchanging = true;
      _errorMessage = null;
    });

    try {
      final flow = ref.read(pixivAuthFlowProvider);
      final credentials = await flow.exchange(code: code, session: session);
      if (!mounted) {
        return;
      }
      ref.read(pixivAuthProvider.notifier).setCredentials(credentials);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExchanging = false;
        _handledAuthorization = false;
        _errorMessage = '授权失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Pixiv 登录')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '将在系统浏览器中打开 Pixiv 登录。请完成登录并授权后，系统会提示回到本应用。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isInitializing)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton.icon(
                  onPressed:
                      session == null || _isLaunching ? null : () => _launchLogin(session.loginUri),
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(_isLaunching ? '正在打开浏览器…' : '在浏览器中打开登录页'),
                ),
                const SizedBox(height: 12),
                if (session != null) ...[
                  Text(
                    '如果浏览器未自动打开，可复制以下链接手动访问：',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    session.loginUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                '注意事项：\n'
                '1. 如果出现安全验证，请完成验证后继续。\n'
                '2. 如未返回应用，请在浏览器完成授权后手动切换回本应用。\n'
                '3. 若仍无法完成登录，可在登录页重新发起流程。',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _isInitializing || _isLaunching ? null : _startLogin,
                child: const Text('重新发起登录流程'),
              ),
            ],
          ),
          if (_isExchanging)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
