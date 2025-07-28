import 'package:flutter/material.dart';

const Color gravityYellow = Color(0xfffbf306);
const Color mainBlue = Color(0xFF3949AB);
const int leewayMinutes = 10;
const double fuzzyThreshold = 0.5;
const int maxPlayersInGroup = 30;
const int minDatesForDailyBuckets = 5;
const int minDatesForWeeklyBuckets = 30;
const int minDatesForMonthlyBuckets = 360;

const Color playersLineChartColor = Colors.lightBlueAccent;
const Color productsLineChartColor = Colors.deepOrange;

final List<Color> groupColors = [
  // Reds & Pinks
  Colors.red.shade400,
  Colors.pink.shade300,
  Colors.purple.shade400,
  Colors.deepPurple.shade400,

  // Blues
  Colors.indigo.shade400,
  Colors.blue.shade500,
  Colors.lightBlue.shade300,
  Colors.cyan.shade400,

  // Greens
  Colors.teal.shade400,
  Colors.green.shade500,
  Colors.lightGreen.shade600,
  Colors.lime.shade700,

  // Yellows & Oranges
  Colors.yellow.shade700,
  Colors.amber.shade600,
  Colors.orange.shade500,
  Colors.deepOrange.shade400,

  // Neutrals & Others
  Colors.brown.shade400,
  Colors.grey.shade600,
  Colors.blueGrey.shade400,

  // Adding a few more distinct shades to reach 24
  Colors.red.shade800,
  Colors.green.shade900,
  Colors.blue.shade800,
  Colors.purple.shade700,
  Colors.orange.shade900,
];
