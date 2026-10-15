import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../data/favorites/favorite_store.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/team_logo.dart';
import '../../data/models/match_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/load_state.dart';
import '../../state/matches_controller.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          MatchesController(context.read<ScoreRepository>()),
      child: const _MatchesView(),
    );
  }
}

class _MatchesView extends StatelessWidget {
  const _MatchesView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MatchesController>();
    final favorites = context.watch<FavoriteStore>().favorites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TurcoScore'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: controller.state == LoadState.loading || controller.showFavorites
                ? null
                : controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateStrip(controller: controller),
          if (controller.isDemo && !controller.showFavorites) const DemoBanner(),
          const Divider(),
          Expanded(child: _buildBody(context, controller, favorites)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MatchesController controller,
    List<FavoriteMatch> favorites,
  ) {
    if (controller.showFavorites) {
      final events = [for (final f in favorites) f.toEvent()];
      if (events.isEmpty) {
        return const EmptyView(
          icon: Icons.favorite_border,
          message: 'Henüz favori maç yok.\nMaçın yanındaki kalbe dokunun.',
        );
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: _MatchList(events: events),
      );
    }

    if (controller.state == LoadState.error) {
      return ErrorView(message: controller.errorMessage ?? 'Hata', onRetry: controller.load);
    }
    if (controller.state != LoadState.ready) return const LoadingView();
    if (controller.events.isEmpty) {
      return EmptyView(
        icon: Icons.event_busy_rounded,
        message: controller.showLive
            ? 'Şu anda canlı maç yok'
            : 'Bu tarihte maç bulunamadı',
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: _MatchList(events: controller.events),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.controller});

  final MatchesController controller;

  static final _dayMonth = DateFormat.d('tr_TR');

  String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(day.year, day.month, day.day).difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    if (diff == -1) return 'Dün';
    return '${_dayMonth.format(day)} ${DateFormat.MMM('tr_TR').format(day)}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = -3; i <= 3; i++) today.add(Duration(days: i))];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            selected: controller.showLive,
            onSelected: (_) => controller.selectLive(),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Colors.red),
                SizedBox(width: 6),
                Text('Canlı'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: controller.showFavorites,
            onSelected: (_) => controller.toggleFavorites(),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                SizedBox(width: 6),
                Text('Favoriler'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final day in days) ...[
            ChoiceChip(
              selected: !controller.showLive &&
                  controller.date.year == day.year &&
                  controller.date.month == day.month &&
                  controller.date.day == day.day,
              onSelected: (_) => controller.selectDate(day),
              label: Text(_label(day)),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Tarih'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: controller.date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) controller.selectDate(picked);
            },
          ),
        ],
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({required this.events});

  final List<MatchEvent> events;

  @override
  Widget build(BuildContext context) {
    final groups = groupByTournament(events);
    final titleByKey = {
      for (final event in events) event.tournamentKey: event.headerTitle,
    };
    final logoByKey = {
      for (final event in events)
        if (event.tournamentLogoUrl != null)
          event.tournamentKey: event.tournamentLogoUrl!,
    };

    final children = <Widget>[];
    for (final entry in groups.entries) {
      final logo = logoByKey[entry.key];
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              if (logo != null) ...[
                NetworkCircleAvatar(url: logo, name: titleByKey[entry.key] ?? '', radius: 10),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  titleByKey[entry.key] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
      children.addAll(entry.value.map((e) => MatchTile(event: e)));
    }
    children.add(const SizedBox(height: 24));

    return ListView(children: children);
  }
}

class MatchTile extends StatelessWidget {
  const MatchTile({super.key, required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasScore = event.homeScore != null && event.awayScore != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailScreen(preview: event)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  event.home.name,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              TeamLogo(team: event.home, size: 28),
              SizedBox(
                width: 76,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasScore)
                      Text(
                        '${event.homeScore} - ${event.awayScore}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text(
                        DateFormat('HH:mm').format(event.kickoff),
                        style: theme.textTheme.titleSmall,
                      ),
                    const SizedBox(height: 2),
                    StatusBadge(event: event),
                  ],
                ),
              ),
              TeamLogo(team: event.away, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.away.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              _FavoriteButton(event: event),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maç yanındaki kalp: favorilere ekle/çıkar.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FavoriteStore>();
    final isFavorite = store.isFavorite(event.id);
    return IconButton(
      tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
      visualDensity: VisualDensity.compact,
      onPressed: () => store.toggle(event),
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.redAccent : null,
        size: 22,
      ),
    );
  }
}
