import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/routes/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/providers/auth_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    return MaterialApp.router(
      title: 'Ghumify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router(context),
    );
  }
}
