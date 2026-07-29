import 'package:equatable/equatable.dart';

class AppFailure extends Equatable implements Exception {
  const AppFailure(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  List<Object?> get props => <Object?>[message, code, details];

  @override
  String toString() => 'AppFailure(code: $code, message: $message, details: $details)';
}
