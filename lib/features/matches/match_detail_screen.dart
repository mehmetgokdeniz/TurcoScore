import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/player_rating.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../core/widgets/rating_badge.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/team_logo.dart';
import '../../data/favorites/favorite_store.dart';
import '../../data/models/event_details.dart';
import '../../data/models/match_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/detail_controllers.dart';
import '../../state/load_state.dart';
import '../player/player_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({super.key, required this.preview});

  final MatchEvent preview;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          MatchDetailController(context.read<ScoreRepository>(), preview),
      child: const _MatchDetailView(),
    );
  }
}

class _MatchDetailView extends StatelessWidget {
  const _MatchDetailView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MatchDetailController>();
    final event = controller.event;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(event.tournamentName, maxLines: 1),
          actions: [
            Builder(
              builder: (context) {
                final store = context.watch<FavoriteStore>();
                final isFavorite = store.isFavorite(event.id);
                return IconButton(
                  tooltip:
                      isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  onPressed: () => store.toggle(event),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.redAccent : null,
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Özet'),
              Tab(text: 'İstatistik'),
              Tab(text: 'Kadrolar'),
            ],
          ),
        ),
        body: switch (controller.state) {
          LoadState.error => ErrorView(
              message: controller.errorMessage ?? 'Hata',
              onRetry: controller.load,
            ),
          LoadState.ready => TabBarView(
              children: [
                _SummaryTab(bundle: controller.bundle),
                _StatsTab(statistics:
                    controller.bundle?.statistics ?? MatchStatistics.empty),
                _LineupsTab(bundle: controller.bundle),
              ],
            ),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.bundle});

  final EventBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bundle = this.bundle;
    if (bundle == null) return const LoadingView();
    final event = bundle.event;

