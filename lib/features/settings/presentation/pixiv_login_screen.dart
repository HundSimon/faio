import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/pixiv/pixiv_auth.dart';
import '../../../data/pixiv/pixiv_auth_flow.dart';
import '../../../data/pixiv/pixiv_providers.dart';

class PixivLoginScreen extends ConsumerStatefulWidget {
  const PixivLoginScreen({super.key});

  @override
  ConsumerState<PixivLoginScreen> createState() => _PixivLoginScreenState();
}

class _PixivLoginScreenState extends ConsumerState<PixivLoginScreen> {
  late final WebViewController _controller;
  PixivLoginSession? _session;
  bool _isInitializing = true;
  bool _isPageLoading = false;
  bool _isExchanging = false;
  bool _handledAuthorization = false;
  String? _errorMessage;
  final TextEditingController _manualCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: _handleWebError,
          onPageStarted: (_) => setState(() {
            _isPageLoading = true;
          }),
          onPageFinished: (_) => setState(() {
            _isPageLoading = false;
          }),
        ),
      );
    _startLogin();
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (_handledAuthorization) {
      return NavigationDecision.prevent;
    }
    if (request.url.startsWith(PixivAuthFlow.redirectUri)) {
      final uri = Uri.parse(request.url);
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        setState(() {
          _errorMessage = '未能获取授权码，请重试。';
        });
        return NavigationDecision.prevent;
      }
      _handledAuthorization = true;
      _exchangeCode(code);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handleWebError(WebResourceError error) {
    setState(() {
      _errorMessage = '加载失败：${error.description}';
    });
  }

  Future<void> _startLogin() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    try {
      final flow = ref.read(pixivAuthFlowProvider);
      final session = await flow.createSession();
      if (!mounted) return;
      _session = session;
      await _controller.loadRequest(session.loginUri);
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = '无法启动 Pixiv 登录：$error';
      });
    }
  }

  Future<void> _exchangeCode(String code) async {
    final session = _session;
    if (session == null) {
      setState(() {
        _errorMessage = '登录会话失效，请重试。';
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
      if (!mounted) return;
      ref.read(pixivAuthProvider.notifier).setCredentials(credentials);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isExchanging = false;
        _handledAuthorization = false;
        _errorMessage = '授权失败：$error';
      });
    }
  }

  Future<void> _openInBrowser() async {
    final session = _session;
    if (session == null) {
      setState(() {
        _errorMessage = '尚未初始化登录会话，请重试。';
      });
      return;
    }

    final uri = session.loginUri;
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );
    } catch (error) {
      setState(() {
        _errorMessage = '无法打开外部浏览器：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _startLogin, child: const Text('重试')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openInBrowser,
                child: const Text('外部浏览器打开'),
              ),
            ],
          ),
        ),
      );
    } else if (_isInitializing) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = WebViewWidget(controller: _controller);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pixiv 登录')),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (_isPageLoading && !_isInitializing && _errorMessage == null)
            const LinearProgressIndicator(minHeight: 2),
          if (_isExchanging)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.95),
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '若浏览器无法打开，可在外部浏览器登录并将回调链接中的 code 参数粘贴到此：',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCodeController,
                          decoration: const InputDecoration(
                            labelText: '授权码 code',
                            hintText: '如：UR0bHuD...（可粘贴整条回调链接）',
                          ),
                          minLines: 1,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: _isExchanging
                            ? null
                            : () {
                                final text = _manualCodeController.text.trim();
                                if (text.isEmpty) {
                                  setState(() {
                                    _errorMessage = '请输入授权码。';
                                  });
                                  return;
                                }
                                final uri = Uri.tryParse(text);
                                final code =
                                    uri?.queryParameters['code'] ?? text;
                                _handledAuthorization = true;
                                _exchangeCode(code);
                              },
                        child: const Text('提交'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _openInBrowser,
                      child: const Text('外部浏览器登录'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
