import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays licensing information and credits for upstream projects.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  static const _pixezUrl = 'https://github.com/Notsfsssf/pixez-flutter';
  static const _gplUrl = 'https://www.gnu.org/licenses/gpl-3.0.txt';
  static const _furryNovelUrl = 'https://furrynovel.ink';
  static const _pixivSourceUrl = 'https://github.com/DowneyRem/PixivSource';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('开源许可与鸣谢')),
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
                    'GNU GPL 3.0',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'faio 以 GNU General Public License v3.0 授权发布，'
                    '分发应用或衍生作品时需保留本许可证文本，并在相同协议下共享。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _launchExternalLink(context, _gplUrl),
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('查看完整协议'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '致谢 Pixez',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pixez (GPL 3.0) 提供了 Pixiv 体验设计以及代码实现思路的灵感来源，'
                    'faio 在实现 Pixiv 浏览体验时参考了该项目。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            _launchExternalLink(context, _pixezUrl),
                        icon: const Icon(Icons.link_outlined),
                        label: const Text('访问 Pixez 仓库'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _launchExternalLink(context, _gplUrl),
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('了解 Pixez 许可'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '社区支持',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '感谢 furrynovel.ink 提供 Pixiv 小说代理能力，'
                    '同时感谢 PixivSource 项目对 Pixiv 及 FurryNovel API 的整理与开源。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            _launchExternalLink(context, _furryNovelUrl),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('访问 FurryNovel'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _launchExternalLink(context, _pixivSourceUrl),
                        icon: const Icon(Icons.code_outlined),
                        label: const Text('PixivSource 仓库'),
                      ),
                    ],
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

Future<void> _launchExternalLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!success) {
    messenger?.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
  }
}
