import 'package:flutter/material.dart';
import 'generated/l10n/app_localizations.dart';
import 'features/map/map_screen.dart';
import 'features/map/spike_map_screen.dart';

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
          body: const MapScreen(),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SpikeMapScreen(),
              ),
            ),
            label: const Text('Spike'),
            icon: const Icon(Icons.map),
          ),
        ),
      ),
    );
  }
}
