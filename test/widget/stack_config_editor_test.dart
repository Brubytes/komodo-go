import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/stacks/stack_config_editor.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/features/providers/data/models/docker_registry_account.dart';
import 'package:komodo_go/features/repos/data/models/repo.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

void main() {
  setUpAll(AppSyntaxHighlight.ensureInitialized);

  for (final missing in [false, true]) {
    testWidgets(
      'missing selection warnings require a stored value ($missing)',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StackConfigEditorContent(
                  stackIdOrName: 'qa',
                  initialConfig: StackConfig(
                    serverId: missing ? 'missing' : '',
                    registryAccount: missing ? 'missing' : '',
                    linkedRepo: missing ? 'missing' : '',
                    repo: 'owner/repo',
                  ),
                  servers: const [Server(id: 'server', name: 'Local')],
                  repos: const [
                    RepoListItem(
                      id: 'repo',
                      name: 'Repo',
                      info: RepoListItemInfo(),
                    ),
                  ],
                  registryAccounts: const [
                    DockerRegistryAccount(
                      id: 'registry',
                      domain: 'docker.io',
                      username: 'qa',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final warnings = find.textContaining('Current value not found');
        expect(warnings, missing ? findsNWidgets(2) : findsNothing);
        expect(
          find.text('Current registry account is not in the account list.'),
          missing ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
