import 'package:flutter/material.dart';
import 'generated/l10n/app_localizations.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: wire GoRouter in Phase 3
    return MaterialApp(
      title: 'Flags Around the World',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Text(AppLocalizations.of(context).scaffoldHomeLabel),
          ),
        ),
      ),
    );
  }
}
