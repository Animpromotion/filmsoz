import 'dart:async';

import 'package:flutter/material.dart';
import 'package:filmsoz_studio/features/screenplay/document/film_document.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning_file_service.dart';
import 'package:filmsoz_studio/features/screenplay/versioning/project_versioning_service.dart';

Future<void> showProjectVersioningDialog({
  required BuildContext context,
  required ScreenplayEditorController controller,
  ProjectVersioningFileService fileService =
      const ProjectVersioningFileService(),
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ProjectVersioningDialog(
      controller: controller,
      fileService: fileService,
    ),
  );
}

class ProjectVersioningDialog extends StatefulWidget {
  const ProjectVersioningDialog({
    super.key,
    required this.controller,
    required this.fileService,
  });

  final ScreenplayEditorController controller;
  final ProjectVersioningFileService fileService;

  @override
  State<ProjectVersioningDialog> createState() =>
      _ProjectVersioningDialogState();
}

class _ProjectVersioningDialogState extends State<ProjectVersioningDialog>
    with SingleTickerProviderStateMixin {
  final ProjectVersioningService _service = const ProjectVersioningService();

  late final TabController _tabController;
  List<AutomaticBackupEntry> _backups = const <AutomaticBackupEntry>[];
  bool _loadingBackups = false;
  CollaborationCommentStatus? _commentStatus;
  String? _commentMemberId;
  bool _overdueOnly = false;
  String? _exportMemberId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    unawaited(_loadBackups());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    if (!mounted) {
      return;
    }

    setState(() => _loadingBackups = true);

    try {
      final backups = await widget.fileService.listAutomaticBackups(
        projectName: widget.controller.projectName,
      );

      if (mounted) {
        setState(() => _backups = backups);
      }
    } catch (error) {
      _showMessage('Не удалось прочитать резервные копии: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingBackups = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF242428),
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 1180,
        height: 760,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Material(
              color: const Color(0xFF2D2D31),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const <Widget>[
                  Tab(icon: Icon(Icons.history), text: 'Версии'),
                  Tab(icon: Icon(Icons.groups_outlined), text: 'Команда'),
                  Tab(icon: Icon(Icons.comment_outlined), text: 'Комментарии'),
                  Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Журнал'),
                  Tab(icon: Icon(Icons.sync_alt), text: 'Обмен'),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _buildVersionsTab(),
                      _buildTeamTab(),
                      _buildCommentsTab(),
                      _buildChangeLogTab(),
                      _buildExchangeTab(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF202023),
        border: Border(
          bottom: BorderSide(color: Color(0xFF3C3C42)),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.history_toggle_off, color: Color(0xFFE5A93C)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Версии, резервные копии и командная работа',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            widget.controller.projectName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFAAAAAF)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionsTab() {
    final document = widget.controller.document;
    final settings = document.versioningSettings;
    final checkpoints = document.projectCheckpoints.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCard(
                  icon: Icons.bookmark_added_outlined,
                  title: 'Контрольные версии',
                  value: '${document.projectCheckpoints.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.backup_outlined,
                  title: 'Автокопии',
                  value: '${_backups.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.schedule,
                  title: 'Интервал',
                  value: '${settings.autoBackupMinutes} мин.',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _createCheckpoint,
                icon: const Icon(Icons.add),
                label: const Text('Новая версия'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget.controller.isCreatingAutomaticBackup
                    ? null
                    : _createAutomaticBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Создать копию'),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Настройки автокопий',
                onPressed: _editBackupSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Panel(
                    title: 'Контрольные версии проекта',
                    trailing: checkpoints.length >= 2
                        ? TextButton.icon(
                            onPressed: _compareCheckpoints,
                            icon: const Icon(Icons.compare_arrows, size: 18),
                            label: const Text('Сравнить'),
                          )
                        : null,
                    child: checkpoints.isEmpty
                        ? const _EmptyState(
                            icon: Icons.bookmark_border,
                            text:
                                'Создай контрольную версию перед крупными правками.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: checkpoints.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final checkpoint = checkpoints[index];
                              final author = checkpoint.authorId == null
                                  ? null
                                  : document.projectMemberById(
                                      checkpoint.authorId!,
                                    );
                              return ListTile(
                                leading: const Icon(
                                  Icons.bookmark,
                                  color: Color(0xFFE5A93C),
                                ),
                                title: Text(checkpoint.name),
                                subtitle: Text(
                                  <String>[
                                    _formatDateTime(checkpoint.createdAt),
                                    if (author != null) author.name,
                                    if (checkpoint.note.trim().isNotEmpty)
                                      checkpoint.note.trim(),
                                  ].join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Wrap(
                                  spacing: 2,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'Восстановить',
                                      onPressed: () =>
                                          _restoreCheckpoint(checkpoint),
                                      icon: const Icon(Icons.restore),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      onPressed: () =>
                                          _deleteCheckpoint(checkpoint),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Panel(
                    title: 'Автоматические резервные копии',
                    trailing: IconButton(
                      tooltip: 'Обновить',
                      onPressed: _loadingBackups ? null : _loadBackups,
                      icon: _loadingBackups
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                    child: _backups.isEmpty
                        ? const _EmptyState(
                            icon: Icons.cloud_done_outlined,
                            text: 'Автокопии появятся после изменений проекта.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _backups.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final backup = _backups[index];
                              return ListTile(
                                leading: const Icon(Icons.backup_outlined),
                                title: Text(
                                  _formatDate(backup.createdAt),
                                ),
                                subtitle: Text(
                                  '${_formatSize(backup.sizeBytes)} • ${backup.fileName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Wrap(
                                  spacing: 2,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'Восстановить',
                                      onPressed: () => _restoreBackup(backup),
                                      icon: const Icon(Icons.restore),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      onPressed: () => _deleteBackup(backup),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    final members = widget.controller.document.projectMembers;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _Panel(
        title: 'Участники проекта',
        trailing: FilledButton.icon(
          onPressed: () => _editMember(),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Добавить'),
        ),
        child: members.isEmpty
            ? const _EmptyState(
                icon: Icons.groups_outlined,
                text:
                    'Добавь сценариста, режиссёра, продюсера и других участников.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 170,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final openComments =
                      widget.controller.document.collaborationComments
                          .where(
                            (comment) =>
                                comment.assigneeId == member.id &&
                                !comment.isResolved,
                          )
                          .length;
                  return Card(
                    color: const Color(0xFF2C2C31),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              CircleAvatar(
                                child: Text(
                                  member.name.trim().isEmpty
                                      ? '?'
                                      : member.name.trim()[0].toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      member.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      member.role.trim().isEmpty
                                          ? 'Роль не указана'
                                          : member.role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFAAAAAF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                member.isActive
                                    ? Icons.check_circle
                                    : Icons.pause_circle_outline,
                                color: member.isActive
                                    ? const Color(0xFF68B984)
                                    : const Color(0xFF88888D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            member.email.trim().isEmpty
                                ? 'Почта не указана'
                                : member.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: <Widget>[
                              Chip(
                                label: Text('Открыто: $openComments'),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () => _editMember(member),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: () => _deleteMember(member),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCommentsTab() {
    final document = widget.controller.document;
    final comments = _service.filterComments(
      document,
      status: _commentStatus,
      memberId: _commentMemberId,
      overdueOnly: _overdueOnly,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<CollaborationCommentStatus?>(
                  initialValue: _commentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Статус',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<CollaborationCommentStatus?>>[
                    const DropdownMenuItem<CollaborationCommentStatus?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...CollaborationCommentStatus.values.map(
                      (status) => DropdownMenuItem<CollaborationCommentStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _commentStatus = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _commentMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Участник',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все участники'),
                    ),
                    ...document.projectMembers.map(
                      (member) => DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _commentMemberId = value),
                ),
              ),
              const SizedBox(width: 10),
              FilterChip(
                selected: _overdueOnly,
                label: const Text('Просроченные'),
                avatar: const Icon(Icons.warning_amber, size: 18),
                onSelected: (value) => setState(() => _overdueOnly = value),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _editComment(),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Комментарий'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _Panel(
              title: 'Комментарии и задачи (${comments.length})',
              child: comments.isEmpty
                  ? const _EmptyState(
                      icon: Icons.mark_chat_read_outlined,
                      text: 'По выбранным фильтрам комментариев нет.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final author = comment.authorId == null
                            ? null
                            : document.projectMemberById(comment.authorId!);
                        final assignee = comment.assigneeId == null
                            ? null
                            : document.projectMemberById(comment.assigneeId!);
                        final overdue = comment.isOverdue();
                        return ListTile(
                          leading: Icon(
                            comment.isResolved
                                ? Icons.check_circle
                                : overdue
                                    ? Icons.warning_amber
                                    : Icons.chat_bubble_outline,
                            color: comment.isResolved
                                ? const Color(0xFF68B984)
                                : overdue
                                    ? const Color(0xFFE57373)
                                    : const Color(0xFFE5A93C),
                          ),
                          title: Text(
                            comment.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            <String>[
                              comment.status.label,
                              _service.targetLabel(document, comment),
                              if (author != null) 'Автор: ${author.name}',
                              if (assignee != null)
                                'Ответственный: ${assignee.name}',
                              if (comment.dueDate.trim().isNotEmpty)
                                'Срок: ${comment.dueDate}',
                            ].join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: <Widget>[
                              if (!comment.isResolved)
                                IconButton(
                                  tooltip: 'Отметить решённым',
                                  onPressed: () {
                                    widget.controller
                                        .upsertCollaborationComment(
                                      comment.copyWith(
                                        status:
                                            CollaborationCommentStatus.resolved,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.task_alt),
                                ),
                              IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () => _editComment(comment),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Удалить',
                                onPressed: () => _deleteComment(comment),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeLogTab() {
    final document = widget.controller.document;
    final entries = document.projectChangeLog.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _Panel(
        title: 'Журнал изменений (${entries.length})',
        child: entries.isEmpty
            ? const _EmptyState(
                icon: Icons.receipt_long_outlined,
                text: 'Изменения версий и командной работы появятся здесь.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final actor = entry.actorId == null
                      ? null
                      : document.projectMemberById(entry.actorId!);
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(entry.summary),
                    subtitle: Text(
                      <String>[
                        _formatDateTime(entry.createdAt),
                        if (actor != null) actor.name,
                        if (entry.details.trim().isNotEmpty) entry.details,
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildExchangeTab() {
    final document = widget.controller.document;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 230,
            child: _Panel(
              title: 'Командный пакет Filmsoz',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Пакет содержит сценарий, производственные данные, версии, '
                      'комментарии и участников. Перед импортом Filmsoz сравнивает '
                      'отпечаток исходной версии и предупреждает о конфликте.',
                      style: TextStyle(color: Color(0xFFB8B8BD)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _exportMemberId,
                            decoration: const InputDecoration(
                              labelText: 'Пакет для участника',
                            ),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Без конкретного получателя'),
                              ),
                              ...document.projectMembers.map(
                                (member) => DropdownMenuItem<String?>(
                                  value: member.id,
                                  child: Text(
                                    member.role.trim().isEmpty
                                        ? member.name
                                        : '${member.name} — ${member.role}',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _exportMemberId = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _exportTeamPackage,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Экспортировать пакет'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _importTeamPackage,
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: const Text('Импортировать обновление'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: const <Widget>[
                Expanded(
                  child: _InfoCard(
                    icon: Icons.security_update_good,
                    title: 'Защита от перезаписи',
                    text: 'Перед заменой текущего проекта создаётся резервная '
                        'копия. При несовпадении исходного отпечатка показывается '
                        'предупреждение о конфликте.',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.people_alt_outlined,
                    title: 'Работа без сервера',
                    text: 'Передавай файл .filmsozpack через почту, облако или '
                        'мессенджер. Это локальный обмен версиями, а не одновременное '
                        'редактирование в реальном времени.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCheckpoint() async {
    final nameController = TextEditingController(
      text:
          'Версия ${widget.controller.document.projectCheckpoints.length + 1}',
    );
    final noteController = TextEditingController();
    String? authorId;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новая контрольная версия'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий к изменениям',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: authorId,
                  decoration: const InputDecoration(labelText: 'Автор'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Не указан'),
                    ),
                    ...widget.controller.document.projectMembers.map(
                      (member) => DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => authorId = value),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      widget.controller.createProjectCheckpoint(
        name: nameController.text,
        note: noteController.text,
        authorId: authorId,
      );
      _showMessage('Контрольная версия создана.');
    }

    nameController.dispose();
    noteController.dispose();
  }

  Future<void> _restoreCheckpoint(ProjectCheckpoint checkpoint) async {
    final confirmed = await _confirm(
      title: 'Восстановить версию?',
      message: 'Текущее состояние можно будет вернуть через Ctrl+Z. '
          'Будет восстановлена версия «${checkpoint.name}».',
      confirmLabel: 'Восстановить',
    );

    if (confirmed &&
        widget.controller.restoreProjectCheckpoint(checkpoint.id)) {
      _showMessage('Версия «${checkpoint.name}» восстановлена.');
    }
  }

  Future<void> _deleteCheckpoint(ProjectCheckpoint checkpoint) async {
    final confirmed = await _confirm(
      title: 'Удалить контрольную версию?',
      message: 'Версия «${checkpoint.name}» будет удалена из проекта.',
      confirmLabel: 'Удалить',
      destructive: true,
    );

    if (confirmed) {
      widget.controller.deleteProjectCheckpoint(checkpoint.id);
    }
  }

  Future<void> _compareCheckpoints() async {
    final checkpoints = widget.controller.document.projectCheckpoints;

    if (checkpoints.length < 2) {
      return;
    }

    String firstId = checkpoints[checkpoints.length - 2].id;
    String secondId = checkpoints.last.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final first = checkpoints.firstWhere((item) => item.id == firstId);
          final second = checkpoints.firstWhere((item) => item.id == secondId);
          final comparison = _service.compareCheckpoints(first, second);

          return AlertDialog(
            title: const Text('Сравнение контрольных версий'),
            content: SizedBox(
              width: 650,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: firstId,
                          decoration:
                              const InputDecoration(labelText: 'Первая версия'),
                          items: checkpoints
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => firstId = value);
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.compare_arrows),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: secondId,
                          decoration:
                              const InputDecoration(labelText: 'Вторая версия'),
                          items: checkpoints
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => secondId = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _MetricChip('Добавлено сцен', comparison.addedScenes),
                      _MetricChip('Удалено сцен', comparison.removedScenes),
                      _MetricChip('Изменено сцен', comparison.changedScenes),
                      _MetricChip('Добавлено блоков', comparison.addedBlocks),
                      _MetricChip('Удалено блоков', comparison.removedBlocks),
                      _MetricChip('Изменено блоков', comparison.changedBlocks),
                    ],
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Закрыть'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createAutomaticBackup() async {
    final path = await widget.controller.createAutomaticBackupNow();

    if (path != null) {
      await _loadBackups();
      _showMessage('Резервная копия создана.');
    }
  }

  Future<void> _restoreBackup(AutomaticBackupEntry backup) async {
    final confirmed = await _confirm(
      title: 'Восстановить резервную копию?',
      message: 'Перед восстановлением будет создана новая копия текущего '
          'состояния. Операцию также можно отменить через Ctrl+Z.',
      confirmLabel: 'Восстановить',
    );

    if (!confirmed) {
      return;
    }

    await widget.controller.createAutomaticBackupNow();

    try {
      final document =
          await widget.fileService.loadAutomaticBackup(backup.path);
      _mergeCheckpointHistory(
        document,
        widget.controller.document.projectCheckpoints,
      );
      widget.controller.replaceWithVersionedDocument(
        document,
        summary: 'Восстановлена автоматическая резервная копия',
        preserveCurrentCheckpoints: false,
      );
      _showMessage('Резервная копия восстановлена.');
    } catch (error) {
      _showMessage('Не удалось восстановить копию: $error');
    }
  }

  Future<void> _deleteBackup(AutomaticBackupEntry backup) async {
    final confirmed = await _confirm(
      title: 'Удалить резервную копию?',
      message: backup.fileName,
      confirmLabel: 'Удалить',
      destructive: true,
    );

    if (!confirmed) {
      return;
    }

    await widget.fileService.deleteAutomaticBackup(backup.path);
    await _loadBackups();
  }

  Future<void> _editBackupSettings() async {
    final settings = widget.controller.document.versioningSettings;
    final intervalController = TextEditingController(
      text: '${settings.autoBackupMinutes}',
    );
    final countController = TextEditingController(
      text: '${settings.maxAutomaticBackups}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Настройки резервных копий'),
        content: SizedBox(
          width: 460,
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Интервал, минут',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Хранить копий',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (saved == true) {
      widget.controller.updateVersioningSettings(
        ProjectVersioningSettings(
          autoBackupMinutes: int.tryParse(intervalController.text) ?? 10,
          maxAutomaticBackups: int.tryParse(countController.text) ?? 20,
          teamPackageBaseFingerprint: settings.teamPackageBaseFingerprint,
        ).copyWith(),
      );
      await widget.fileService.pruneAutomaticBackups(
        projectName: widget.controller.projectName,
        maxBackups:
            widget.controller.document.versioningSettings.maxAutomaticBackups,
      );
      await _loadBackups();
    }

    intervalController.dispose();
    countController.dispose();
  }

  Future<void> _editMember([ProjectMember? source]) async {
    final nameController = TextEditingController(text: source?.name ?? '');
    final roleController = TextEditingController(text: source?.role ?? '');
    final emailController = TextEditingController(text: source?.email ?? '');
    final notesController = TextEditingController(text: source?.notes ?? '');
    var isActive = source?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(source == null ? 'Новый участник' : 'Участник команды'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Имя'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Роль или должность',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Почта'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Заметки'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: const Text('Активный участник'),
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      final id =
          source?.id ?? 'member_${DateTime.now().microsecondsSinceEpoch}';
      widget.controller.upsertProjectMember(
        ProjectMember(
          id: id,
          name: nameController.text,
          role: roleController.text,
          email: emailController.text,
          notes: notesController.text,
          isActive: isActive,
        ),
      );
    }

    nameController.dispose();
    roleController.dispose();
    emailController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteMember(ProjectMember member) async {
    final confirmed = await _confirm(
      title: 'Удалить участника?',
      message: 'Назначения в комментариях будут очищены. ${member.name}',
      confirmLabel: 'Удалить',
      destructive: true,
    );

    if (confirmed) {
      widget.controller.deleteProjectMember(member.id);
    }
  }

  Future<void> _editComment([CollaborationComment? source]) async {
    final document = widget.controller.document;
    final textController = TextEditingController(text: source?.text ?? '');
    var targetType = source?.targetType ?? CollaborationTargetType.project;
    String? targetId = source?.targetId;
    String? authorId = source?.authorId;
    String? assigneeId = source?.assigneeId;
    var status = source?.status ?? CollaborationCommentStatus.open;
    var dueDate = source?.dueDate ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final targets = _targetsForType(document, targetType);

          if (targetType == CollaborationTargetType.project) {
            targetId = null;
          } else if (targetId != null &&
              !targets.any((target) => target.id == targetId)) {
            targetId = null;
          }

          return AlertDialog(
            title: Text(source == null ? 'Новый комментарий' : 'Комментарий'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: textController,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Текст комментария или задачи',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child:
                              DropdownButtonFormField<CollaborationTargetType>(
                            initialValue: targetType,
                            decoration:
                                const InputDecoration(labelText: 'Объект'),
                            items: CollaborationTargetType.values
                                .map(
                                  (type) =>
                                      DropdownMenuItem<CollaborationTargetType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  targetType = value;
                                  targetId = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey<String>(targetType.name),
                            initialValue: targetId,
                            decoration:
                                const InputDecoration(labelText: 'Элемент'),
                            items: <DropdownMenuItem<String?>>[
                              if (targetType == CollaborationTargetType.project)
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Весь проект'),
                                )
                              else
                                ...targets.map(
                                  (target) => DropdownMenuItem<String?>(
                                    value: target.id,
                                    child: Text(
                                      target.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged:
                                targetType == CollaborationTargetType.project
                                    ? null
                                    : (value) =>
                                        setDialogState(() => targetId = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: authorId,
                            decoration:
                                const InputDecoration(labelText: 'Автор'),
                            items: _memberItems(document),
                            onChanged: (value) =>
                                setDialogState(() => authorId = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: assigneeId,
                            decoration: const InputDecoration(
                              labelText: 'Ответственный',
                            ),
                            items: _memberItems(document),
                            onChanged: (value) =>
                                setDialogState(() => assigneeId = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<
                              CollaborationCommentStatus>(
                            initialValue: status,
                            decoration:
                                const InputDecoration(labelText: 'Статус'),
                            items: CollaborationCommentStatus.values
                                .map(
                                  (value) => DropdownMenuItem<
                                      CollaborationCommentStatus>(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(dueDate) ??
                                    DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (selected != null) {
                                setDialogState(
                                  () => dueDate = _dateOnly(selected),
                                );
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Срок',
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                dueDate.isEmpty ? 'Не указан' : dueDate,
                              ),
                            ),
                          ),
                        ),
                        if (dueDate.isNotEmpty)
                          IconButton(
                            tooltip: 'Очистить срок',
                            onPressed: () => setDialogState(() => dueDate = ''),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true &&
        textController.text.trim().isNotEmpty &&
        (targetType == CollaborationTargetType.project || targetId != null)) {
      final now = DateTime.now().toUtc().toIso8601String();
      widget.controller.upsertCollaborationComment(
        CollaborationComment(
          id: source?.id ?? 'comment_${DateTime.now().microsecondsSinceEpoch}',
          text: textController.text,
          targetType: targetType,
          targetId: targetId,
          authorId: authorId,
          assigneeId: assigneeId,
          status: status,
          dueDate: dueDate,
          createdAt: source?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }

    textController.dispose();
  }

  Future<void> _deleteComment(CollaborationComment comment) async {
    final confirmed = await _confirm(
      title: 'Удалить комментарий?',
      message: comment.text,
      confirmLabel: 'Удалить',
      destructive: true,
    );

    if (confirmed) {
      widget.controller.deleteCollaborationComment(comment.id);
    }
  }

  Future<void> _exportTeamPackage() async {
    final filePath = await widget.fileService.chooseExportTeamPackage(
      projectName: widget.controller.projectName,
    );

    if (filePath == null) {
      return;
    }

    try {
      final result = await widget.fileService.writeTeamPackage(
        filePath: filePath,
        document: widget.controller.document,
        projectName: widget.controller.projectName,
        exportedForMemberId: _exportMemberId,
        baseFingerprint: widget.controller.document.versioningSettings
                .teamPackageBaseFingerprint
                .trim()
                .isEmpty
            ? null
            : widget.controller.document.versioningSettings
                .teamPackageBaseFingerprint,
      );
      widget.controller.recordVersioningChange(
        summary: 'Экспортирован командный пакет',
        details: result,
        actorId: _exportMemberId,
      );
      _showMessage('Командный пакет сохранён: $result');
    } catch (error) {
      _showMessage('Ошибка экспорта пакета: $error');
    }
  }

  Future<void> _importTeamPackage() async {
    final filePath = await widget.fileService.chooseImportTeamPackage();

    if (filePath == null) {
      return;
    }

    try {
      final imported = await widget.fileService.readTeamPackage(filePath);
      final conflict = imported.conflictsWith(widget.controller.document);
      final message = conflict
          ? 'Исходная версия пакета не совпадает с текущим проектом. '
              'Импорт заменит текущие данные и может перезаписать новые правки. '
              'Перед импортом будет создана резервная копия.'
          : 'Исходная версия совпадает. Будет импортировано обновление '
              '«${imported.projectName}» от ${_formatDate(imported.exportedAt)}.';
      final confirmed = await _confirm(
        title: conflict ? 'Обнаружен конфликт версий' : 'Импортировать пакет?',
        message: message,
        confirmLabel: conflict ? 'Импортировать всё равно' : 'Импортировать',
        destructive: conflict,
      );

      if (!confirmed) {
        return;
      }

      await widget.controller.createAutomaticBackupNow();
      imported.document.versioningSettings =
          imported.document.versioningSettings.copyWith(
        teamPackageBaseFingerprint: imported.documentFingerprint,
      );
      _mergeCheckpointHistory(
        imported.document,
        widget.controller.document.projectCheckpoints,
      );
      widget.controller.replaceWithVersionedDocument(
        imported.document,
        summary: conflict
            ? 'Импортирован командный пакет с конфликтом'
            : 'Импортирован командный пакет',
        preserveCurrentCheckpoints: false,
      );
      _showMessage('Командный пакет импортирован.');
    } catch (error) {
      _showMessage('Ошибка импорта пакета: $error');
    }
  }

  void _mergeCheckpointHistory(
    FilmDocument target,
    Iterable<ProjectCheckpoint> additional,
  ) {
    final knownIds =
        target.projectCheckpoints.map((checkpoint) => checkpoint.id).toSet();

    for (final checkpoint in additional) {
      if (knownIds.add(checkpoint.id)) {
        target.projectCheckpoints.add(checkpoint);
      }
    }

    target.projectCheckpoints.sort(
      (first, second) => first.createdAt.compareTo(second.createdAt),
    );
  }

  List<DropdownMenuItem<String?>> _memberItems(FilmDocument document) {
    return <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Не указан'),
      ),
      ...document.projectMembers.map(
        (member) => DropdownMenuItem<String?>(
          value: member.id,
          child: Text(member.name),
        ),
      ),
    ];
  }

  List<_TargetOption> _targetsForType(
    FilmDocument document,
    CollaborationTargetType type,
  ) {
    switch (type) {
      case CollaborationTargetType.project:
        return const <_TargetOption>[];
      case CollaborationTargetType.scene:
        return document.sceneSections
            .map(
              (scene) => _TargetOption(
                id: scene.id,
                label: '${scene.number}. ${scene.title}',
              ),
            )
            .toList(growable: false);
      case CollaborationTargetType.shot:
        final result = <_TargetOption>[];

        for (final scene in document.sceneSections) {
          final shots = document.storyboardShotsFor(scene.id);

          for (var index = 0; index < shots.length; index++) {
            result.add(
              _TargetOption(
                id: shots[index].id,
                label: 'Кадр ${scene.number}.${index + 1}',
              ),
            );
          }
        }

        return result;
      case CollaborationTargetType.take:
        final result = <_TargetOption>[];

        for (final scene in document.sceneSections) {
          final shots = document.storyboardShotsFor(scene.id);

          for (var shotIndex = 0; shotIndex < shots.length; shotIndex++) {
            final takes = document.shotTakesFor(shots[shotIndex].id);

            for (var takeIndex = 0; takeIndex < takes.length; takeIndex++) {
              result.add(
                _TargetOption(
                  id: takes[takeIndex].id,
                  label: 'Сцена ${scene.number}, кадр ${shotIndex + 1}, '
                      'дубль ${takeIndex + 1}',
                ),
              );
            }
          }
        }

        return result;
      case CollaborationTargetType.task:
        return document.postProductionTasks
            .map(
              (task) => _TargetOption(
                id: task.id,
                label: task.title,
              ),
            )
            .toList(growable: false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: Text(message),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB94B4B),
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  String _formatDateTime(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();

    if (parsed == null) {
      return value.trim().isEmpty ? 'Дата не указана' : value;
    }

    return _formatDate(parsed);
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _dateOnly(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

class _TargetOption {
  const _TargetOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF29292D),
        border: Border.all(color: const Color(0xFF3B3B40)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF3B3B40)),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B3B40)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFFE5A93C)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAF),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: const Color(0xFF77777D)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFAAAAAF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2C2C31),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 48, color: const Color(0xFFE5A93C)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB8B8BD)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text('$value')),
      label: Text(label),
    );
  }
}
