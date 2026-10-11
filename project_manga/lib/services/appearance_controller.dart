import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class AppearanceController extends ValueNotifier<int> {
  AppearanceController() : super(0);
  bool _updateScheduled = false;

  void cycle() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      value = (value + 1) % 3;
    });
  }
}

final appearanceController = AppearanceController();
