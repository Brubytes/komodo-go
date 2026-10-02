import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/core/widgets/surfaces/app_card_surface.dart';
import 'package:komodo_go/features/deployments/data/repositories/deployment_repository.dart';
import 'package:komodo_go/features/deployments/presentation/providers/deployments_provider.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/stacks/presentation/providers/stacks_provider.dart';
import 'package:komodo_go/shared/resources/data/update_control_repository.dart';

class AutoUpdateReviewView extends ConsumerStatefulWidget {
  const AutoUpdateReviewView({super.key});

  @override
  ConsumerState<AutoUpdateReviewView> createState() =>
      _AutoUpdateReviewViewState();
}

class _AutoUpdateReviewViewState extends ConsumerState<AutoUpdateReviewView> {
  List<_UpdateCandidate> _candidates = const [];
  final _selected = <String>{};
  var _loading = true;
  var _checking = false;
  var _deploying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCandidates());
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checking || _deploying;
    return Scaffold(
      appBar: const MainAppBar(
        title: 'Auto-update review',
        icon: Icons.system_update_alt,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCandidates,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            AppCardSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review before updating',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(6),
                  const Text(
                    'Check every Stack and Deployment configured for image '
                    'polling. Auto-deploy is suppressed until you review the '
                    'candidates below.',
                  ),
                  const Gap(14),
                  FilledButton.icon(
                    key: const ValueKey('global_check_now'),
                    onPressed: busy ? null : _runGlobalCheck,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_outlined),
                    label: Text(
                      _checking ? 'Checking images…' : 'Check all now',
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            if (_error != null)
              AppCardSurface(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_candidates.isEmpty)
              const EmptyStateView.inline(
                icon: Icons.verified_outlined,
                title: 'Everything is up to date',
                message: 'Run a global check to refresh image status.',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_candidates.length} candidate${_candidates.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            if (_selected.length == _candidates.length) {
                              _selected.clear();
                            } else {
                              _selected
                                ..clear()
                                ..addAll(_candidates.map((item) => item.key));
                            }
                          }),
                    child: Text(
                      _selected.length == _candidates.length
                          ? 'Clear all'
                          : 'Select all',
                    ),
                  ),
                ],
              ),
              const Gap(8),
              for (final candidate in _candidates) ...[
                AppCardSurface(
                  padding: EdgeInsets.zero,
                  child: CheckboxListTile(
                    key: ValueKey('update_candidate_${candidate.key}'),
                    value: _selected.contains(candidate.key),
                    onChanged: busy
                        ? null
                        : (selected) => setState(() {
                            if (selected ?? false) {
                              _selected.add(candidate.key);
                            } else {
                              _selected.remove(candidate.key);
                            }
                          }),
                    secondary: Icon(candidate.icon),
                    title: Text(candidate.name),
                    subtitle: Text(candidate.summary),
                  ),
                ),
                const Gap(10),
              ],
              FilledButton.icon(
                key: const ValueKey('deploy_selected_updates'),
                onPressed: busy || _selected.isEmpty ? null : _deploySelected,
                icon: _deploying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.deployments),
                label: Text(
                  _deploying
                      ? 'Deploying…'
                      : 'Deploy selected (${_selected.length})',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runGlobalCheck() async {
    final repository = ref.read(updateControlRepositoryProvider);
    if (repository == null) {
      setState(() => _error = 'No active Komodo connection.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await repository.checkGlobalCandidates();
    if (!mounted) return;
    final failure = result.fold<Failure?>((value) => value, (_) => null);
    if (failure != null) {
      setState(() {
        _checking = false;
        _error = failure.displayMessage;
      });
      return;
    }
    await _loadCandidates();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _loadCandidates() async {
    final deployments = ref.read(deploymentRepositoryProvider);
    final stacks = ref.read(stackRepositoryProvider);
    if (deployments == null || stacks == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No active Komodo connection.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final deploymentResult = await deployments.listUpdateCandidates();
    final stackResult = await stacks.listUpdateCandidates();
    if (!mounted) return;
    Failure? failure;
    final candidates = <_UpdateCandidate>[];
    deploymentResult.fold(
      (value) => failure = value,
      (items) => candidates.addAll(
        items.map(
          (item) => _UpdateCandidate(
            id: item.id,
            name: item.name,
            kind: _CandidateKind.deployment,
            summary: item.imageLabel.isEmpty
                ? 'Deployment image update available'
                : item.imageLabel,
          ),
        ),
      ),
    );
    stackResult.fold(
      (value) => failure ??= value,
      (items) => candidates.addAll(
        items.map((item) {
          final count = item.info.services
              .where((service) => service.updateAvailable)
              .length;
          return _UpdateCandidate(
            id: item.id,
            name: item.name,
            kind: _CandidateKind.stack,
            summary: '$count service image${count == 1 ? '' : 's'} available',
          );
        }),
      ),
    );
    setState(() {
      _loading = false;
      _error = failure?.displayMessage;
      _candidates = candidates;
      _selected
        ..removeWhere(
          (key) => !candidates.any((candidate) => candidate.key == key),
        )
        ..addAll(candidates.map((candidate) => candidate.key));
    });
  }

  Future<void> _deploySelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deploy selected updates?'),
        content: Text(
          'This will deploy ${_selected.length} selected resource'
          '${_selected.length == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deploy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deployments = ref.read(deploymentRepositoryProvider);
    final stacks = ref.read(stackRepositoryProvider);
    if (deployments == null || stacks == null) return;
    setState(() => _deploying = true);
    var succeeded = 0;
    for (final candidate in _candidates) {
      if (!_selected.contains(candidate.key)) continue;
      final result = candidate.kind == _CandidateKind.stack
          ? await stacks.deployStackIfChanged(candidate.id)
          : await deployments.deploy(candidate.id);
      if (result.isRight()) succeeded++;
    }
    if (!mounted) return;
    ref
      ..invalidate(stacksProvider)
      ..invalidate(deploymentsProvider);
    setState(() => _deploying = false);
    AppSnackBar.show(
      context,
      '$succeeded of ${_selected.length} deployments started.',
      tone: succeeded == _selected.length
          ? AppSnackBarTone.success
          : AppSnackBarTone.warning,
    );
    await _loadCandidates();
  }
}

enum _CandidateKind { stack, deployment }

class _UpdateCandidate {
  const _UpdateCandidate({
    required this.id,
    required this.name,
    required this.kind,
    required this.summary,
  });

  final String id;
  final String name;
  final _CandidateKind kind;
  final String summary;

  String get key => '${kind.name}:$id';
  IconData get icon => switch (kind) {
    _CandidateKind.stack => AppIcons.stacks,
    _CandidateKind.deployment => AppIcons.deployments,
  };
}
