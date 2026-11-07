import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Weekly Outflow Chart Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OCTOBER OUTFLOW TREND',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _WeekBar(week: 'Week 1', heightRatio: 0.45, amount: '₹12k'),
                        _WeekBar(week: 'Week 2', heightRatio: 0.85, amount: '₹25k'),
                        _WeekBar(week: 'Week 3', heightRatio: 0.35, amount: '₹8k'),
                        _WeekBar(week: 'Week 4', heightRatio: 0.20, amount: '₹4k'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. AI Financial Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'AI FINANCIAL INSIGHTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InsightItem(
                    emoji: '💡',
                    title: 'SIP Auto-Debited',
                    description:
                        '₹25,000 auto-debited for Zerodha Mutual Fund SIP on Oct 02. Your disciplined savings streak is 8 months!',
                  ),
                  const Divider(height: 20),
                  _InsightItem(
                    emoji: '⚡',
                    title: 'Electricity Spike',
                    description:
                        'BESCOM electricity bill was ₹2,850 on Oct 05, approx ₹400 higher than your 3-month running average.',
                  ),
                  const Divider(height: 20),
                  _InsightItem(
                    emoji: '🍔',
                    title: 'Food & Dining',
                    description:
                        'Swiggy and Starbucks account for ₹1,062.50 across 2 transactions in October.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Category Breakdown Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CATEGORY ALLOCATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...finance.categoryBreakdown.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 12)),
                          Text(
                            inrFormat.format(e.value),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final String week;
  final double heightRatio;
  final String amount;

  const _WeekBar({
    required this.week,
    required this.heightRatio,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(amount, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          FractionallySizedBox(
            heightFactor: heightRatio,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(week, style: const TextStyle(fontSize: 10, color: AppTheme.textFaint)),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _InsightItem({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

