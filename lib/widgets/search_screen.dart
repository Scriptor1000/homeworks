import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utilities/common.dart';

/// A generic search screen widget
///
/// This widget provides a search interface for a list of items of type [T].
/// You need to provide:
/// - [searchableItems]: The list of items to search from.
/// - [searchHint]: A hint text displayed in the search bar.
/// - [getQueryString]: A function that returns a string for each provided item. Only if the string contains the search query, the item will be listed as possible result.
/// - [buildTile]: A function that builds a widget for each item in the search results. It receives the current [BuildContext], the item of type [T], and a callback to be called when the user taps on the item.
/// - [onSelected]: A callback that is called when the user selects an item.
///
/// The search is NOT case-sensitive, both user query and item query will be converted to lower case by this widget.
///
/// Information: The callback provided to [buildTile] simply calls the provided [onSelected] with the item.
/// The [onSelected] Method must be provided because it can also be called if the user submits a query with only one matching item.
class SearchScreen<T> extends StatefulWidget {
  final List<T> searchableItems;
  final String searchHint;
  final String Function(T) getQueryString;
  final Widget Function(BuildContext, T, void Function()) buildTile;
  final void Function(T) onSelected;

  const SearchScreen({
    super.key,
    required this.searchableItems,
    required this.searchHint,
    required this.getQueryString,
    required this.buildTile,
    required this.onSelected,
  });

  @override
  State<SearchScreen<T>> createState() => _SearchScreenState<T>();
}

class _SearchScreenState<T> extends State<SearchScreen<T>> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.searchableItems.where((e) {
      return widget
          .getQueryString(e)
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          withConstrainedWidth(
            context,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        // This could be improved
                        return const Gap(56 + 16);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: widget.buildTile(
                          context,
                          filtered[index],
                          () => widget.onSelected(filtered[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          withConstrainedWidth(
            context,
            child: Container(
              alignment: Alignment.bottomCenter,
              margin: const EdgeInsets.only(bottom: 16),
              // decoration: BoxDecoration(color: Colors.transparent),
              child: SearchBar(
                autoFocus: true,
                onChanged: (query) {
                  setState(() {
                    this.query = query;
                  });
                },
                onSubmitted: (query) {
                  if (filtered.length == 1) {
                    widget.onSelected(filtered[0]);
                  }
                },
                leading: const Icon(Icons.search),
                hintText: widget.searchHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
