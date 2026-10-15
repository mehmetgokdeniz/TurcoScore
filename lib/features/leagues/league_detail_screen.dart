import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/team_logo.dart';
import '../../data/models/tournament_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/leagues_controller.dart';
import '../../state/load_state.dart';

class LeagueDetailScreen extends StatelessWidget {
  const LeagueDetailScreen({super.key, required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          StandingsController(context.read<ScoreRepository>(), tournament),
      child: const _LeagueDetailView(),
    );
  }
}

class _LeagueDetailView extends StatelessWidget {
  const _LeagueDetailView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StandingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.tournament.title, maxLines: 1),
        actions: [
          if (controller.seasons.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Season>(
                  value: controller.selectedSeason,
                  items: [
                    for (final season in controller.seasons)
                      DropdownMenuItem(value: season, child: Text(season.name)),
                  ],
                  onChanged: (season) {
                    if (season != null) controller.selectSeason(season);
                  },
                ),
              ),
            ),
        ],
      ),
      body: switch (controller.state) {
        LoadState.error => ErrorView(
            message: controller.errorMessage ?? 'Hata',
            onRetry: controller.load,
          ),
        LoadState.ready => _StandingsTable(table: controller.table),
        _ => const LoadingView(),
      },
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.table});

  final StandingsTable? table;

  // Sütun genişlikleri: yatay kaydırmalı tablo, taşma yok.
  static const double _posWidth = 30;
  static const double _teamWidth = 168;
  static const double _statWidth = 32;
  static const double _gdWidth = 38;
  static const double _ptsWidth = 42;

  static double get _rowWidth =>
      _posWidth +
      _teamWidth +
      _statWidth * 6 + // O G B M A Y
      _gdWidth + // AV
      _ptsWidth;

  Widget _cell(
    BuildContext context, {
    required String text,
    required double width,
    bool bold = false,
    Color? color,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = this.table;
    if (table == null || (table.rows.isEmpty && table.sections.isEmpty)) {
      return const EmptyView(
        icon: Icons.table_chart_rounded,
        message: 'Puan tablosu bulunamadı',
      );
    }

    final sections = table.hasSections
        ? table.sections
        : [StandingSection(name: '', rows: table.rows)];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _rowWidth + 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in sections) ...[
                if (section.name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      section.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      _cell(context, text: '#', width: _posWidth),
                      const SizedBox(
                        width: _teamWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Takım',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      _cell(context, text: 'O', width: _statWidth),
                      _cell(context, text: 'G', width: _statWidth),
                      _cell(context, text: 'B', width: _statWidth),
                      _cell(context, text: 'M', width: _statWidth),
                      _cell(context, text: 'A', width: _statWidth),
                      _cell(context, text: 'Y', width: _statWidth),
                      _cell(context, text: 'AV', width: _gdWidth),
                      _cell(context, text: 'P', width: _ptsWidth, bold: true),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final row in section.rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _posWidth,
                          child: Text(
                            '${row.position}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: row.promotionText == null
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: _teamWidth,
                          child: Row(
                            children: [
                              TeamLogo(team: row.team, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      row.team.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    if (row.promotionText != null)
                                      Text(
                                        row.promotionText!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontSize: 10,
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _cell(context, text: '${row.matches}', width: _statWidth),
                        _cell(context, text: '${row.won}', width: _statWidth),
                        _cell(context, text: '${row.drawn}', width: _statWidth),
                        _cell(context, text: '${row.lost}', width: _statWidth),
                        _cell(context, text: '${row.goalsFor}', width: _statWidth),
                        _cell(context, text: '${row.goalsAgainst}',
                            width: _statWidth),
                        _cell(context,
                            text: '${row.goalDifference}', width: _gdWidth),
                        _cell(context,
                            text: '${row.points}', width: _ptsWidth, bold: true),
                      ],
                    ),
                  ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
