class ProgressEntry {
  final double peso;
  final String date;
  final String objetivo;

  ProgressEntry({
    required this.peso,
    required this.date,
    required this.objetivo,
  });

  factory ProgressEntry.fromJson(Map<String, dynamic> json) {
    return ProgressEntry(
      peso: (json['peso'] as num).toDouble(),
      date: json['date'] as String,
      objetivo: json['objetivo'] as String,
    );
  }
}
