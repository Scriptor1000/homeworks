import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SearchScreen<T> extends StatefulWidget {
  final List<T> things;
  final String searchHint;
  final String Function(T) getQueryString;
  final Widget Function(BuildContext, T, void Function(T)) buildTile;
  final void Function(T) onSelected;

  const SearchScreen({
    super.key,
    required this.things,
    required this.searchHint,
    required this.getQueryString,
    required this.buildTile,
    required this.onSelected,
  });

  @override
  State<SearchScreen<T>> createState() => _TeacherSelectionScreenState<T>();
}

class _TeacherSelectionScreenState<T> extends State<SearchScreen<T>> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.things.where((e) {
      return widget.getQueryString(e).contains(query.toLowerCase());
    }).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Column(
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
                        widget.onSelected,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Container(
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
        ],
      ),
    );
  }
}
