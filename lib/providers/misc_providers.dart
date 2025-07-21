// providers/selected_players_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/models/player.dart';

class SelectedPlayersNotifier extends StateNotifier<Set<Player>> {
  SelectedPlayersNotifier() : super({}); // Initial state is an empty set

  void togglePlayer(Player player) {
    // When updating state with StateNotifier, i have to create a new instance
    // of the state for Riverpod to detect the change and notify listeners.
    if (state.contains(player)) {
      state = {...state}..remove(player);
    } else {
      state = {...state, player};
    }
  }

  void clearSelection() {
    state = {};
  }

  bool isSelected(Player player) {
    return state.contains(player);
  }
}

final selectedPlayersProvider =
    StateNotifierProvider<SelectedPlayersNotifier, Set<Player>>((ref) {
  return SelectedPlayersNotifier();
});
  