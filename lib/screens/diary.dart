import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// v1.1.7: Diary tab — Journal + Tasks + personal Goals in one
/// screen, same dark liquid-glass + neon-blue language as the rest
/// of the app. Diary data is a SEPARATE tracker (never wallets,
/// income or expense) and IS included in the cloud backup snapshot.
///
/// NOTE: these life Goals are NOT the finance Savings Goals on the
/// Home quick action — the two are deliberately separate.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

enum _DiaryTab { journal, tasks, goals }

const _moods = <String, IconData>{
  'happy': Icons.sentiment_very_satisfied_outlined,
  'calm': Icons.sentiment_satisfied_outlined,
  'proud': Icons.emoji_events_outlined,
  'low': Icons.sentiment_dissatisfied_outlined,
  'tired': Icons.bedtime_outlined,
};

class _DiaryScreenState extends State<DiaryScreen> {
  _DiaryTab _tab = _DiaryTab.journal;
  String _journalQuery = '';
  String _taskFilter = 'All'; // All | Open | Done

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Store.changes,
      builder: (context, _, _) {
        final openTasks =
            Store.allDiaryTasks.where((t) => !t.done).length;
        final totalGoals = Store.allLifeGoals.length;
        final doneGoals =
            Store.allLifeGoals.where((g) => g.isDone).length;
        return GlassScaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Diary', style: AppText.h1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentTint,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          border:
                              Border.all(color: AppColors.hairline),
                        ),
                        child: Text(
                          '$openTasks open · $doneGoals/$totalGoals goals',
                          style: AppText.label.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _segmented(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: switch (_tab) {
                    _DiaryTab.journal => _journalBody(),
                    _DiaryTab.tasks => _tasksBody(),
                    _DiaryTab.goals => _goalsBody(),
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: PrimaryButton(
                    label: switch (_tab) {
                      _DiaryTab.journal => 'New Entry',
                      _DiaryTab.tasks => 'New Task',
                      _DiaryTab.goals => 'New Goal',
                    },
                    height: 58,
                    onTap: () {
                      switch (_tab) {
                        case _DiaryTab.journal:
                          _openJournalForm(context);
                        case _DiaryTab.tasks:
                          _openTaskForm(context);
                        case _DiaryTab.goals:
                          _openGoalForm(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _segmented() {
    Widget seg(String label, _DiaryTab tab) {
      final selected = _tab == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label,
                style: AppText.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.inkSecondary,
                )),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(children: [
        seg('Journal', _DiaryTab.journal),
        seg('Tasks', _DiaryTab.tasks),
        seg('Goals', _DiaryTab.goals),
      ]),
    );
  }

  // ---------------------------------------------------------------- journal
  Widget _journalBody() {
    final entries = Store.searchJournal(_journalQuery);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        TextField(
          onChanged: (v) => setState(() => _journalQuery = v),
          decoration: InputDecoration(
            hintText: 'Search your journal…',
            hintStyle:
                AppText.body.copyWith(color: AppColors.inkTertiary),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.inkTertiary),
            filled: true,
            fillColor: AppColors.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
          style: AppText.body,
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Container(
            decoration: cardDecoration(),
            child: EmptyState(
              icon: Icons.book_outlined,
              title: _journalQuery.isEmpty
                  ? 'No journal entries yet'
                  : 'Nothing matches',
              body: _journalQuery.isEmpty
                  ? 'Write your first entry — a thought, a day, a memory.'
                  : 'Try a different search.',
              actionLabel:
                  _journalQuery.isEmpty ? 'New Entry' : null,
              onAction: _journalQuery.isEmpty
                  ? () => _openJournalForm(context)
                  : null,
            ),
          )
        else
          GroupCard(
            children: [
              for (final e in entries) _journalRow(e),
            ],
          ),
      ],
    );
  }

  Widget _journalRow(JournalEntry e) {
    return InkWell(
      onTap: () => _openJournalForm(context, existing: e),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                e.mood.isNotEmpty && _moods.containsKey(e.mood)
                    ? _moods[e.mood]!
                    : Icons.article_outlined,
                size: 22,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.title.isEmpty ? 'Untitled entry' : e.title,
                          style: AppText.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        fmtDate(DateTime.fromMillisecondsSinceEpoch(
                            e.dateMs)),
                        style: AppText.caption.copyWith(
                            color: AppColors.inkTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.text,
                    style: AppText.body.copyWith(
                        color: AppColors.inkSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openJournalForm(BuildContext context, {JournalEntry? existing}) {
    showAppSheet<void>(
      context: context,
      title: existing == null ? 'New Entry' : 'Edit Entry',
      child: _JournalForm(existing: existing),
    );
  }

  // ------------------------------------------------------------------ tasks
  Widget _tasksBody() {
    var tasks = Store.allDiaryTasks;
    if (_taskFilter == 'Open') {
      tasks = tasks.where((t) => !t.done).toList();
    } else if (_taskFilter == 'Done') {
      tasks = tasks.where((t) => t.done).toList();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ['All', 'Open', 'Done'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _taskFilter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _taskFilter == f
                            ? AppColors.accent
                            : AppColors.surfaceInset,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border:
                            Border.all(color: AppColors.hairline),
                      ),
                      child: Text(f,
                          style: AppText.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _taskFilter == f
                                ? Colors.white
                                : AppColors.inkSecondary,
                          )),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          Container(
            decoration: cardDecoration(),
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No tasks here',
              body: _taskFilter == 'All'
                  ? 'Add your first task and tick it off as you go.'
                  : 'Nothing in this filter.',
              actionLabel: _taskFilter == 'All' ? 'New Task' : null,
              onAction: _taskFilter == 'All'
                  ? () => _openTaskForm(context)
                  : null,
            ),
          )
        else
          GroupCard(
            children: [
              for (final t in tasks) _taskRow(t),
            ],
          ),
      ],
    );
  }

  Widget _taskRow(DiaryTask t) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: () => Store.toggleDiaryTask(t.id),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: t.done
                    ? AppColors.accent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: t.done
                        ? AppColors.accent
                        : AppColors.inkTertiary,
                    width: 2),
              ),
              child: t.done
                  ? const Icon(Icons.check,
                      size: 18, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: AppText.body.copyWith(
                    decoration:
                        t.done ? TextDecoration.lineThrough : null,
                    color: t.done
                        ? AppColors.inkTertiary
                        : AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (t.dueDateMs > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Due ${fmtDate(DateTime.fromMillisecondsSinceEpoch(t.dueDateMs))}',
                      style: AppText.caption.copyWith(
                          color: AppColors.inkTertiary),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showConfirmDialog(
                context: context,
                title: 'Delete this task?',
                body: t.title,
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok) await Store.deleteDiaryTask(t.id);
            },
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.expense),
          ),
        ],
      ),
    );
  }

  void _openTaskForm(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: 'New Task',
      child: _TaskForm(),
    );
  }

  // ------------------------------------------------------------------ goals
  Widget _goalsBody() {
    final goals = Store.allLifeGoals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Container(
          decoration: cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Text(
            'Personal goals — separate from your finance Savings Goals. Track what matters to you, one step at a time.',
            style: AppText.body
                .copyWith(color: AppColors.inkSecondary),
          ),
        ),
        const SizedBox(height: 16),
        if (goals.isEmpty)
          Container(
            decoration: cardDecoration(),
            child: EmptyState(
              icon: Icons.flag_outlined,
              title: 'No personal goals yet',
              body: 'Set a goal, break it into steps, and watch the progress grow.',
              actionLabel: 'New Goal',
              onAction: () => _openGoalForm(context),
            ),
          )
        else
          GroupCard(
            children: [
              for (final g in goals) _goalRow(g),
            ],
          ),
      ],
    );
  }

  Widget _goalRow(LifeGoal g) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(g.name,
                    style: AppText.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (g.isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentTint,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('Done',
                      style: AppText.label.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand)),
                ),
              IconButton(
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context: context,
                    title: 'Delete this goal?',
                    body: g.name,
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok) await Store.deleteLifeGoal(g.id);
                },
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.expense),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${g.stepsDone} of ${g.stepsTotal} steps'
            '${g.targetDateMs > 0 ? ' · Target ${fmtDate(DateTime.fromMillisecondsSinceEpoch(g.targetDateMs))}' : ''}',
            style: AppText.caption
                .copyWith(color: AppColors.inkTertiary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: g.progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceInset,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(g.progress * 100).round()}%',
                  style: AppText.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stepButton(Icons.remove, () {
                if (g.stepsDone > 0) {
                  g.stepsDone--;
                  Store.saveLifeGoal(g);
                }
              }),
              const SizedBox(width: 8),
              _stepButton(Icons.add, () {
                if (g.stepsDone < g.stepsTotal) {
                  g.stepsDone++;
                  Store.saveLifeGoal(g);
                }
              }),
              const SizedBox(width: 8),
              Text('Step', style: AppText.caption.copyWith(
                  color: AppColors.inkTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceInset,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }

  void _openGoalForm(BuildContext context) {
    showAppSheet<void>(
      context: context,
      title: 'New Goal',
      child: _GoalForm(),
    );
  }
}

