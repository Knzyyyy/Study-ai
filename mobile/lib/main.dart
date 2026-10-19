import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zalhlzvuehqupgmiqtnl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbGhsenZ1ZWhxdXBnbWlxdG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3NTg0NzcsImV4cCI6MjEwNjMzNDQ3N30.fNvyMKbLlXTczhyZbVvLiJf0RPH5j66tiacz--Be2jA',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'AI Tutor App',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7560B5))
            .copyWith(
              primary: const Color(0xFF7560B5),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFEAE3F7),
              onPrimaryContainer: const Color(0xFF30283F),
              secondary: const Color(0xFF7560B5),
              onSecondary: Colors.white,
              secondaryContainer: const Color(0xFFEAE3F7),
              onSecondaryContainer: const Color(0xFF30283F),
              surface: Colors.white,
              onSurface: const Color(0xFF30283F),
              onSurfaceVariant: const Color(0xFF716B80),
              outline: const Color(0xFFE7E2F0),
              outlineVariant: const Color(0xFFE7E2F0),
            ),
        scaffoldBackgroundColor: const Color(0xFFF7F5FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF30283F),
          surfaceTintColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF9275CD),
          linearTrackColor: Color(0xFFF2EDF9),
        ),
        useMaterial3: true,
      ),
    );
  }
}
