class Player {
  final String playerID; // UUID
  final String name;
  final int age;
  final DateTime checkInTime;
  final Duration timeReserved;
  final bool isOpenTime;
  int amountPaid;
  int sessionID; // For the current player's session

  Player({
    required this.playerID,
    required this.name,
    required this.age,
    required this.checkInTime,
    required this.timeReserved,
    required this.amountPaid,
    required this.sessionID,
    required this.isOpenTime,
  });

  // Factory constructor to create a Player from a map
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerID: map['id'] as String,
      name: map['name'] as String,
      age: map['age'] as int,
      checkInTime: DateTime.parse(map['check_in_time'] as String),
      timeReserved: Duration(
        hours: map['time_reserved_hours'] as int,
        minutes: map['time_reserved_minutes'] as int,
      ),
      isOpenTime: map['is_open_time'] == 1,
      amountPaid: map['amount_paid'] as int,
      sessionID: map['session_id'] as int,
    );
  }
}