    // Dakika dakika tüm olaylar (gol, kart, değişiklik, VAR, penaltı...).
    final incidents = bundle.incidents;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  event.countryName == null
                      ? event.tournamentName
                      : '${event.countryName} · ${event.tournamentName}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMMM y, HH:mm', 'tr_TR').format(event.kickoff),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TeamColumn(team: event.home),
                    ),
                    Column(
                      children: [
                        Text(
                          event.homeScore != null && event.awayScore != null
                              ? '${event.homeScore} - ${event.awayScore}'
                              : 'vs',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusBadge(event: event),
                        if (event.homePenalties != null ||
                            event.awayPenalties != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Penaltılar: ${event.homePenalties ?? 0} - ${event.awayPenalties ?? 0}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: _TeamColumn(team: event.away),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (bundle.form.isNotEmpty) ...[
          _FormCard(form: bundle.form),
          const SizedBox(height: 16),
        ],
        if (bundle.headToHead.isNotEmpty) ...[
          _HeadToHeadCard(
            matches: bundle.headToHead,
            template: event,
          ),
          const SizedBox(height: 16),
        ],
        Text('Maç Olayları', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (incidents.isEmpty)
          const EmptyView(
            icon: Icons.timeline_rounded,
            message: 'Maç olayı bulunamadı',
          )
        else
          ...incidents.map((incident) => _IncidentTile(
                incident: incident,
                homeTeamId: event.home.id,
                homeName: event.home.name,
                awayName: event.away.name,
              )),
      ],
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team});

  final TeamRef team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamLogo(team: team, size: 48),
        const SizedBox(height: 8),
        Text(
          team.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.incident,
    required this.homeTeamId,
    required this.homeName,
    required this.awayName,
  });

  final MatchIncident incident;
  final int homeTeamId;
  final String homeName;
  final String awayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = incident.isGoal
        ? Icons.sports_soccer_rounded
        : incident.isCard
            ? Icons.square_rounded
            : incident.isSubstitution
                ? Icons.swap_horiz_rounded
                : incident.type == 'var'
                    ? Icons.videocam_rounded
                    : incident.type == 'penalty'
                        ? Icons.ads_click_rounded
                        : Icons.info_outline_rounded;

    final isRedCard = incident.isCard &&
        (incident.text ?? '').toLowerCase().contains('kırmızı');
    final color = incident.isGoal
        ? theme.colorScheme.primary
        : incident.isCard
            ? (isRedCard ? const Color(0xFFE03131) : Colors.amber)
            : incident.type == 'var'
                ? theme.colorScheme.tertiary
                : theme.colorScheme.outline;
    final isHome = incident.teamId == homeTeamId;
    final teamName =
        incident.teamId == null ? '' : (isHome ? homeName : awayName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(incident.minute,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.playerName ??
                      (incident.isSubstitution ? 'Oyuncu değişikliği' : '-'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (incident.text != null)
                  Text(
                    incident.text!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  )
                else if (teamName.isNotEmpty)
                  Text(
                    teamName,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          if (incident.homeScore != null && incident.awayScore != null)
            Text(
              '${incident.homeScore} - ${incident.awayScore}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.statistics});

  final MatchStatistics statistics;

  @override
  Widget build(BuildContext context) {
    if (statistics.groups.isEmpty) {
      return const EmptyView(
        icon: Icons.query_stats_rounded,
        message: 'İstatistik bulunamadı',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in statistics.groups) ...[
          Text(group.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final item in group.items) ...[
                    _StatRow(item: item),
                    if (item != group.items.last) const Divider(height: 16),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.item});

  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = item.homeRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.home,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(item.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            Expanded(
              child: Text(item.away,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        if (ratio != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: (ratio * 100).round().clamp(1, 99),
                child: _Bar(color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: ((1 - ratio) * 100).round().clamp(1, 99),
                child: _Bar(color: theme.colorScheme.tertiary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

class _LineupsTab extends StatefulWidget {
  const _LineupsTab({required this.bundle});

  final EventBundle? bundle;

  @override
  State<_LineupsTab> createState() => _LineupsTabState();
}

class _LineupsTabState extends State<_LineupsTab> {
  bool _showHome = true;

  void _openPlayer(LineupPlayer entry) {
    if (entry.player.id <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          playerId: entry.player.id,
          initialName: entry.player.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    if (bundle == null) return const LoadingView();

    final hasPlayers = bundle.homeLineup.players.isNotEmpty ||
        bundle.awayLineup.players.isNotEmpty;
    if (!hasPlayers) {
      return const EmptyView(
        icon: Icons.groups_rounded,
        message: 'Kadro bilgisi bulunamadı',
      );
    }

    final event = bundle.event;
    final lineup = _showHome ? bundle.homeLineup : bundle.awayLineup;
    final team = _showHome ? event.home : event.away;
    final theme = Theme.of(context);

    final flagged = lineup.players.where((p) => p.isStarter).toList();
    final starters =
        flagged.length >= 7 ? flagged : lineup.players.take(11).toList();
    final subs =
        lineup.players.where((p) => !starters.contains(p)).toList();

    final ratings =
        lineup.players.map((p) => p.rating).whereType<double>().toList();
    final average =
        ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _TeamToggle(
                  label: event.home.name,
                  selected: _showHome,
                  onTap: () => setState(() => _showHome = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TeamToggle(
                  label: event.away.name,
                  selected: !_showHome,
                  onTap: () => setState(() => _showHome = false),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              TeamLogo(team: team, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (lineup.formation != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    lineup.formation!,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              if (average != null) RatingBadge(rating: average),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _PitchView(
                players: starters,
                formation: lineup.formation,
                onTap: _openPlayer,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  ratings.isEmpty
                      ? 'Maç başlamadan puan gösterilmez.'
                      : 'Puanlar istatistiklerden türetilmiştir (tahmini).',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              if (subs.isNotEmpty) ...[
                Text(
                  'Yedekler',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final entry in subs)
                        ListTile(
                          dense: true,
                          leading: _PlayerAvatar(entry: entry, radius: 16),
                          title: Text(entry.player.name),
                          subtitle: Text(entry.position ?? '-'),
                          trailing: entry.rating == null
                              ? null
                              : RatingBadge(rating: entry.rating!),
                          onTap: () => _openPlayer(entry),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamToggle extends StatelessWidget {
  const _TeamToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      showCheckmark: false,
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.entry, required this.radius});

  final LineupPlayer entry;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Text(
      entry.player.name.isEmpty ? '?' : entry.player.name[0].toUpperCase(),
      style: TextStyle(
        fontSize: radius * 0.8,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
      ),
    );

    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: initials,
    );

    final url = entry.player.photoUrl;
    if (url == null) return fallback;

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => fallback,
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

/// Dizilise göre sahaya yerleşen oyuncu ağacı (Fotoğraf + puan + isim).
class _PitchView extends StatelessWidget {
  const _PitchView({
    required this.players,
    required this.formation,
    required this.onTap,
  });

  final List<LineupPlayer> players;
  final String? formation;
  final void Function(LineupPlayer) onTap;

  static const Color _field = Color(0xFF123B25);

  List<List<LineupPlayer>> _rows() {
    if (players.isEmpty) return const [];
    final list = List<LineupPlayer>.of(players);

    LineupPlayer? goalkeeper;
    if ((list.first.position ?? '').toUpperCase().startsWith('G')) {
      goalkeeper = list.removeAt(0);
    } else {
      final index =
          list.indexWhere((p) => (p.position ?? '').toUpperCase().startsWith('G'));
      if (index >= 0) goalkeeper = list.removeAt(index);
    }

    final counts = _formationCounts(list.length);
    final rows = <List<LineupPlayer>>[
      if (goalkeeper != null) [goalkeeper],
    ];

    var cursor = 0;
    for (final count in counts) {
      if (cursor >= list.length) break;
      final end = cursor + count > list.length ? list.length : cursor + count;
      rows.add(list.sublist(cursor, end));
      cursor = end;
    }
    if (cursor < list.length) rows.add(list.sublist(cursor));
    return rows;
  }

  List<int> _formationCounts(int outfield) {
    final parsed = (formation ?? '')
        .split('-')
        .map(int.tryParse)
        .whereType<int>()
        .where((n) => n > 0)
        .toList();
    final total = parsed.fold<int>(0, (sum, n) => sum + n);
    if (parsed.isNotEmpty && total == outfield) return parsed;

    const chunk = 4;
    return [
      for (var i = 0; i < outfield; i += chunk)
        i + chunk > outfield ? outfield - i : chunk,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.68,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final diameter = (width * 0.16).clamp(38.0, 54.0);

          final rows = _rows();
          final nodes = <Widget>[];
          for (var r = 0; r < rows.length; r++) {
            final row = rows[r];
            final y = rows.length == 1
                ? height * 0.5
                : height * (0.12 + 0.75 * r / (rows.length - 1));
            for (var c = 0; c < row.length; c++) {
              final x = width * (c + 1) / (row.length + 1);
              final nodeHeight = diameter + 46;
              nodes.add(
                Positioned(
                  left: x - (diameter + 30) / 2,
                  top: y - nodeHeight / 2,
                  width: diameter + 30,
                  child: _PitchPlayer(
                    entry: row[c],
                    diameter: diameter,
                    onTap: onTap,
                  ),
                ),
              );
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: _PitchPainter(),
              child: Stack(children: nodes),
            ),
          );
        },
      ),
    );
  }
}

class _PitchPlayer extends StatelessWidget {
  const _PitchPlayer({
    required this.entry,
    required this.diameter,
    required this.onTap,
  });

  final LineupPlayer entry;
  final double diameter;
  final void Function(LineupPlayer) onTap;

  @override
  Widget build(BuildContext context) {
    final url = entry.player.photoUrl;
    final rating = entry.rating;
    final initials = Text(
      entry.player.name.isEmpty ? '?' : entry.player.name[0].toUpperCase(),
      style: TextStyle(
        fontSize: diameter * 0.32,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF123B25),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(entry),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: url == null
                      ? Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: initials,
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: initials,
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: initials,
                          ),
                        ),
                ),
              ),
              if (rating != null)
                Positioned(
                  bottom: -7,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: ratingColor(rating),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ratingLabel(rating),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            [
              if (entry.jerseyNumber != null) '${entry.jerseyNumber}',
              entry.player.name,
            ].join(' '),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// İki takımın son5 maçı (G/B/M rozetleri).
class _FormCard extends StatelessWidget {
  const _FormCard({required this.form});

  final List<TeamForm> form;

  static const _labels = {'W': 'G', 'D': 'B', 'L': 'M'};

  Color _colorFor(BuildContext context, String result) {
    switch (result) {
      case 'W':
        return const Color(0xFF2FA84F);
      case 'D':
        return const Color(0xFFF08C00);
      default:
        return const Color(0xFFE03131);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son 5 maç',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final teamForm in form) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    NetworkCircleAvatar(
                      url: teamForm.logoUrl,
                      name: teamForm.teamName,
                      radius: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teamForm.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final result in teamForm.results)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _colorFor(context, result),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _labels[result] ?? result,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// İki takım arasındaki geçmiş maçlar — satıra dokununca o maç açılır.
class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.matches, required this.template});

  final List<HeadToHeadMatch> matches;
  final MatchEvent template;

  MatchEvent _toEvent(HeadToHeadMatch match) => MatchEvent(
        id: match.id,
        startTimestamp: match.startTimestamp,
        tournamentName: template.tournamentName,
        tournamentId: template.tournamentId,
        countryName: template.countryName,
        tournamentFlagUrl: null,
        home: TeamRef(
          id: 0,
          name: match.homeName,
          logoUrl: match.homeLogoUrl,
        ),
        away: TeamRef(
          id: 0,
          name: match.awayName,
          logoUrl: match.awayLogoUrl,
        ),
        statusType: match.isFinished ? 'finished' : 'notstarted',
        statusDescription: match.isFinished ? 'MS' : null,
        homeScore: match.isFinished ? match.homeScore : null,
        awayScore: match.isFinished ? match.awayScore : null,
        sourceKey: template.sourceKey,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              'İki takım arasındaki maçlar',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final match in matches)
            InkWell(
              onTap: match.id <= 0
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MatchDetailScreen(preview: _toEvent(match)),
                        ),
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        match.startTimestamp <= 0
                            ? ''
                            : DateFormat('dd.MM.yy').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    match.startTimestamp * 1000),
                              ),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        match.homeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        match.homeScore == null || match.awayScore == null
                            ? '-'
                            : '${match.homeScore} - ${match.awayScore}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        match.awayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const inset = 8.0;
    final field = Rect.fromLTWH(inset, inset, size.width - inset * 2,
        size.height - inset * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(10)),
      line,
    );

    canvas.drawLine(
      Offset(inset, size.height / 2),
      Offset(size.width - inset, size.height / 2),
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.15,
      line,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    void boxes(double top) {
      final boxWidth = size.width * 0.54;
      final boxHeight = size.height * 0.13;
      final y = top == inset ? top : top - boxHeight;
      canvas.drawRect(
        Rect.fromLTWH((size.width - boxWidth) / 2, y, boxWidth, boxHeight),
        line,
      );

      final smallWidth = size.width * 0.26;
      final smallHeight = size.height * 0.06;
      final sy = top == inset ? top : top - smallHeight;
      canvas.drawRect(
        Rect.fromLTWH(
            (size.width - smallWidth) / 2, sy, smallWidth, smallHeight),
        line,
      );
    }

    boxes(inset);
    boxes(size.height - inset);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => false;
}
