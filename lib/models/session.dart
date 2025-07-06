class Session {
  final int sessionId;
  final String playerId;
  final String playerName;
  final DateTime checkInTime;
  final DateTime checkOutTime;
  final int finalFee;
  final int amountPaid;

  // subs
  final int? subscriptionId;
  final int? minutesUsed;

  Session({
    required this.sessionId,
    required this.playerId,
    required this.playerName,
    required this.checkInTime,
    required this.checkOutTime,
    required this.finalFee,
    required this.amountPaid,
    this.subscriptionId,
    this.minutesUsed,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['session_id'] as int,
      playerId: map['id'] as String,
      playerName: map['name'] as String,
      checkInTime: DateTime.parse(map['check_in_time'] as String),
      checkOutTime: DateTime.parse(map['check_out_time'] as String),
      finalFee: map['final_fee'] as int,
      amountPaid: map['amount_paid'] as int,
      subscriptionId: map['subscription_id'] as int?,
      minutesUsed: map['minutes_used'] as int?,
    );
  }
}
