import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../models/dashboard/dashboard_feed_item.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../explore/repositories/explore_repository.dart';
import '../repositories/dashboard_repository.dart';

class DashboardFeedBody extends StatefulWidget {
  const DashboardFeedBody({
    required this.token,
    required this.repository,
    required this.exploreRepository,
    required this.config,
    required this.tx,
    super.key,
  });

  final String token;
  final DashboardRepository repository;
  final ExploreRepository exploreRepository;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  State<DashboardFeedBody> createState() => _DashboardFeedBodyState();
}

class _DashboardFeedBodyState extends State<DashboardFeedBody> {
  bool _loading = true;
  String? _error;
  List<DashboardFeedItem> _items = const [];
  final Map<String, bool> _starredOverride = {};
  final Set<String> _pendingStars = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.fetchFeed(
        widget.token,
        types: widget.config.types ?? kFeedTypes,
        limit: widget.config.limit ?? 8,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.tx('feed_load_error');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStar(DashboardFeedItem item) async {
    if (!item.canToggleFavorite || _pendingStars.contains(item.key)) return;
    final starred = _starredOverride[item.key] ?? item.starred;
    setState(() => _pendingStars.add(item.key));
    try {
      if (starred) {
        await widget.exploreRepository.unstar(
          widget.token,
          resourceType: item.resourceType,
          resourceId: item.resourceId,
        );
      } else {
        await widget.exploreRepository.star(
          widget.token,
          resourceType: item.resourceType,
          resourceId: item.resourceId,
        );
      }
      if (!mounted) return;
      setState(() => _starredOverride[item.key] = !starred);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.tx('favorite_update_error'))),
      );
    } finally {
      if (mounted) setState(() => _pendingStars.remove(item.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: IAgentsLoadingMark(),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SecondaryButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(widget.tx('feed_retry')),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Text(widget.tx('no_recent_activity'));
    }

    final defaultResourceName = widget.tx('default_resource_name');
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ..._items.map((item) {
          final starred = _starredOverride[item.key] ?? item.starred;
          final pending = _pendingStars.contains(item.key);
          final name = item.name.isEmpty ? defaultResourceName : item.name;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
            ),
            title: Text(name),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResourceTypeBadge(
                  type: item.resourceType,
                  label: feedTypeLabel(item.resourceType, widget.tx),
                ),
                if (item.ownerUsername.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('@${item.ownerUsername}'),
                ],
              ],
            ),
            trailing: pending
                ? const SizedBox.square(
                    dimension: 24,
                    child: IAgentsLoadingMark(),
                  )
                : AppIconButton(
                    icon: Icon(
                      starred ? Icons.star : Icons.star_border,
                      color: starred ? FncColors.materialAmber : null,
                      size: 20,
                    ),
                    tooltip: widget.tx('toggle_favorite'),
                    onPressed: item.canToggleFavorite
                        ? () => _toggleStar(item)
                        : null,
                  ),
          );
        }),
      ],
    );
  }
}
