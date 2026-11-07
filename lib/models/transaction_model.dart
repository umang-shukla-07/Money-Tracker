import 'package:intl/intl.dart';

class TransactionModel {
  final String id;
  final String? userId; // Scoped to Supabase Auth User ID
  final String date; // YYYY-MM-DD
  final int amount; // Exact integer paise (e.g. 64250 = ₹642.50)
  final String direction; // 'debit' or 'credit'
  final String rawDescription;
  final String cleanMerchantName;
  final String? categoryId;
  final String categoryName;
  final double confidence;
  final String reviewStatus; // 'auto', 'confirmed', 'needs_review'
  final String hash;
  final int? balance;
  final String? bankFormat;
  final String? notes;
  final String updatedAt; // ISO 8601 UTC timestamp for Last-Write-Wins
  final bool deleted; // Soft delete flag for sync propagation

  TransactionModel({
    required this.id,
    this.userId,
    required this.date,
    required this.amount,
    required this.direction,
    required this.rawDescription,
    required this.cleanMerchantName,
    this.categoryId,
    required this.categoryName,
    this.confidence = 1.0,
    this.reviewStatus = 'auto',
    required this.hash,
    this.balance,
    this.bankFormat,
    this.notes,
    String? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String();

  bool get isCredit => direction == 'credit';
  bool get isDebit => direction == 'debit';
  double get amountRupees => amount / 100.0;

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return '${isCredit ? "+" : "-"}${formatter.format(amountRupees)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'amount': amount,
      'direction': direction,
      'raw_description': rawDescription,
      'clean_merchant_name': cleanMerchantName,
      'category_id': categoryId,
      'category_name': categoryName,
      'confidence': confidence,
      'review_status': reviewStatus,
      'hash': hash,
      'balance': balance,
      'bank_format': bankFormat,
      'notes': notes,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date,
      'amount': amount,
      'direction': direction,
      'raw_description': rawDescription,
      'clean_merchant_name': cleanMerchantName,
      'category_id': categoryId,
      'category_name': categoryName,
      'confidence': confidence,
      'review_status': reviewStatus,
      'hash': hash,
      'balance': balance,
      'bank_format': bankFormat,
      'notes': notes,
      'updated_at': updatedAt,
      'deleted': deleted,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      date: map['date'] as String,
      amount: map['amount'] as int,
      direction: map['direction'] as String,
      rawDescription: map['raw_description'] as String,
      cleanMerchantName: map['clean_merchant_name'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      reviewStatus: (map['review_status'] as String?) ?? 'auto',
      hash: map['hash'] as String,
      balance: map['balance'] as int?,
      bankFormat: map['bank_format'] as String?,
      notes: map['notes'] as String?,
      updatedAt: map['updated_at'] as String? ??
          (map['date'] != null ? '${map['date']}T00:00:00.000Z' : DateTime.now().toUtc().toIso8601String()),
      deleted: map['deleted'] == 1 || map['deleted'] == true,
    );
  }

  TransactionModel copyWith({
    String? categoryName,
    String? categoryId,
    String? reviewStatus,
    double? confidence,
    String? userId,
    String? updatedAt,
    bool? deleted,
    String? notes,
  }) {
    return TransactionModel(
      id: id,
      userId: userId ?? this.userId,
      date: date,
      amount: amount,
      direction: direction,
      rawDescription: rawDescription,
      cleanMerchantName: cleanMerchantName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      confidence: confidence ?? this.confidence,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      hash: hash,
      balance: balance,
      bankFormat: bankFormat,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      deleted: deleted ?? this.deleted,
    );
  }
}
