import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../data/models/player_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/detail_controllers.dart';
import '../../state/load_state.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.playerId,
    this.initialName,
    this.provider,
  });

  final int playerId;
  final String? initialName;

  /// Profil kaynağı (arama sonucundan gelir, örn. Maçkolik).
  final String? provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PlayerController(
        context.read<ScoreRepository>(),
        playerId,
        provider: provider,
      ),
      child: _PlayerView(initialName: initialName),
    );
  }
}

class _PlayerView extends StatelessWidget {
  const _PlayerView({this.initialName});

  final String? initialName;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerController>();
    final player = controller.player;

    return Scaffold(
      appBar: AppBar(title: Text(player?.name ?? initialName ?? 'Oyuncu')),
      body: switch (controller.state) {
        LoadState.error => ErrorView(
            message: controller.errorMessage ?? 'Hata',
            onRetry: controller.load,
          ),
        LoadState.ready when player == null => const EmptyView(
            icon: Icons.person_off_rounded,
            message: 'Oyuncu bulunamadı',
          ),
        LoadState.ready => _ProfileView(profile: player!),
        _ => const LoadingView(),
      },
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <MapEntry<String, String>>[
      if (profile.appearances != null || profile.goals != null) ...[
        if (profile.appearances != null)
          MapEntry('Sezon maçı', '${profile.appearances}'),
        if (profile.goals != null) MapEntry('Gol', '${profile.goals}'),
        if (profile.assists != null) MapEntry('Asist', '${profile.assists}'),
        if (profile.shots != null) MapEntry('Şut', '${profile.shots}'),
      ],
      if (profile.countryName != null)
        MapEntry('Ülke', profile.countryName!),
      if (profile.age != null) MapEntry('Yaş', '${profile.age}'),
      if (profile.birthDate != null)
        MapEntry(
          'Doğum tarihi',
          DateFormat('dd.MM.y').format(profile.birthDate!),
        ),
      if (profile.birthPlace != null)
        MapEntry('Doğum yeri', profile.birthPlace!),
      if (profile.height != null) MapEntry('Boy', '${profile.height} cm'),
      if (profile.weight != null) MapEntry('Kilo', '${profile.weight} kg'),
      if (profile.position != null)
        MapEntry('Mevki', profile.positionLabel),
      if (profile.jerseyNumber != null)
        MapEntry('Forma no', '${profile.jerseyNumber}'),
      if (profile.preferredFoot != null)
        MapEntry('Ay tercihi', profile.preferredFoot!),
      if (profile.contractUntil != null)
        MapEntry('Kontrat sonu', profile.contractUntil!),
      if (profile.marketValue != null)
        MapEntry('Piyasa değeri', profile.marketValue!),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                NetworkCircleAvatar(
                  url: profile.photoUrl,
                  name: profile.name,
                  radius: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (profile.teamName != null) profile.teamName!,
                    if (profile.countryName != null) profile.countryName!,
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final entry in entries)
                  ListTile(
                    dense: true,
                    title: Text(entry.key),
                    trailing: Text(
                      entry.value,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
