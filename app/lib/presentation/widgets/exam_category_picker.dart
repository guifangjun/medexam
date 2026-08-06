import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/exam_category_provider.dart';

class ExamCategoryPickerButton extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final String label;
  final bool compact;
  final bool plain;
  final TextStyle? textStyle;

  const ExamCategoryPickerButton({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label = '当前考试类别',
    this.compact = false,
    this.plain = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (plain) {
      final style = textStyle ??
          TextStyle(
            color: AppTheme.textPrimary,
            fontSize: compact ? 16 : 22,
            fontWeight: FontWeight.w900,
          );
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: style.color ?? AppTheme.textPrimary,
                size: compact ? 20 : 24,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 14 : 18),
      onTap: () => _showPicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          border: Border.all(color: AppTheme.primary.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(
              Icons.school_outlined,
              color: AppTheme.primary,
              size: compact ? 18 : 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact)
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    selected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textPrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExamCategoryPickerSheet(initialSelected: selected),
    );
    if (result != null && result != selected) {
      onChanged(result);
    }
  }
}

class _ExamCategoryPickerSheet extends StatefulWidget {
  final String initialSelected;

  const _ExamCategoryPickerSheet({required this.initialSelected});

  @override
  State<_ExamCategoryPickerSheet> createState() =>
      _ExamCategoryPickerSheetState();
}

class _ExamCategoryPickerSheetState extends State<_ExamCategoryPickerSheet> {
  late String _selected = widget.initialSelected;
  String _keyword = '';
  int? _activeRootId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamCategoryProvider>();
    final roots = provider.level1Categories;
    _activeRootId ??= _rootIdForSelected(provider) ??
        (roots.isNotEmpty ? roots.first.id : null);
    final activeRootId = _activeRootId;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearch(),
            Expanded(
              child: Row(
                children: [
                  _buildRootTabs(provider, roots, activeRootId),
                  Expanded(
                    child: _buildLeafPanel(provider, activeRootId),
                  ),
                ],
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
          const Expanded(
            child: Text(
              '选择考试类别',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: TextField(
        onChanged: (value) => setState(() => _keyword = value.trim()),
        decoration: InputDecoration(
          hintText: '输入科目名称或代码进行搜索',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: AppTheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRootTabs(
    ExamCategoryProvider provider,
    List<ExamCategoryNode> roots,
    int? activeRootId,
  ) {
    final visibleRoots = _keyword.isEmpty
        ? roots
        : roots
            .where((root) =>
                _leafNamesUnderRoot(provider, root.id)
                    .any((name) => name.contains(_keyword)) ||
                root.name.contains(_keyword))
            .toList();

    return Container(
      width: 118,
      color: AppTheme.surface.withOpacity(0.68),
      child: ListView.builder(
        itemCount: visibleRoots.length,
        itemBuilder: (context, index) {
          final root = visibleRoots[index];
          final selected = root.id == activeRootId;
          return InkWell(
            onTap: () => setState(() => _activeRootId = root.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Text(
                root.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeafPanel(ExamCategoryProvider provider, int? activeRootId) {
    if (activeRootId == null) {
      return const Center(child: Text('暂无考试类别'));
    }
    final sections = provider.childrenOf(activeRootId);
    final keyword = _keyword;
    final sectionWidgets = <Widget>[];
    for (final section in sections) {
      final leaves = provider
          .childrenOf(section.id)
          .where((leaf) => keyword.isEmpty || leaf.name.contains(keyword))
          .toList();
      if (leaves.isEmpty) continue;
      sectionWidgets.add(_buildSection(section.name, leaves));
    }

    if (sectionWidgets.isEmpty) {
      final rootsLeaves = provider
          .childrenOf(activeRootId)
          .where((leaf) =>
              leaf.level == 3 &&
              (keyword.isEmpty || leaf.name.contains(keyword)))
          .toList();
      if (rootsLeaves.isNotEmpty) {
        sectionWidgets.add(_buildSection('考试科目', rootsLeaves));
      }
    }

    if (sectionWidgets.isEmpty) {
      return const Center(
        child: Text(
          '没有匹配的考试科目',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: sectionWidgets,
    );
  }

  Widget _buildSection(String title, List<ExamCategoryNode> leaves) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: leaves.map((leaf) {
              final selected = leaf.name == _selected;
              return ChoiceChip(
                label: Text(leaf.name),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppTheme.accentLight.withOpacity(0.18),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.accent : AppTheme.divider,
                  width: selected ? 1.2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (_) => setState(() => _selected = leaf.name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选择：$_selected',
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text(
                '确定',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? _rootIdForSelected(ExamCategoryProvider provider) {
    for (final leaf in provider.categories) {
      if (leaf.name == widget.initialSelected) {
        final section = provider.parentOf(leaf);
        final root = section == null ? leaf : provider.parentOf(section);
        return root?.level == 1 ? root?.id : section?.id;
      }
    }
    return null;
  }

  List<String> _leafNamesUnderRoot(ExamCategoryProvider provider, int rootId) {
    final names = <String>[];
    for (final section in provider.childrenOf(rootId)) {
      for (final leaf in provider.childrenOf(section.id)) {
        names.add(leaf.name);
      }
    }
    return names;
  }
}
