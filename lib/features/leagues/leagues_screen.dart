import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../data/models/tournament_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/leagues_controller.dart';
import '../../state/load_state.dart';
import 'league_detail_screen.dart';

class LeaguesScreen extends StatelessWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          TournamentsController(context.read<ScoreRepository>()),
      child: const _LeaguesView(),
    );
  }
}

class _LeaguesView extends StatelessWidget {
  const _LeaguesView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TournamentsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ligler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: controller.state == LoadState.loading
                ? null
                : controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: controller.setQuery,
              decoration: InputDecoration(
                hintText: 'Lig, turnuva veya ülke ara (örn. süperlig)',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ),
          if (controller.isDemo) const DemoBanner(),
          Expanded(child: _buildBody(context, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TournamentsController controller) {
    if (controller.state == LoadState.error) {
      return ErrorView(
        message: controller.errorMessage ?? 'Hata',
        onRetry: controller.load,
      );
    }
    if (controller.state != LoadState.ready) return const LoadingView();

    final items = controller.visible;
    if (items.isEmpty) {
      return const EmptyView(
        icon: Icons.emoji_events_outlined,
        message: 'Sonuç bulunamadı',
      );
    }

    // Kategori başlıkları: milli takımlar, kupalar, ligler.
    const order = ['national', 'cup', 'league', 'other'];
    const labels = {
      'national': 'Milli Takımlar & Turnuvalar',
      'cup': 'Kupalar',
      'league': 'Ligler',
      'other': 'Diğer',
    };

    final grouped = <String, List<Tournament>>{};
    for (final tournament in items) {
      final key = order.contains(tournament.category ?? 'other')
          ? (tournament.category ?? 'other')
          : 'other';
      grouped.putIfAbsent(key, () => []).add(tournament);
    }

    final children = <Widget>[];
    for (final key in order) {
      final list = grouped[key];
      if (list == null || list.isEmpty) continue;

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            labels[key]!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      );
      children.addAll(list.map((tournament) => ListTile(
            leading: _FlagOrInitial(tournament: tournament),
            title: Text(tournament.name),
            subtitle: tournament.countryName == null
                ? null
                : Text(tournament.countryName!),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LeagueDetailScreen(tournament: tournament),
              ),
            ),
          )));
    }
    children.add(const SizedBox(height: 24));

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(children: children),
    );
  }
}

class _FlagOrInitial extends StatelessWidget {
  const _FlagOrInitial({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    // Önce lig logosu, yoksa ülke bayrağı, yoksa baş harf.
    final logo = tournament.logoUrl;
    if (logo != null && logo.isNotEmpty) {
      return NetworkCircleAvatar(url: logo, name: tournament.name, radius: 18);
    }

    final url = tournament.flagUrl;
    if (url == null || url.isEmpty) {
      final label = (tournament.countryName ?? tournament.name);
      return CircleAvatar(
        child: Text(label.isEmpty ? '?' : label[0].toUpperCase()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 36,
        height: 26,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(width: 36, height: 26),
        errorWidget: (_, _, _) =>
            const SizedBox(width: 36, height: 26, child: Icon(Icons.flag_rounded)),
      ),
    );
  }
}
