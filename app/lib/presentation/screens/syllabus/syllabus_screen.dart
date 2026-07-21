import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/question_provider.dart';
import '../../widgets/app_glass.dart';

class SyllabusScreen extends StatelessWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final examCategory = context.watch<QuestionProvider>().examCategory;
    final syllabus = _SyllabusCatalog.byCategory(examCategory);

    return GlassScaffold(
      appBar: AppBar(title: const Text('考试大纲')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            tint: AppTheme.primary.withOpacity(0.10),
            borderColor: AppTheme.primary.withOpacity(0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$examCategory考试大纲',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            syllabus.summary,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: syllabus.tags
                      .map((tag) => _SyllabusTag(label: tag))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '考试模块',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...syllabus.sections.map((section) => _SectionCard(section: section)),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.all(16),
            tint: Colors.white.withOpacity(0.76),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    color: AppTheme.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    syllabus.advice,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textSecondary,
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
}

class _SectionCard extends StatelessWidget {
  final _SyllabusSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        tint: Colors.white.withOpacity(0.82),
        borderColor: AppTheme.divider.withOpacity(0.72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, color: section.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  section.weight,
                  style: TextStyle(
                    color: section.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...section.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: section.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyllabusTag extends StatelessWidget {
  final String label;
  const _SyllabusTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SyllabusCatalog {
  final String summary;
  final String advice;
  final List<String> tags;
  final List<_SyllabusSection> sections;

  const _SyllabusCatalog({
    required this.summary,
    required this.advice,
    required this.tags,
    required this.sections,
  });

  static _SyllabusCatalog byCategory(String category) {
    switch (category) {
      case '初级职称':
        return _junior;
      case '中级职称':
        return _middle;
      case '高级职称':
        return _senior;
      case '执业资格':
      default:
        return _license;
    }
  }

  static const _license = _SyllabusCatalog(
    summary: '围绕岗位准入能力，覆盖基础医学、临床医学、预防医学与医学人文。',
    advice: '建议先完成基础医学和临床医学章节刷题，再用模考检查综合应用能力。',
    tags: ['准入考试', '基础能力', '临床应用', '医学人文'],
    sections: [
      _SyllabusSection(
        icon: Icons.biotech_rounded,
        title: '基础医学综合',
        weight: '核心',
        color: AppTheme.primary,
        items: ['解剖学、生理学、病理学、生物化学', '常见机制、正常结构与功能、疾病发生发展规律'],
      ),
      _SyllabusSection(
        icon: Icons.local_hospital_rounded,
        title: '临床医学综合',
        weight: '高频',
        color: AppTheme.accent,
        items: ['内科学、外科学、妇产科学、儿科学', '常见病诊断、治疗原则、并发症处理'],
      ),
      _SyllabusSection(
        icon: Icons.public_rounded,
        title: '预防医学与人文',
        weight: '必考',
        color: AppTheme.success,
        items: ['流行病学、统计学、卫生法规', '医学伦理、医患沟通、依法执业'],
      ),
    ],
  );

  static const _junior = _SyllabusCatalog(
    summary: '面向初级岗位胜任力，强调专业基础、常见病处理和基本操作规范。',
    advice: '建议以专业基础为主线，每天配合常见题型训练，形成稳定得分点。',
    tags: ['初级职称', '专业基础', '岗位规范', '常见题型'],
    sections: [
      _SyllabusSection(
        icon: Icons.school_rounded,
        title: '专业基础知识',
        weight: '基础',
        color: AppTheme.primary,
        items: ['生理、病理、药理等基础知识', '专业相关概念、原则和基础判断'],
      ),
      _SyllabusSection(
        icon: Icons.health_and_safety_rounded,
        title: '专业理论与技能',
        weight: '核心',
        color: AppTheme.accent,
        items: ['诊断思路、治疗流程、基本技能', '常见检查指标和操作规范'],
      ),
      _SyllabusSection(
        icon: Icons.assignment_turned_in_rounded,
        title: '常见病诊疗',
        weight: '高频',
        color: AppTheme.success,
        items: ['心血管、呼吸、消化等常见系统疾病', '典型表现、鉴别诊断和处理原则'],
      ),
    ],
  );

  static const _middle = _SyllabusCatalog(
    summary: '面向中级专业能力，强调专业实践、病例分析和临床决策能力。',
    advice: '建议在完成专业理论后，集中训练病例题和跨知识点综合题。',
    tags: ['中级职称', '专业实践', '病例分析', '临床决策'],
    sections: [
      _SyllabusSection(
        icon: Icons.psychology_rounded,
        title: '专业理论',
        weight: '核心',
        color: AppTheme.primary,
        items: ['病理生理、免疫、分子机制等进阶理论', '疾病机制与临床表现之间的关联'],
      ),
      _SyllabusSection(
        icon: Icons.medical_information_rounded,
        title: '专业实践能力',
        weight: '高频',
        color: AppTheme.accent,
        items: ['诊疗路径、检查选择、治疗方案制定', '专业指南、循证医学和规范化处理'],
      ),
      _SyllabusSection(
        icon: Icons.hub_rounded,
        title: '综合病例分析',
        weight: '拉分',
        color: AppTheme.error,
        items: ['复杂病例、急危重症、并发症处理', '多学科协作和鉴别诊断'],
      ),
    ],
  );

  static const _senior = _SyllabusCatalog(
    summary: '面向高级职称能力评价，强调专科深度、学科前沿、科研与教学能力。',
    advice: '建议以专科前沿和病例综合为主，同时补齐科研方法与医学教育能力。',
    tags: ['高级职称', '专科前沿', '科研能力', '病例综合'],
    sections: [
      _SyllabusSection(
        icon: Icons.auto_awesome_rounded,
        title: '学科前沿与指南更新',
        weight: '重点',
        color: AppTheme.primary,
        items: ['近年指南更新、诊疗新技术、新证据', '专科热点、前沿进展与临床转化'],
      ),
      _SyllabusSection(
        icon: Icons.science_rounded,
        title: '临床科研方法',
        weight: '核心',
        color: AppTheme.accent,
        items: ['临床试验设计、医学统计、论文写作', '研究伦理、证据等级和结果解读'],
      ),
      _SyllabusSection(
        icon: Icons.groups_rounded,
        title: '病例综合与教学能力',
        weight: '综合',
        color: AppTheme.error,
        items: ['疑难危重病例分析、诊疗决策复盘', '医学教育、继续教育和团队带教能力'],
      ),
    ],
  );
}

class _SyllabusSection {
  final IconData icon;
  final String title;
  final String weight;
  final Color color;
  final List<String> items;

  const _SyllabusSection({
    required this.icon,
    required this.title,
    required this.weight,
    required this.color,
    required this.items,
  });
}
