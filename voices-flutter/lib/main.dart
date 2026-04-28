import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/model_download_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 恢复用户配置的外部模型搜索路径。
  await ModelDownloadManager().loadExternalModelSearchPaths();

  runApp(
    const ProviderScope(
      child: VoicesApp(),
    ),
  );
}

class VoicesApp extends StatelessWidget {
  const VoicesApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    const seed = Color(0xFF0B7285);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      textTheme: const TextTheme().apply(
        fontFamilyFallback: const [
          'PingFang SC',
          'Noto Sans CJK SC',
          'SF Pro Text',
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '语音转写',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