// --------------------------------------------------------------------- forms

class _JournalForm extends StatefulWidget {
  final JournalEntry? existing;
  const _JournalForm({this.existing});

  @override
  State<_JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends State<_JournalForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _textCtrl;
  late String _mood;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _textCtrl = TextEditingController(text: ex?.text ?? '');
    _mood = ex?.mood ?? '';
    _date = ex != null
        ? DateTime.fromMillisecondsSinceEpoch(ex.dateMs)
        : DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_textCtrl.text.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ex = widget.existing;
    await Store.saveJournal(JournalEntry(
      id: ex?.id ?? newId(),
      title: _titleCtrl.text.trim(),
      text: _textCtrl.text.trim(),
      mood: _mood,
      dateMs:
          DateTime(_date.year, _date.month, _date.day).millisecondsSinceEpoch,
      createdAtMs: ex?.createdAtMs ?? now,
      updatedAtMs: now,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel('Title (optional)'),
        _sheetField(_titleCtrl, 'A title for this day…'),
        const SizedBox(height: 16),
        _sheetLabel('How are you feeling? (optional)'),
        Wrap(
          spacing: 8,
          children: [
            for (final m in _moods.entries)
              GestureDetector(
                onTap: () => setState(() => _mood = _mood == m.key ? '' : m.key),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _mood == m.key
                        ? AppColors.accent
                        : AppColors.surfaceInset,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Icon(m.value,
                      size: 24,
                      color: _mood == m.key
                          ? Colors.white
                          : AppColors.inkSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _sheetLabel('Date'),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(fmtDate(_date), style: AppText.body),
          ),
        ),
        const SizedBox(height: 16),
        _sheetLabel('Entry'),
        TextField(
          controller: _textCtrl,
          maxLines: 6,
          minLines: 4,
          decoration: InputDecoration(
            hintText: 'Write it down…',
            hintStyle:
                AppText.body.copyWith(color: AppColors.inkTertiary),
            filled: true,
            fillColor: AppColors.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
          style: AppText.body,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.existing == null ? 'Save Entry' : 'Save Changes',
          onTap:
              _textCtrl.text.trim().isEmpty ? null : _save,
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await showConfirmDialog(
                context: context,
                title: 'Delete this entry?',
                body: 'This journal entry will be removed.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok || !mounted) return;
              await Store.deleteJournal(widget.existing!.id);
              if (mounted) navigator.pop();
            },
            child: Text('Delete this entry',
                style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.expense)),
          ),
        ],
      ],
    );
  }
}

