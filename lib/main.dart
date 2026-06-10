import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global status bar style — transparent background, dark icons for light UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
  ));

  await dotenv.load(fileName: '.env');

  // ignore: deprecated_member_use
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  try {
    await RevenueCatService().initialize();
    await RevenueCatService().debugOfferings();
  } catch (_) {
    // RevenueCat initialization failure is non-fatal
  }

  runApp(
    ProviderScope(
      child: GowaiApp(),
    ),
  );
}
