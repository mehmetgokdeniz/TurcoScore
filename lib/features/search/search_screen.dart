import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/async_views.dart';
import '../../core/widgets/network_circle_avatar.dart';
import '../../data/models/player_models.dart';
import '../../data/models/tournament_models.dart';
import '../../data/repositories/score_repository.dart';
import '../../state/load_state.dart';
import '../../state/search_controller.dart';
import '../leagues/league_detail_screen.dart';
import '../player/player_screen.dart';
import '../team/team_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppSearchController(context.read<ScoreRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _open(BuildContext context, SearchItem item) {
    switch (item.kind) {
      case SearchKind.player:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              playerId: item.id,
              initialName: item.name,
              provider: item.sourceKey,
            ),
          ),
        );
      case SearchKind.tournament:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeagueDetailScreen(
              tournament: Tournament(
                id: item.id,
                name: item.name,
                countryName: item.subtitle,
              ),
            ),
          ),
        );
      case SearchKind.team:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TeamScreen(
              teamId: item.id,
              teamName: item.name,
              leagueSlug: item.sourceKey,
            ),
          ),
        );
      case SearchKind.unknown:
        break;
    }
  }

  IconData _iconFor(SearchKind kind) => switch (kind) {
        SearchKind.player => Icons.person_rounded,
        SearchKind.tournament => Icons.emoji_events_rounded,
        SearchKind.team => Icons.groups_rounded,
        SearchKind.unknown => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppSearchController>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          onChanged: controller.onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Oyuncu, takım, lig ara',
            border: InputBorder.none,
            suffixIcon: _textController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _textController.clear();
                      controller.onQueryChanged('');
                      setState(() {});
                    },
                  ),
          ),
        ),
      ),
      body: _buildBody(context, controller),
    );
  }

  Widget _buildBody(BuildContext context, AppSearchController controller) {
    if (controller.state == LoadState.error) {
      return ErrorView(
        message: controller.errorMessage ?? 'Hata',
        onRetry: () => controller.onQueryChanged(controller.query),
      );
    }
    if (controller.query.trim().isEmpty) {
      return const EmptyView(
        icon: Icons.search_rounded,
        message: 'Aramak için oyuncu, takım veya lig adı yazın',
      );
    }
    if (controller.state == LoadState.loading) return const LoadingView();
    if (controller.results.isEmpty) {
      return const EmptyView(
        icon: Icons.person_off_rounded,
        message: 'Sonuç bulunamadı',
      );
    }

    return ListView.separated(
      itemCount: controller.results.length,
      separatorBuilder: (_, _) => const Divider(indent: 64),
      itemBuilder: (context, index) {
        final item = controller.results[index];
        return ListTile(
          leading: item.logoUrl == null
              ? Icon(_iconFor(item.kind))
              : NetworkCircleAvatar(
                  url: item.logoUrl,
                  name: item.name,
                  radius: 18,
                ),
          title: Text(item.name),
          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _open(context, item),
        );
      },
    );
  }
}
