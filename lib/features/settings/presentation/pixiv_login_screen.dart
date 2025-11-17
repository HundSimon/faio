import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  PixivLoginSession? _session;
  bool _isInitializing = true;
  bool _isPageLoading = false;
  bool _isExchanging = false;
  bool _handledAuthorization = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final params = const PlatformWebViewControllerCreationParams();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _controller = WebViewController.fromPlatformCreationParams(
        AndroidWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
          params,
        ),
      );
    } else {
      _controller = WebViewController.fromPlatformCreationParams(params);
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onWebResourceError: _handleWebError,
          onHttpError: _handleHttpError,
          onPageStarted: (_) => setState(() {
            _isPageLoading = true;
          }),
          onPageFinished: (_) => setState(() {
            _isPageLoading = false;
          }),
        ),
      );

    final platformController = _controller.platform;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (platformController is AndroidWebViewController) {
        platformController.setMediaPlaybackRequiresUserGesture(false);
        final platformCookieManager = _cookieManager.platform;
        if (platformCookieManager is AndroidWebViewCookieManager) {
          unawaited(
            platformCookieManager.setAcceptThirdPartyCookies(
              platformController,
              true,
            ),
          );
        }
      }
    }
    _startLogin();
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (_handledAuthorization) {
      return NavigationDecision.prevent;
    }
    final uri = Uri.tryParse(request.url);
    debugPrint('Pixiv WebView navigating to ${request.url}');
    if (uri != null && _isTrackingDomain(uri)) {
      debugPrint('Pixiv WebView encountered tracking domain ${uri.host}');
    }
    if (request.url.startsWith(PixivAuthFlow.redirectUri)) {
      final redirectUri = uri ?? Uri.parse(request.url);
      final code = redirectUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        setState(() {
          _errorMessage = '未能获取授权码，请重试。';
        });
        return NavigationDecision.prevent;
      }
      debugPrint(
        'Pixiv WebView intercepted callback (code length=${code.length})',
      );
      _handledAuthorization = true;
      _exchangeCode(code);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handleWebError(WebResourceError error) {
    String? failingUrl;
    if (error is AndroidWebResourceError) {
      failingUrl = error.failingUrl;
    }
    failingUrl ??= error.url;

    final parsedFailingUri = failingUrl != null
        ? Uri.tryParse(failingUrl)
        : null;
    if (parsedFailingUri != null && _isTrackingDomain(parsedFailingUri)) {
      debugPrint(
        'Ignoring tracking resource error (${error.errorCode}) for $failingUrl',
      );
      return;
    }

    debugPrint(
      'Pixiv login WebView error (${error.errorCode}): ${error.description} '
      'url=$failingUrl',
    );
    setState(() {
      final messageUrl = failingUrl ?? '';
      _errorMessage = messageUrl.isEmpty
          ? '加载失败：${error.description}'
          : '加载失败：${error.description}\n地址：$messageUrl';
    });
  }

  void _handleHttpError(HttpResponseError error) {
    final request = error.request;
    final response = error.response;
    final url = request?.uri.toString();
    final status = response?.statusCode ?? -1;
    if (status == 400) {
      debugPrint('Pixiv login HTTP 400 for url=$url');
    } else {
      debugPrint('Pixiv login HTTP error $status for url=$url');
    }
    setState(() {
      final messageUrl = url ?? '';
      _errorMessage = messageUrl.isEmpty
          ? '加载失败：HTTP $status'
          : '加载失败：HTTP $status\n地址：$messageUrl';
    });
  }

  bool _isTrackingDomain(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('googletagmanager.com') ||
        host.endsWith('google-analytics.com') ||
        host.endsWith('withgoogle.com');
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
      debugPrint(
        'Pixiv WebView session created (appVersion=${session.appVersion})',
      );
      await _controller.setUserAgent(session.userAgent);
      debugPrint('Pixiv WebView loading URL: ${session.loginUri}');
      await _controller.loadRequest(
        session.loginUri,
        headers: {
          'User-Agent': session.userAgent,
          'Referer': 'https://app-api.pixiv.net/',
          'X-Requested-With': 'com.pixiv.android',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN',
        },
      );
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
      debugPrint(
        'Pixiv WebView exchanging code length ${code.length} '
        'with verifier length ${session.codeVerifier.length}',
      );
      final flow = ref.read(pixivAuthFlowProvider);
      final credentials = await flow.exchange(code: code, session: session);
      if (!mounted) return;
      ref.read(pixivAuthProvider.notifier).setCredentials(credentials);
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Pixiv WebView exchange failed: $error');
      if (!mounted) return;
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
        ],
      ),
    );
  }
}
