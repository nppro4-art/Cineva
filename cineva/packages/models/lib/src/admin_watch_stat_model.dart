import 'package:equatable/equatable.dart';

class AdminWatchStatModel extends Equatable {
  const AdminWatchStatModel({
    required this.contentId,
    required this.contentType,
    required this.title,
    required this.totalEvents,
    required this.totalMinutes,
  });

  final String contentId;
  final String contentType;
  final String title;
  final int totalEvents;
  final int totalMinutes;

  @override
  List<Object?> get props => <Object?>[
        contentId,
        contentType,
        title,
        totalEvents,
        totalMinutes,
      ];
}
