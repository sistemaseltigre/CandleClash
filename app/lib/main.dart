import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_logger.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogger.error('FlutterError', details.exception, details.stack);
      };
      runApp(const CandleClashApp());
    },
    (error, stack) {
      AppLogger.error('Uncaught zone error', error, stack);
    },
  );
}
