import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rhttp/rhttp.dart';

import 'core/preferences/content_safety_settings.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Rhttp.init();
  await ContentSafetySettingsNotifier.preload();
  runApp(const ProviderScope(child: FaioApp()));
}
