import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'providers/library_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/player_provider.dart';
import 'views/home/home_view.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize MediaKit video playback engine
  MediaKit.ensureInitialized();

  // 2. Initialize Windows 11 Window Manager (Size, Title, Minimum dimensions)
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'CinemaStream - Local Media Hub',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  String? initialFilePath;
  if (args.isNotEmpty) {
    final candidate = args.first.replaceAll('"', '').trim();
    if (candidate.isNotEmpty && File(candidate).existsSync()) {
      initialFilePath = candidate;
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: CinemaStreamApp(initialFilePath: initialFilePath),
    ),
  );
}

class CinemaStreamApp extends StatelessWidget {
  final String? initialFilePath;
  const CinemaStreamApp({super.key, this.initialFilePath});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'CinemaStream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: Locale(locale.languageCode),
      builder: (context, child) {
        return Directionality(
          textDirection: locale.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox(),
        );
      },
      home: HomeView(initialFilePath: initialFilePath),
    );
  }
}
