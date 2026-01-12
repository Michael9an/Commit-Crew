import 'package:event_app/models/event.dart';
import 'package:event_app/models/register.dart';

class ParticipationActivity {
  final DateTime date;
  final String type; // 'Registration', 'Attend'
  final Register registration;
  final EventModel? event;

  ParticipationActivity({
    required this.date,
    required this.type,
    required this.registration,
    this.event,
  });
}
