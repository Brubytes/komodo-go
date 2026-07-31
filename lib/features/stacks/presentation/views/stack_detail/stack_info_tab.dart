import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/syntax_highlight/app_syntax_highlight.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/empty_state_view.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

class StackInfoTabContent extends StatefulWidget {
  const StackInfoTabContent({
    required this.info,
    required this.onSaveFile,
    this.onDirtyChanged,
    super.key,
  });

  final StackInfo info;
  final Future<bool> Function(String path, String contents, {bool showSnackBar})
  onSaveFile;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<StackInfoTabContent> createState() => StackInfoTabContentState();
}

class StackInfoTabContentState extends State<StackInfoTabContent> {
  final Map<String, CodeEditorController> _controllers = {};
  final Map<String, String> _initialContents = {};
  final Set<String> _savingPaths = {};
  final Set<String> _dirtyPaths = {};

  var _files = <StackRemoteFileContents>[];
  var _lastDirty = false;

  bool get isDirty => _dirtyPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _syncFiles(widget.info.remoteContents ?? const []);
  }

  @override
  void didUpdateWidget(covariant StackInfoTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info.remoteContents != oldWidget.info.remoteContents) {
      _syncFiles(widget.info.remoteContents ?? const []);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initialContents.clear();
    _savingPaths.clear();
    _dirtyPaths.clear();
    super.dispose();
  }

  void _syncFiles(List<StackRemoteFileContents> files) {
    final nextPaths = {for (final f in files) f.path};

    final removed = _controllers.keys
        .where((p) => !nextPaths.contains(p))
        .toList();
    for (final path in removed) {
      _controllers.remove(path)?.dispose();
      _initialContents.remove(path);
      _savingPaths.remove(path);
      _dirtyPaths.remove(path);
    }

    for (final file in files) {
      final path = file.path;
      final controller = _controllers[path];
      if (controller == null) {
        _registerController(path, _createCodeController(text: file.contents));
        continue;
      }

      final initial = _initialContents[path] ?? '';
      final isDirty = controller.text != initial;
      if (!isDirty && controller.text != file.contents) {
        controller.text = file.contents;
      }
      _initialContents[path] = file.contents;
    }

    if (!mounted) {
      _files = files;
      _notifyDirtyChanged();
      return;
    }
    setState(() => _files = files);
    _notifyDirtyChanged();
  }

  CodeEditorController _createCodeController({required String text}) {
    return CodeEditorController(
      text: text,
      lightHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.lightTheme,
      ),
      darkHighlighter: Highlighter(
        language: 'yaml',
        theme: AppSyntaxHighlight.darkTheme,
      ),
    );
  }

  void _registerController(String path, CodeEditorController controller) {
    _controllers[path] = controller;
    _initialContents[path] = controller.text;
    controller.addListener(() => _handleControllerChanged(path));
  }

  void _handleControllerChanged(String path) {
    _updateDirtyForPath(path);
    if (!mounted) return;
    setState(() {});
  }

  void _updateDirtyForPath(String path) {
    final controller = _controllers[path];
    if (controller == null) return;
    if (controller.text != (_initialContents[path] ?? '')) {
      _dirtyPaths.add(path);
    } else {
      _dirtyPaths.remove(path);
    }
    _notifyDirtyChanged();
  }

  void _notifyDirtyChanged() {
    final isDirty = _dirtyPaths.isNotEmpty;
    if (isDirty == _lastDirty) return;
    _lastDirty = isDirty;
    widget.onDirtyChanged?.call(isDirty);
  }

  CodeEditorController _controllerForFile(StackRemoteFileContents file) {
    final existing = _controllers[file.path];
    if (existing != null) return existing;
    final controller = _createCodeController(text: file.contents);
    _registerController(file.path, controller);
    return controller;
  }

  String _requiresLabel(StackFileRequires value) {
    return switch (value) {
      StackFileRequires.none => 'None',
      StackFileRequires.restart => 'Restart',
      StackFileRequires.redeploy => 'Redeploy',
    };
  }

  Future<bool> saveAll() async {
    final dirtyPaths = _dirtyPaths.toList();
    if (dirtyPaths.isEmpty) return true;

    var allSuccess = true;
    for (final path in dirtyPaths) {
      final controller = _controllers[path];
      if (controller == null) continue;
      if (!mounted) break;
      setState(() => _savingPaths.add(path));
      final success = await widget.onSaveFile(
        path,
        controller.text,
        showSnackBar: false,
      );
      if (!mounted) break;
      setState(() => _savingPaths.remove(path));
      if (success) {
        _initialContents[path] = controller.text;
        _dirtyPaths.remove(path);
      } else {
        allSuccess = false;
      }
    }
    _notifyDirtyChanged();
    return allSuccess;
  }

  void resetAll() {
    for (final entry in _controllers.entries) {
      entry.value.text = _initialContents[entry.key] ?? '';
    }
    _dirtyPaths.clear();
    _notifyDirtyChanged();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final deployedConfig = widget.info.deployedConfig?.trim() ?? '';
    final hasFiles = _files.isNotEmpty;
    final hasDeployedConfig = deployedConfig.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasFiles)
          const EmptyStateView(
            icon: AppIcons.package,
            title: 'No file contents',
            message: 'Stack file contents will appear here once configured.',
          )
        else
          Column(
            children: [
              for (final file in _files) ...[
                DetailSubCard(
                  title: file.path.trim().isNotEmpty
                      ? file.path.trim()
                      : 'Stack file',
                  icon: AppIcons.package,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (file.services.isNotEmpty ||
                          file.requires != StackFileRequires.none) ...[
                        if (file.services.isNotEmpty)
                          DetailKeyValueRow(
                            label: 'Services',
                            value: file.services.join(', '),
                          ),
                        if (file.requires != StackFileRequires.none)
                          DetailKeyValueRow(
                            label: 'Requires',
                            value: _requiresLabel(file.requires),
                            bottomPadding: 0,
                          ),
                        const Gap(12),
                      ],
                      DetailCodeEditor(
                        controller: _controllerForFile(file),
                        fullscreenTitle: file.path.trim().isNotEmpty
                            ? file.path.trim()
                            : '',
                      ),
                    ],
                  ),
                ),
                const Gap(12),
              ],
            ],
          ),
        if (hasFiles || hasDeployedConfig) ...[
          const Gap(12),
          DetailSubCard(
            title: 'Deployed config',
            icon: AppIcons.stacks,
            child: hasDeployedConfig
                ? DetailCodeBlock(
                    code: deployedConfig,
                    language: DetailCodeLanguage.yaml,
                  )
                : Text(
                    'No deployed config yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
