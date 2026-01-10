import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/router/app_router.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_snack_bar.dart';
import 'package:komodo_go/core/widgets/main_app_bar.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/widgets/procedure_card.dart';

class ProceduresListContent extends ConsumerWidget {
  const ProceduresListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proceduresAsync = ref.watch(proceduresProvider);
    final actionsState = ref.watch(procedureActionsProvider);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(proceduresProvider.notifier).refresh(),
          child: proceduresAsync.when(
            data: (procedures) {
              if (procedures.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: procedures.length,
                separatorBuilder: (context, index) => const Gap(12),
                itemBuilder: (context, index) {
                  final procedure = procedures[index];
                  return ProcedureCard(
                    procedure: procedure,
                    onTap: () => context.push(
                      '${AppRoutes.procedures}/${procedure.id}?name=${Uri.encodeComponent(procedure.name)}',
                    ),
                    onRun: () => _runProcedure(context, ref, procedure.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _ErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(proceduresProvider),
            ),
          ),
        ),
        if (actionsState.isLoading)
          const ColoredBox(
            color: Colors.black26,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _runProcedure(
    BuildContext context,
    WidgetRef ref,
    String procedureId,
  ) async {
    final actions = ref.read(procedureActionsProvider.notifier);
    final success = await actions.run(procedureId);

    if (context.mounted) {
      AppSnackBar.show(
        context,
        success ? 'Procedure started' : 'Action failed. Please try again.',
        tone: success ? AppSnackBarTone.success : AppSnackBarTone.error,
      );
    }
  }
}

/// View displaying the list of all procedures.
class ProceduresListView extends StatelessWidget {
  const ProceduresListView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MainAppBar(
        title: 'Procedures',
        icon: AppIcons.procedures,
        markColor: AppTokens.resourceProcedures,
        markUseGradient: true,
        centerTitle: true,
      ),
      body: ProceduresListContent(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.procedures,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No procedures found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          Text(
            'Create procedures in the Komodo web interface',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.formError,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const Gap(16),
            Text(
              'Failed to load procedures',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
