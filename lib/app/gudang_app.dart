import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_defaults.dart';
import '../notifiers/app_settings_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/item_notifier.dart';
import '../notifiers/location_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../notifiers/user_management_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/remote_settings_sync.dart';
import 'auth_gate.dart';

class GudangApp extends StatelessWidget {
  const GudangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsNotifier()),
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
        ChangeNotifierProvider(create: (_) => UserManagementNotifier()),
        ChangeNotifierProvider(create: (_) => ItemNotifier()),
        ChangeNotifierProvider(create: (_) => LocationNotifier()),
        ChangeNotifierProvider(create: (_) => StockNotifier()),
      ],
      child: RemoteSettingsSync(
        child: Consumer<AppSettingsNotifier>(
          builder: (context, appSettings, _) {
            final themed = AppTheme.forAppearance(
              appSettings.settings.appearance,
            );
            return MaterialApp(
              title: AppDefaults.appTitle,
              debugShowCheckedModeBanner: false,
              locale: const Locale('id', 'ID'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
              theme: themed,
              darkTheme: themed,
              home: const AuthGate(),
            );
          },
        ),
      ),
    );
  }
}
