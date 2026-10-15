import 'package:flutter/material.dart';

import '../../data/models/match_models.dart';

enum MatchPhase { upcoming, live, finished }

MatchPhase phaseOf(MatchEvent event) {
  if (event.isFinished) return MatchPhase.finished;
  if (event.isUpcoming) return MatchPhase.upcoming;
  return MatchPhase.live;
}

String statusText(MatchEvent event) {
  final phase = phaseOf(event);
  if (phase == MatchPhase.live) return event.statusDescription ?? 'CANLI';
  if (phase == MatchPhase.finished) return event.statusDescription ?? 'MS';
  return '';
}

Color statusColor(BuildContext context, MatchPhase phase) {
  final scheme = Theme.of(context).colorScheme;
  switch (phase) {
    case MatchPhase.live:
      return scheme.error;
    case MatchPhase.finished:
      return scheme.onSurfaceVariant;
    case MatchPhase.upcoming:
      return scheme.primary;
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final phase = phaseOf(event);
    final text = statusText(event);
    if (text.isEmpty) return const SizedBox.shrink();

    final color = statusColor(context, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
