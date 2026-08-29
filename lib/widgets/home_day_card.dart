import 'package:flutter/material.dart';

class HomeDayCard extends StatelessWidget {
  const HomeDayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: const Flex(
        direction: Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        children: [Placeholder()],
      ),
    );
  }
}