class _TaskForm extends StatefulWidget {
  const _TaskForm();

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _titleCtrl = TextEditingController();
  DateTime? _due;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    await Store.saveDiaryTask(DiaryTask(
      id: newId(),
      title: _titleCtrl.text.trim(),
      dueDateMs: _due == null
          ? 0
          : DateTime(_due!.year, _due!.month, _due!.day)
              .millisecondsSinceEpoch,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel('Task'),
        _sheetField(_titleCtrl, 'What needs doing?'),
        const SizedBox(height: 16),
        _sheetLabel('Due date (optional)'),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _due = picked);
                },
                child: Container(
                  height: 56,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    _due == null ? 'No due date' : fmtDate(_due!),
                    style: AppText.body.copyWith(
                        color: _due == null
                            ? AppColors.inkTertiary
                            : AppColors.ink),
                  ),
                ),
              ),
            ),
            if (_due != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _due = null),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  height: 56,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text('Clear',
                      style: AppText.body
                          .copyWith(color: AppColors.expense)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Save Task',
          onTap: _titleCtrl.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm();

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final _nameCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController(text: '5');
  DateTime? _target;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final steps = int.tryParse(_stepsCtrl.text) ?? 1;
    await Store.saveLifeGoal(LifeGoal(
      id: newId(),
      name: _nameCtrl.text.trim(),
      targetDateMs: _target == null
          ? 0
          : DateTime(_target!.year, _target!.month, _target!.day)
              .millisecondsSinceEpoch,
      stepsTotal: steps < 1 ? 1 : steps,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel('Goal'),
        _sheetField(_nameCtrl, 'e.g. Read 12 books this year'),
        const SizedBox(height: 16),
        _sheetLabel('Steps to complete it'),
        TextField(
          controller: _stepsCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '5',
            hintStyle:
                AppText.body.copyWith(color: AppColors.inkTertiary),
            filled: true,
            fillColor: AppColors.surfaceInset,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
          style: AppText.body,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _sheetLabel('Target date (optional)'),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _target ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _target = picked);
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _target == null ? 'No target date' : fmtDate(_target!),
              style: AppText.body.copyWith(
                  color: _target == null
                      ? AppColors.inkTertiary
                      : AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Save Goal',
          onTap: _nameCtrl.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

Widget _sheetLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: AppText.label.copyWith(color: AppColors.inkSecondary)),
  );
}

Widget _sheetField(TextEditingController ctrl, String hint) {
  return TextField(
    controller: ctrl,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppText.body.copyWith(color: AppColors.inkTertiary),
      filled: true,
      fillColor: AppColors.surfaceInset,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
    ),
    style: AppText.body,
  );
}
