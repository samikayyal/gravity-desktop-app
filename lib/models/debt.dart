class Debt {
  final int debtId;
  final String playerId;
  final String playerName;
  final int sessionId;
  final int amount;
  final DateTime createdAt;

  Debt({
    required this.debtId,
    required this.playerId,
    required this.playerName,
    required this.sessionId,
    required this.amount,
    required this.createdAt,
  });

  Debt.fromMap(Map<String, dynamic> map)
      : debtId = map['debt_id'] as int,
        playerId = map['player_id'] as String,
        playerName = map['player_name'] as String,
        sessionId = map['session_id'] as int,
        amount = map['amount'] as int,
        createdAt = DateTime.parse(map['created_at'] as String);

  Map<String, dynamic> toMap() {
    return {
      'debt_id': debtId,
      'player_id': playerId,
      'session_id': sessionId,
      'amount': amount,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
