import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/providers/product_provider.dart';
import 'package:gravity_desktop_app/providers/subscriptions_provider.dart';
import 'package:gravity_desktop_app/providers/time_prices_provider.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/providers/notes_provider.dart';

Future<void> refreshAllProviders(WidgetRef ref) async {
  // Refresh all providers that have refresh methods
  // We call each provider's refresh method individually since they have different notifier types

  await Future.wait([
    ref.read(productsProvider.notifier).refresh(),
    ref.read(currentPlayersProvider.notifier).refresh(),
    ref.read(subscriptionsProvider.notifier).refresh(),
    ref.read(pricesProvider.notifier).refresh(),
    ref.read(pastPlayersProvider.notifier).refresh(),
    ref.read(notesProvider.notifier).refresh(),
  ]);
}
