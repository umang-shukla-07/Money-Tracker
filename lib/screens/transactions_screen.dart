import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final txns = finance.transactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${txns.length} entries',
                style: const TextStyle(fontSize: 12, color: AppTheme.textFaint),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (q) => finance.setSearchQuery(q),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search merchant, description...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textFaint),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: true,
                  onTap: () => finance.setAmountRange('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Under ₹500',
                  isSelected: false,
                  onTap: () => finance.setAmountRange('under_500'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '₹500–₹5k',
                  isSelected: false,
                  onTap: () => finance.setAmountRange('500_to_5000'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Over ₹5k',
                  isSelected: false,
                  onTap: () => finance.setAmountRange('over_5000'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Income Only',
                  isSelected: false,
                  onTap: () => finance.setAmountRange('income'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Transaction List
          Expanded(
            child: txns.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions match your search.',
                      style: TextStyle(color: AppTheme.textFaint),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: txns.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final t = txns[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: t.isCredit
                                  ? AppTheme.income.withOpacity(0.12)
                                  : AppTheme.expense.withOpacity(0.12),
                              child: Icon(
                                t.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 16,
                                color: t.isCredit ? AppTheme.income : AppTheme.expense,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.cleanMerchantName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${t.date} • ${t.categoryName}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.formattedAmount,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: t.isCredit ? AppTheme.income : AppTheme.expense,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

