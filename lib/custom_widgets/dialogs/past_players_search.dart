import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:gravity_desktop_app/custom_widgets/dialogs/my_dialog.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/past_players_provider.dart';
import 'package:gravity_desktop_app/screens/player_details.dart';
import 'package:gravity_desktop_app/utils/constants.dart';

class PastPlayersSearch extends ConsumerStatefulWidget {
  const PastPlayersSearch({super.key});

  @override
  ConsumerState<PastPlayersSearch> createState() => _PastPlayersSearchState();
}

class _PastPlayersSearchState extends ConsumerState<PastPlayersSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _navigateToPlayerDetails(Player player) {
    Navigator.of(context).pop(); // Close the dialog first
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerDetails(player),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MyDialog(
      width: 500.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dialog Header
          Row(
            children: [
              const Icon(
                Icons.search,
                color: Color(0xFF3949AB),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search Past Players',
                  style: AppTextStyles.sectionHeaderStyle.copyWith(
                    fontSize: 22,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search Field with Autocomplete
          Text(
            'Enter player name to search:',
            style: AppTextStyles.regularTextStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          Autocomplete<Player>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Player>.empty();
              }

              return ref.watch(pastPlayersProvider).when(
                    data: (pastPlayers) {
                      final fuse = Fuzzy(
                        pastPlayers,
                        options: FuzzyOptions(
                          keys: [
                            WeightedKey(
                              name: 'name',
                              getter: (Player player) => player.name,
                              weight: 1,
                            ),
                          ],
                          threshold: fuzzyThreshold
                        ),
                      );

                      final results = fuse.search(textEditingValue.text);
                      return results.map((result) => result.item);
                    },
                    error: (err, stack) {
                      log("Error fetching past players: $err, $stack");
                      return const Iterable<Player>.empty();
                    },
                    loading: () => const Iterable<Player>.empty(),
                  );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                      maxWidth: 456, // Match dialog width minus padding
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final player = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(player),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3949AB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      player.name.isNotEmpty
                                          ? player.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.name,
                                        style: AppTextStyles.regularTextStyle
                                            .copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Age: ${player.age}',
                                        style: AppTextStyles.subtitleTextStyle
                                            .copyWith(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            displayStringForOption: (Player option) => option.name,
            onSelected: (Player selection) async {
              _navigateToPlayerDetails(selection);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              // Sync our controller with the autocomplete controller
              _searchController.text = controller.text;
              _searchController.selection = controller.selection;

              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: AppTextStyles.regularTextStyle,
                decoration: InputDecoration(
                  hintText: 'Type player name...',
                  hintStyle: AppTextStyles.subtitleTextStyle,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF3949AB),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF3949AB),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onFieldSubmitted: (value) => onFieldSubmitted(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Loading/Error States
          ref.watch(pastPlayersProvider).when(
                data: (players) {
                  if (players.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No past players found in the database.',
                            style: AppTextStyles.subtitleTextStyle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3949AB).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: const Color(0xFF3949AB),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${players.length} players available for search',
                          style: AppTextStyles.subtitleTextStyle.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF3949AB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading players...',
                        style: AppTextStyles.subtitleTextStyle.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, stack) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error loading players: ${error.toString()}',
                          style: AppTextStyles.subtitleTextStyle.copyWith(
                            fontSize: 14,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
