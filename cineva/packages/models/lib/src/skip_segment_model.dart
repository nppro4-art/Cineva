import 'package:equatable/equatable.dart';

/// Un intervalle de temps à passer pendant la lecture (générique,
/// publicité, scène coupée…).
///
/// Représenté côté base / JSON sous la forme `[début, fin]` (secondes)
/// ou `{"start": début, "end": fin}`.
class SkipSegment extends Equatable {
  const SkipSegment({
    required this.startSeconds,
    required this.endSeconds,
  });

  /// Tolère les formats `[start, end]`, `{"start", "end"}` et
  /// `{"startSeconds", "endSeconds"}`. Un payload illisible produit un
  /// segment invalide (filtré en aval) plutôt qu'une exception.
  factory SkipSegment.fromJson(dynamic raw) {
    int _toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    if (raw is List && raw.length >= 2) {
      return SkipSegment(startSeconds: _toInt(raw[0]), endSeconds: _toInt(raw[1]));
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return SkipSegment(
        startSeconds: _toInt(map['startSeconds'] ?? map['start']),
        endSeconds: _toInt(map['endSeconds'] ?? map['end']),
      );
    }
    return const SkipSegment(startSeconds: 0, endSeconds: 0);
  }

  /// Début du segment, en secondes depuis le début du média.
  final int startSeconds;

  /// Fin du segment, en secondes depuis le début du média.
  final int endSeconds;

  /// Un segment valide a un début positif ou nul et une fin strictement
  /// après le début.
  bool get isValid => startSeconds >= 0 && endSeconds > startSeconds;

  int get durationSeconds => endSeconds - startSeconds;

  /// `true` si [positionSeconds] tombe dans `[startSeconds, endSeconds)`.
  bool containsPosition(int positionSeconds) =>
      isValid && positionSeconds >= startSeconds && positionSeconds < endSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start': startSeconds,
        'end': endSeconds,
      };

  List<int> toList() => <int>[startSeconds, endSeconds];

  @override
  List<Object?> get props => <Object?>[startSeconds, endSeconds];
}
