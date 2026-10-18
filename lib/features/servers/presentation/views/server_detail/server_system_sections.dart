import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/ui/app_motion.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/features/servers/data/models/system_information.dart';
import 'package:komodo_go/features/servers/data/models/system_stats.dart';

class ServerSystemInfoContent extends StatelessWidget {
  const ServerSystemInfoContent({required this.info, super.key});

  final SystemInformation info;

  @override
  Widget build(BuildContext context) {
    final isLockedDown = info.terminalsDisabled || info.containerExecDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSubCard(
          title: 'Basics',
          icon: AppIcons.server,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.name?.isNotEmpty ?? false)
                ValuePill(label: 'Name', value: info.name!),
              if (info.hostName?.isNotEmpty ?? false)
                ValuePill(label: 'Host', value: info.hostName!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'OS',
          icon: AppIcons.settings,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.os?.isNotEmpty ?? false)
                ValuePill(label: 'OS', value: info.os!),
              if (info.kernel?.isNotEmpty ?? false)
                ValuePill(label: 'Kernel', value: info.kernel!),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Hardware',
          icon: AppIcons.cpu,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.cpuBrand.isNotEmpty)
                ValuePill(label: 'CPU', value: info.cpuBrand),
              if (info.coreCount != null)
                ValuePill(label: 'Cores', value: info.coreCount.toString()),
            ],
          ),
        ),
        const Gap(12),
        DetailSubCard(
          title: 'Access',
          icon: AppIcons.lock,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill.onOff(
                isOn: !info.terminalsDisabled,
                onLabel: 'Terminal enabled',
                offLabel: 'Terminal disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill.onOff(
                isOn: !info.containerExecDisabled,
                onLabel: 'Exec enabled',
                offLabel: 'Exec disabled',
                onIcon: AppIcons.ok,
                offIcon: AppIcons.warning,
                offTone: PillTone.warning,
              ),
              StatusPill(
                label: isLockedDown ? 'Locked down' : 'Operational',
                icon: isLockedDown ? AppIcons.warning : AppIcons.ok,
                tone: isLockedDown ? PillTone.warning : PillTone.success,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ProcessSort { cpu, memory, read, write }

class SystemProcessesContent extends StatefulWidget {
  const SystemProcessesContent({required this.processes, super.key});

  final List<SystemProcess> processes;

  @override
  State<SystemProcessesContent> createState() => _SystemProcessesContentState();
}

class _SystemProcessesContentState extends State<SystemProcessesContent> {
  _ProcessSort _sort = _ProcessSort.cpu;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final processes = [...widget.processes]
      ..sort((a, b) => _sortValue(b).compareTo(_sortValue(a)));

    return DetailSubCard(
      title: 'Processes (${processes.length})',
      icon: AppIcons.activity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SegmentedButton<_ProcessSort>(
              segments: const [
                ButtonSegment(value: _ProcessSort.cpu, label: Text('CPU')),
                ButtonSegment(value: _ProcessSort.memory, label: Text('Mem')),
                ButtonSegment(value: _ProcessSort.read, label: Text('Read')),
                ButtonSegment(value: _ProcessSort.write, label: Text('Write')),
              ],
              selected: {_sort},
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              onSelectionChanged: (value) =>
                  setState(() => _sort = value.first),
            ),
          ),
          const Gap(10),
          if (processes.isEmpty)
            Text('No process data available.', style: textTheme.bodyMedium)
          else
            for (final process in processes.take(50))
              ExpansionTile(
                expansionAnimationStyle: AppMotion.expansionStyle(context),
                key: PageStorageKey<String>(
                  'server_process_${process.pid}',
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 10),
                title: Text(
                  process.name.isEmpty ? 'PID ${process.pid}' : process.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'PID ${process.pid}  •  ${process.cpuPercent.toStringAsFixed(1)}%  •  ${process.memoryMb.toStringAsFixed(0)} MB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  DetailKeyValueRow(
                    label: 'Executable',
                    value: process.executable.isEmpty
                        ? '—'
                        : process.executable,
                  ),
                  DetailKeyValueRow(
                    label: 'Command',
                    value: process.command.isEmpty
                        ? '—'
                        : process.command.join(' '),
                  ),
                  DetailKeyValueRow(
                    label: 'Disk read / write',
                    value:
                        '${process.diskReadKb.toStringAsFixed(0)} / ${process.diskWriteKb.toStringAsFixed(0)} KB',
                    bottomPadding: 0,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  double _sortValue(SystemProcess process) => switch (_sort) {
    _ProcessSort.cpu => process.cpuPercent,
    _ProcessSort.memory => process.memoryMb,
    _ProcessSort.read => process.diskReadKb,
    _ProcessSort.write => process.diskWriteKb,
  };
}
