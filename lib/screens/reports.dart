import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Reports (master spec screen 6): monthly bar chart In vs Out,
/// category donut, vs-last-period mini cards, insight banner.
enum ReportPeriod { week, month, year }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  int? _touchedBar;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: Store.changes,
          builder: (context, _, _) {
            final now = DateTime.now();
            final bars = _barData(now);
            final (rangeStart, rangeEnd) = _periodRange(now);
            final (prevStart, prevEnd) = _prevRange(now);
            final inSum = _sum(rangeStart, rangeEnd, income: true);
            final outSum = _sum(rangeStart, rangeEnd, income: false);
            final prevIn = _sum(prevStart, prevEnd, income: true);
            final prevOut = _sum(prevStart, prevEnd, income: false);
            final donut = _donutData(rangeStart, rangeEnd);
            final totalDonut =
                donut.fold<int>(0, (s, e) => s + e.$2);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text('Reports', style: AppText.h1),
                const SizedBox(height: 16),
                _periodSegmented(),
                const SizedBox(height: 20),
                Container(
                  decoration: cardDecoration(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Income vs Expenses', style: AppText.title),
                          const Spacer(),
                          _legendDot(AppColors.brand, 'Income'),
                          const SizedBox(width: 12),
                          _legendDot(const Color(0xFFF0908F), 'Expenses'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _touchedBar == null
                            ? _periodCaption(now)
                            : _barSummary(bars[_touchedBar!]),
                        style: AppText.caption.copyWith(
                            color: AppColors.inkTertiary),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 168,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _niceMax(bars),
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => AppColors.ink,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final label = rodIndex == 0
                                      ? 'Income'
                                      : 'Expenses';
                                  return BarTooltipItem(
                                    '$label\n${fmtRs(rod.toY.round())}',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                              touchCallback: (event, response) {
                                setState(() {
                                  _touchedBar = (event
                                              .isInterestedForInteractions &&
                                          response?.spot != null)
                                      ? response!.spot!.touchedBarGroupIndex
                                      : null;
                                });
                              },
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      _compact(value.round()),
                                      style: AppText.caption.copyWith(
                                          fontSize: 10,
                                          color: AppColors.inkTertiary),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= bars.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(top: 6),
                                      child: Text(
                                        bars[i].$1,
                                        style: AppText.caption.copyWith(
                                            fontSize: 10,
                                            color: AppColors.inkTertiary),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: _niceMax(bars) / 4,
                              getDrawingHorizontalLine: (_) =>
                                  const FlLine(
                                      color: AppColors.hairline,
                                      strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (var i = 0; i < bars.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barsSpace: 2,
                                  barRods: [
                                    BarChartRodData(
                                      toY: bars[i].$2.toDouble(),
                                      width: 8,
                                      color: AppColors.brand,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(4)),
                                    ),
                                    BarChartRodData(
                                      toY: bars[i].$3.toDouble(),
                                      width: 8,
                                      color: const Color(0xFFF0908F),
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(4)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _miniCard(
                            'Total Income', inSum, _delta(inSum, prevIn),
                            income: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _miniCard(
                            'Total Expenses', outSum, _delta(outSum, prevOut),
                            income: false)),
                  ],
                ),
                const SizedBox(height: 16),
                _insightBanner(rangeStart, rangeEnd, prevStart, prevEnd),
                Container(
                  decoration: cardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Where your money went', style: AppText.title),
                      const SizedBox(height: 4),
                      Text(_periodCaption(now),
                          style: AppText.caption
                              .copyWith(color: AppColors.inkTertiary)),
                      const SizedBox(height: 16),
                      if (totalDonut == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No expenses in this period yet',
                                style: AppText.label.copyWith(
                                    color: AppColors.inkSecondary)),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 56,
                                  sections: [
                                    for (final e in donut)
                                      PieChartSectionData(
                                        value: e.$2.toDouble(),
                                        color: Color(e.$3),
                                        radius: 26,
                                        showTitle: false,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('TOTAL SPENT',
                                      style: AppText.micro.copyWith(
                                          color: AppColors.inkTertiary)),
                                  const SizedBox(height: 4),
                                  AmountText(
                                      value: totalDonut,
                                      style: AppText.amountXL,
                                      neutral: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final e in donut)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(e.$3),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(e.$1, style: AppText.body)),
                                Text(
                                    '${percentOf(e.$2, totalDonut)}%',
                                    style: AppText.caption.copyWith(
                                        color: AppColors.inkTertiary)),
                                const SizedBox(width: 12),
                                AmountText(
                                    value: e.$2,
                                    style: AppText.amountRow,
                                    neutral: true),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _periodSegmented() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceInset,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final p in ReportPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _period = p;
                  _touchedBar = null;
                }),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _period == p
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    boxShadow:
                        _period == p ? AppShadows.card : null,
                  ),
                  child: Text(
                    switch (p) {
                      ReportPeriod.week => 'Week',
                      ReportPeriod.month => 'Month',
                      ReportPeriod.year => 'Year',
                    },
                    style: AppText.label.copyWith(
                      color: _period == p
                          ? AppColors.ink
                          : AppColors.inkTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppText.caption.copyWith(color: AppColors.inkSecondary)),
      ],
    );
  }

  Widget _miniCard(String label, int value, double? delta,
      {required bool income}) {
    final up = (delta ?? 0) >= 0;
    // Income up = good (green); expenses up = bad (red).
    final good = income ? up : !up;
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: income ? AppColors.mintTint : AppColors.expenseTint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  income ? Icons.south_west : Icons.north_east,
                  size: 16,
                  color: income ? AppColors.brand : AppColors.expense,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AmountText(value: value, style: AppText.amountXL, neutral: true),
          const SizedBox(height: 4),
          if (delta == null)
            Text('First period — no comparison yet',
                style: AppText.caption
                    .copyWith(color: AppColors.inkTertiary))
          else
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: good ? AppColors.brand : AppColors.expense),
                const SizedBox(width: 2),
                Text(
                  '${delta.abs().toStringAsFixed(0)}% vs last ${_period.name}',
                  style: AppText.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: good ? AppColors.brand : AppColors.expense),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _insightBanner(DateTime start, DateTime end, DateTime prevStart,
      DateTime prevEnd) {
    // Data-driven insight: top category whose spend rose most vs prior period.
    final current = <String, int>{};
    final previous = <String, int>{};
    for (final t in Store.allTxnsDesc) {
      if (!t.isExpense || t.categoryId.isEmpty) continue;
      if (!t.date.isBefore(start) && t.date.isBefore(end)) {
        current[t.categoryId] = (current[t.categoryId] ?? 0) + t.amount;
      }
      if (!t.date.isBefore(prevStart) && t.date.isBefore(prevEnd)) {
        previous[t.categoryId] = (previous[t.categoryId] ?? 0) + t.amount;
      }
    }
    String? bestCat;
    var bestDelta = 0.0;
    current.forEach((catId, sum) {
      final prev = previous[catId] ?? 0;
      if (prev > 0) {
        final d = (sum - prev) / prev * 100;
        if (d > bestDelta) {
          bestDelta = d;
          bestCat = catId;
        }
      }
    });
    if (bestCat == null || bestDelta < 5) return const SizedBox.shrink();
    final cat = Store.categoryById(bestCat!);
    if (cat == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.hero,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.lightbulb_outline,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Insight',
                      style: AppText.label.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'Your ${cat.name.toLowerCase()} spending is up ${bestDelta.round()}% vs last ${_period.name}.',
                    style: AppText.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- data helpers ----

  (DateTime, DateTime) _periodRange(DateTime now) {
    return switch (_period) {
      ReportPeriod.week => (
          DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1)),
          DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1))
              .add(const Duration(days: 7)),
        ),
      ReportPeriod.month =>
        (DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
      ReportPeriod.year =>
        (DateTime(now.year), DateTime(now.year + 1)),
    };
  }

  (DateTime, DateTime) _prevRange(DateTime now) {
    final (start, end) = _periodRange(now);
    final len = end.difference(start);
    return (start.subtract(len), start);
  }

  String _periodCaption(DateTime now) {
    return switch (_period) {
      ReportPeriod.week => 'This week',
      ReportPeriod.month => fmtMonth(now),
      ReportPeriod.year => '${now.year}',
    };
  }

  int _sum(DateTime start, DateTime end, {required bool income}) {
    var s = 0;
    for (final t in Store.allTxnsDesc) {
      if (t.isTransfer || t.isAdjustment) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      if (income && t.isIncome) s += t.amount;
      if (!income && t.isExpense) s += t.amount;
    }
    return s;
  }

  /// (label, income, expense) per bar bucket.
  List<(String, int, int)> _barData(DateTime now) {
    switch (_period) {
      case ReportPeriod.month:
        // Last 6 months.
        return [
          for (var back = 5; back >= 0; back--)
            () {
              final m = DateTime(now.year, now.month - back);
              final start = DateTime(m.year, m.month);
              final end = DateTime(m.year, m.month + 1);
              return (
                DateFormat('MMM').format(m),
                _sum(start, end, income: true),
                _sum(start, end, income: false),
              );
            }(),
        ];
      case ReportPeriod.week:
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return [
          for (var d = 0; d < 7; d++)
            () {
              final start = monday.add(Duration(days: d));
              final end = start.add(const Duration(days: 1));
              return (
                DateFormat('EEE').format(start),
                _sum(start, end, income: true),
                _sum(start, end, income: false),
              );
            }(),
        ];
      case ReportPeriod.year:
        return [
          for (var m = 1; m <= 12; m++)
            (
              DateFormat('MMM').format(DateTime(now.year, m)),
              _sum(DateTime(now.year, m), DateTime(now.year, m + 1),
                  income: true),
              _sum(DateTime(now.year, m), DateTime(now.year, m + 1),
                  income: false),
            ),
        ];
    }
  }

  String _barSummary((String, int, int) bar) =>
      '${bar.$1}: ${fmtRs(bar.$2)} in · ${fmtRs(bar.$3)} out';

  double _niceMax(List<(String, int, int)> bars) {
    var max = 0;
    for (final b in bars) {
      if (b.$2 > max) max = b.$2;
      if (b.$3 > max) max = b.$3;
    }
    if (max <= 0) return 100;
    // Round up to a "nice" ceiling.
    var ceiling = 100.0;
    while (ceiling < max) {
      ceiling *= 2;
      if (ceiling >= max) break;
      ceiling *= 2.5;
    }
    return ceiling;
  }

  /// Donut entries: (label, amount, color) top-5 + Other.
  List<(String, int, int)> _donutData(DateTime start, DateTime end) {
    final byCat = <String, int>{};
    for (final t in Store.allTxnsDesc) {
      if (!t.isExpense || t.categoryId.isEmpty) continue;
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <(String, int, int)>[];
    var other = 0;
    for (var i = 0; i < sorted.length; i++) {
      final cat = Store.categoryById(sorted[i].key);
      if (cat == null) continue;
      if (i < 5) {
        out.add((cat.name, sorted[i].value, cat.tintColor));
      } else {
        other += sorted[i].value;
      }
    }
    if (other > 0) out.add(('Other', other, 0xFF93A698));
    return out;
  }

  /// Compact axis label: 950 → "950", 12500 → "12.5k", 340000 → "3.4L".
  String _compact(int v) {
    if (v < 1000) return '$v';
    if (v < 100000) {
      final k = v / 1000;
      return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
    }
    final l = v / 100000;
    return '${l == l.roundToDouble() ? l.toInt() : l.toStringAsFixed(1)}L';
  }

  double? _delta(int current, int previous) {
    if (previous <= 0) return null;
    return (current - previous) / previous * 100;
  }
}
