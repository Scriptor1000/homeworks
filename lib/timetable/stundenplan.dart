import 'package:flutter/material.dart';

/// Demo page with sample timetable data.

class TimetableDemoPage extends StatelessWidget {
  const TimetableDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example: variable days and slots — replace with any data source.
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final slots = [
      '08:00\n08:45',
      '08:50\n09:35',
      '09:50\n10:35',
      '10:50\n11:35',
      '11:40\n12:25',
      '12:30\n13:15',
    ];

    // Map of (dayIndex, slotIndex) -> entry. This structure makes the timetable
    // general-purpose: you can populate it from an API or local DB.
    final Map<Position, TimetableEntry> entries = {
      Position(0, 0): TimetableEntry(
        subject: 'Math',
        teacher: 'Mr. Müller',
        room: '201',
        color: Colors.green.shade400,
      ),
      Position(0, 1): TimetableEntry(
        subject: 'Physics',
        teacher: 'Ms. Schmidt',
        room: 'Lab A',
        color: Colors.blue.shade400,
      ),
      Position(1, 0): TimetableEntry(
        subject: 'English',
        teacher: 'Mrs. Brown',
        room: '101',
        color: Colors.orange.shade400,
      ),
      Position(2, 2): TimetableEntry(
        subject: 'History',
        teacher: 'Mr. Lee',
        room: '103',
        color: Colors.purple.shade300,
      ),
      Position(3, 4): TimetableEntry(
        subject: 'PE',
        teacher: 'Coach',
        room: 'Gym',
        color: Colors.red.shade300,
      ),
      // Add more entries to test
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable (mithilfe von KI(gerade unbenutzbar))'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TimetableWidget(
          days: days,
          timeSlots: slots,
          entries: entries,
          // optional customization:
          cellWidth: 140,
          cellHeight: 84,
          onTapEntry: (pos, entry) {
            if (entry != null) {
              showModalBottomSheet(
                context: context,
                builder: (_) => EntryDetailSheet(entry: entry),
              );
            }
          },
        ),
      ),
    );
  }
}

/// Position (dayIndex, slotIndex) as key for entries.
class Position {
  final int day;
  final int slot;
  const Position(this.day, this.slot);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          slot == other.slot;

  @override
  int get hashCode => day.hashCode ^ slot.hashCode;
}

/// Data model for a timetable cell.
class TimetableEntry {
  final String subject;
  final String? teacher;
  final String? room;
  final Color color;

  TimetableEntry({
    required this.subject,
    this.teacher,
    this.room,
    required this.color,
  });
}

/// Reusable Timetable widget.
/// - [days]: labels for columns (e.g., Mon, Tue)
/// - [timeSlots]: labels for rows (e.g., 08:00-08:45)
/// - [entries]: map of Position -> TimetableEntry
class TimetableWidget extends StatelessWidget {
  final List<String> days;
  final List<String> timeSlots;
  final Map<Position, TimetableEntry> entries;
  final double cellWidth;
  final double cellHeight;
  final void Function(Position pos, TimetableEntry? entry)? onTapEntry;

  const TimetableWidget({
    super.key,
    required this.days,
    required this.timeSlots,
    required this.entries,
    this.cellWidth = 120,
    this.cellHeight = 72,
    this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    // Outer horizontal scroll, inner vertical scroll to allow two-axis scrolling.
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          // vertical
          child: Table(
            defaultColumnWidth: FixedColumnWidth(cellWidth),
            border: TableBorder(
              verticalInside: BorderSide(
                color: Colors.grey.withValues(alpha: 0.12),
              ),
              horizontalInside: BorderSide(
                color: Colors.grey.withValues(alpha: 0.12),
              ),
            ),
            children: _buildRows(context),
          ),
        ),
      ),
    );
  }

  List<TableRow> _buildRows(BuildContext context) {
    final List<TableRow> rows = [];

    // Header row: empty corner cell + day headers
    rows.add(
      TableRow(
        children: [
          // top-left corner for times header label (optional)
          SizedBox(
            height: cellHeight * 0.75,
            width: cellWidth,
            child: Center(
              child: Text(
                'Time',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ...days.map((d) => _buildHeaderCell(d)),
        ],
      ),
    );

    // For each time slot row, create left time cell + day cells
    for (int r = 0; r < timeSlots.length; r++) {
      final String slotLabel = timeSlots[r];
      final List<Widget> rowCells = [];

      // left column: time slot
      rowCells.add(
        Container(
          height: cellHeight,
          padding: const EdgeInsets.all(6),
          alignment: Alignment.center,
          color: Colors.grey.shade50,
          child: Text(
            slotLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );

      // day columns
      for (int c = 0; c < days.length; c++) {
        final pos = Position(c, r);
        final entry = entries[pos];
        rowCells.add(_buildContentCell(context, pos, entry));
      }

      rows.add(TableRow(children: rowCells));
    }

    return rows;
  }

  Widget _buildHeaderCell(String label) {
    return Container(
      height: cellHeight * 0.75,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildContentCell(
    BuildContext context,
    Position pos,
    TimetableEntry? entry,
  ) {
    if (entry == null) {
      // empty cell
      return InkWell(
        onTap: () => onTapEntry?.call(pos, null),
        child: SizedBox(
          height: cellHeight,
          child: const Center(child: Text('')),
        ),
      );
    }

    // Card-like compact cell
    return InkWell(
      onTap: () => onTapEntry?.call(pos, entry),
      child: Container(
        height: cellHeight,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: entry.color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildEntryContent(entry),
      ),
    );
  }

  Widget _buildEntryContent(TimetableEntry entry) {
    // Compact content: subject (bold), optional teacher/room lines smaller
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            entry.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (entry.teacher != null || entry.room != null) ...[
          const SizedBox(height: 4),
          Text(
            _smallMeta(entry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String _smallMeta(TimetableEntry e) {
    final pieces = <String>[];
    if ((e.teacher ?? '').isNotEmpty) pieces.add(e.teacher!);
    if ((e.room ?? '').isNotEmpty) pieces.add(e.room!);
    return pieces.join(' · ');
  }
}

/// Bottom sheet showing details of a timetable entry.
class EntryDetailSheet extends StatelessWidget {
  final TimetableEntry entry;
  const EntryDetailSheet({required this.entry, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Wrap(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: entry.color,
              child: const Icon(Icons.book, color: Colors.white),
            ),
            title: Text(
              entry.subject,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${entry.teacher ?? ''}${entry.teacher != null && entry.room != null ? ' · ' : ''}${entry.room ?? ''}',
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              'Here you can display more details, links to materials, homework, or quick actions like "Add homework", "Share" or "Mark as favorite".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
