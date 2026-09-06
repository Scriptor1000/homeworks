import 'package:flutter/material.dart';

import '../utilities/constants.dart';

/// A widget that displays an information box with a title, icon, and multiple paragraphs of text.
/// This widget is used to provide additional information or instructions in a visually distinct way.
class InfoBox extends StatelessWidget {
  final String? title;

  /// A list of paragraphs wich are separated to display in the info box.
  final List<String> paragraphs;

  final IconData icon;
  final Color? accentColor;

  const InfoBox({
    super.key,
    this.title,
    required this.paragraphs,
    this.icon = Icons.info_outline,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color iconAndTitleColor = accentColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(BorderRadiusConstants.infoBox),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zeige die Titelzeile nur an, wenn ein Titel vorhanden ist
          if (title != null)
            Row(
              children: [
                Icon(icon, color: iconAndTitleColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconAndTitleColor,
                  ),
                ),
              ],
            ),

          // Wenn ein Titel vorhanden ist, füge einen Abstand hinzu
          if (title != null) const SizedBox(height: 8),

          // Generiere für jeden Absatz ein Text-Widget
          ...paragraphs.asMap().entries.map((entry) {
            final index = entry.key;
            final paragraph = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0)
                  const SizedBox(height: 4), // Abstand zwischen Absätzen
                Text(paragraph, style: const TextStyle(fontSize: 13)),
              ],
            );
          }),
        ],
      ),
    );
  }
}
