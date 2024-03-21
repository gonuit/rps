import 'package:meta/meta.dart';
import 'package:rps/rps.dart';

@immutable
abstract class ExecutionEvent {
  Context get context;
  String get path;
  String? get command;
}
