import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/routes/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mocking Firebase initialization since we don't have config
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const GhumifyApp(),
    ),
  );
}

class GhumifyApp extends StatelessWidget {
  const GhumifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();

    return MaterialApp.router(
      title: 'Ghumify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settingsProvider.themeMode,
      routerConfig: AppRouter.router(context),
    );
  }
}
