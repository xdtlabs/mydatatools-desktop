import 'dart:isolate';

import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart' as p;

class ConcisePrinter extends LogPrinter {
  final PrettyPrinter _errorPrinter = PrettyPrinter(methodCount: 8, errorMethodCount: 8, lineLength: 120, colors: true, printEmojis: true, printTime: false);

  static final levelEmojis = {
    Level.verbose: '🐱',
    Level.debug: '🐛',
    Level.info: '💡',
    Level.warning: '⚠️',
    Level.error: '⛔',
    Level.wtf: '👾',
  };

  @override
  List<String> log(LogEvent event) {
    if (event.level == Level.error || event.level == Level.warning || event.level == Level.wtf) {
      return _errorPrinter.log(event);
    }

    final String emoji = levelEmojis[event.level] ?? '';
    final String message = event.message.toString();
    
    // Extract call site
    String callSite = "";
    try {
      final stackTrace = StackTrace.current.toString().split('\n');
      // print('STACK TRACE: $stackTrace');
      // We need to find the first frame outside of logger/app_logger
      for (var frame in stackTrace) {
        // print('FRAME: $frame');
        if (!frame.contains('app_logger.dart') && !frame.contains('package:logger')) {
          // Format of frame is usually: #N   ClassName.MethodName (package:path/to/file.dart:line:col) or (file:///path/to/file.dart:line:col)
          final match = RegExp(r'\(((?:package|file):.*)\)').firstMatch(frame);
          if (match != null) {
            callSite = match.group(1) ?? "";
            // Clean up the path to be more concise
            if (callSite.contains('package:mydatatools/')) {
              callSite = callSite.replaceAll('package:mydatatools/', '');
            } else if (callSite.contains('file:///')) {
               callSite = p.basename(callSite);
            }
            break;
          }
        }
      }
    } catch (e) {
      // ignore
    }

    return ['│ $emoji [$callSite] $message'];
  }
}

class AppLogger extends Logger {
  SendPort? sendPort;

  AppLogger(SendPort? sendPort_, {LogFilter? filter}) : super(printer: ConcisePrinter(), filter: filter) {
    sendPort = sendPort_;
  }

  static PublishSubject<String> statusSubject = PublishSubject<String>();

  void s(dynamic message) async {
    //If we are in an Isolate we'll send the message out over the port and let the parent log it.
    if (sendPort != null) {
      sendPort!.send(message);
    } else {
      statusSubject.add(message);
    }
  }
}
