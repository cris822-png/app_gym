class ProgressEntry {
  final double peso;
  final String date;

  ProgressEntry({
    required this.peso,
    required this.date,
  });

  factory ProgressEntry.fromJson(Map<String, dynamic> json) {
    return ProgressEntry(
      peso: (json['peso'] as num).toDouble(),
      date: json['date'] as String,
    );
  }
}
