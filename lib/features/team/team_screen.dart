import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/errors.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../data/models/player_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/load_state.dart';
import '../player/player_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.leagueSlug,
  });

  final int teamId;
  final String teamName;

  /// ESPN kadro sorgusu için lig anahtarı (ör. `eng.1`).
  final String? leagueSlug;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  LoadState _state = LoadState.loading;
  String? _errorMessage;
  List<PlayerSummary> _players = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = LoadState.loading;
      _errorMessage = null;
    });
    try {
      final players = await context
          .read<ScoreRepository>()
          .fetchTeamSquad(widget.teamId, leagueSlug: widget.leagueSlug);
      if (!mounted) return;
      setState(() {
        _players = players;
        _state = LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = humanError(e);
        _state = LoadState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.teamName)),
      body: switch (_state) {
        LoadState.error => ErrorView(
            message: _errorMessage ?? 'Hata',
            onRetry: _load,
          ),
        LoadState.ready => _players.isEmpty
            ? const EmptyView(
                icon: Icons.groups_rounded,
                message: 'Kadro bulunamadı',
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _players.length,
                  separatorBuilder: (_, _) => const Divider(indent: 72),
                  itemBuilder: (context, index) {
                  final player = _players[index];
                  return ListTile(
                    leading: NetworkCircleAvatar(
                      url: player.photoUrl,
                      name: player.name,
                      radius: 18,
                    ),
                    title: Text(player.name),
                    subtitle: Text(
                      [
                        player.positionLabel,
                        if (player.jerseyNumber != null)
                          '#${player.jerseyNumber}',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: player.id > 0
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    playerId: player.id,
                                    initialName: player.name,
                                  ),
                                ),
                              )
                          : null,
                    );
                  },
                ),
              ),
        _ => const LoadingView(),
      },
    );
  }
}
