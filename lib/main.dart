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

  // ─── Sync RevenueCat identity with Supabase auth state ───────────────────
  // Covers three scenarios:
  //   • initialSession  — cold-start with an existing Supabase session
  //   • signedIn        — fresh email/social sign-in
  //   • tokenRefreshed  — silent token refresh mid-session
  //   • signedOut       — explicit sign-out
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed) {
      RevenueCatService().logIn();
    }
    if (event == AuthChangeEvent.signedOut) {
      RevenueCatService().logOut();
    }
  });
  print('RC Key: ${dotenv.env['REVENUECAT_IOS_KEY']}');

  runApp(
    ProviderScope(
      child: GowaiApp(),
    ),
  );
}
