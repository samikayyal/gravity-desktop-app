class Player {
  final String playerID; // UUID
  final String name;
  final int age;
  final DateTime checkInTime;
  final int amountOwed;
  final int amountPaid;
  final int sessionID; // For the current player's session

  Player({
    required this.playerID,
    required this.name,
    required this.age,
    required this.checkInTime,
    required this.amountOwed,
    required this.amountPaid,
    required this.sessionID,
  });

  // Factory constructor to create a Player from a map
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerID: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      checkInTime: DateTime.parse(map['check_in_time'] as String),
      amountOwed: map['amount_owed'] as int,
      amountPaid: map['amount_paid'] as int,
      sessionID: map['session_id'] as int,
    );
  }
}
