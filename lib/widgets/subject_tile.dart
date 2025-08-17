import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../utilities/constants.dart';
import '../database/models/subject.dart';
import 'subject_avatar.dart';

/// A [ListTile] to displays the subject with functionallity to provide an trailing Widget.
class SubjectTile extends StatelessWidget {
  const SubjectTile(
      {super.key, required this.subject, this.trailing, this.onTap});

  final Subject subject;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backColor =
        subject.backColor.harmonizeWith(Theme.of(context).primaryColor);
    final avatar = SubjectAvatar(subject: subject);
    final title = subject.name;
    return SubjectTileTemplate(
      title: title,
      avatarChild: avatar,
      trailing: trailing,
      backColor: backColor,
      onTap: onTap,
    );
  }
}

class SubjectTileTemplate extends StatelessWidget {
  final String title;
  final Widget avatarChild;
  final Color backColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SubjectTileTemplate({
    super.key,
    required this.title,
    required this.avatarChild,
    required this.trailing,
    required this.backColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BorderRadiusConstants.subjects),
        border: Border.all(color: backColor, width: 3),
      ),
      child: ListTile(
        title: Text(title),
        leading: CircleAvatar(
          backgroundColor: backColor,
          child: avatarChild,
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
