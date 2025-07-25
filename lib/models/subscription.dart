class Subscription {
  final int subscriptionId;
  final String playerId;
  final String playerName;
  final List<String> phoneNumbers;
  final int totalMinutes;
  final int remainingMinutes;
  final DateTime startDate;
  final DateTime expiryDate;
  final String status; // 'active', 'expired', 'paused', 'finished'
  final int totalFee;
  final int amountPaid;
  final int discountPercent;

  Subscription({
    required this.subscriptionId,
    required this.playerId,
    required this.playerName,
    required this.phoneNumbers,
    required this.totalMinutes,
    required this.remainingMinutes,
    required this.startDate,
    required this.expiryDate,
    required this.status,
    required this.totalFee,
    required this.amountPaid,
    required this.discountPercent,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      subscriptionId: map['subscription_id'],
      playerId: map['player_id'],
      playerName: map['player_name'],
      totalMinutes: map['total_minutes'],
      remainingMinutes: map['remaining_minutes'],
      startDate: DateTime.parse(map['start_date']),
      expiryDate: DateTime.parse(map['expiry_date']),
      status: map['status'],
      totalFee: map['total_fee'],
      amountPaid: map['amount_paid'],
      phoneNumbers: List<String>.from(map['phone_numbers'] ?? []),
      discountPercent: map['discount_percent'] ?? 0,
    );
  }
}
