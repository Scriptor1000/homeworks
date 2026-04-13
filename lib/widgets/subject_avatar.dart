import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../database/models/subject.dart';

class SubjectAvatar extends StatelessWidget {
  final Subject? subject;

  const SubjectAvatar({super.key, this.subject});

  String _standardizeShortName(String shortName) {
    return shortName
        .replaceAll(RegExp(r's_|\d'), '')
        .replaceAll(' ', '\n')
        .replaceAllMapped(RegExp('s([A-Z])'), (match) => match.group(1)!);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (subject != null) {
      final backColor = subject!.backColor.harmonizeWith(
        Theme.of(context).primaryColor,
      );
      final foreColor = subject!.foreColor.harmonizeWith(backColor);
      return CircleAvatar(
        backgroundColor: backColor,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: Text(
              _standardizeShortName(subject!.shortName),
              textAlign: TextAlign.center,
              style: TextStyle(color: foreColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        backgroundColor: colorScheme.tertiaryContainer,
        child: Icon(
          Icons.question_mark,
          color: colorScheme.onTertiaryContainer,
        ),
      );
    }
  }
}
