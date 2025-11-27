// dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:mydatatools/main.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PythonManager {
  Process? _pythonProc;
  Process? _pipProc;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  final StreamController<String> _stdoutController =
      StreamController.broadcast();
  final StreamController<String> _stderrController =
      StreamController.broadcast();

  String? _pythonDir;
  static ValueNotifier<bool> isLLMServiceRunning = ValueNotifier(false);

  PythonManager._();

  /// Create manager for `supportDir/flet/app`.
  static Future<PythonManager> forAppSupport() async {
    final mgr = PythonManager._();
    return mgr;
  }

  Stream<String> get stdoutLines => _stdoutController.stream;
  Stream<String> get stderrLines => _stderrController.stream;

  bool get isRunning => _pythonProc != null;

  Future<void> startAiChatService() async {
    // Use a completer to ensure the aichat assets are available before proceeding.
    Completer<void> completer = Completer<void>();

    // Ensure bundled aichat assets are available in Application Support before proceeding.
    await ensureAichatUnzipped().then((_) => completer.complete());

    final supportDir = await getApplicationSupportDirectory();
    _pythonDir = p.join(supportDir.path, "aichat/aichat");

    // Check for existing PID file and kill previous process if it exists
    final pidFile = File(p.join(_pythonDir!, 'aichat.pid'));
    if (pidFile.existsSync()) {
      try {
        final oldPid = int.parse(pidFile.readAsStringSync().trim());
        debugPrint('[python] Found existing PID file with PID: $oldPid');
        if (Process.killPid(oldPid, ProcessSignal.sigkill)) {
          debugPrint('[python] Successfully killed old process $oldPid');
        } else {
          debugPrint(
            '[python] Failed to kill old process $oldPid (might not be running)',
          );
        }
      } catch (e) {
        debugPrint('[python] Error handling existing PID file: $e');
      }
    }

    debugPrint('[python] Starting AI Chat service in `$_pythonDir`');
    debugPrint('[python] Starting AI Chat service in `$_pythonDir`');

    String executableName = 'aichat';
    if (Platform.isWindows) {
      executableName = 'aichat.exe';
    }

    final executablePath = p.join(_pythonDir!, executableName);

    if (!File(executablePath).existsSync()) {
      _stderrController.add('Python executable not found at $executablePath');
      return;
    }

    // Ensure executable permission on Unix-like systems
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', executablePath]);
    }

    try {
      print("Starting AI Chat service...");
      _pythonProc = await Process.start(
        executablePath,
        [],
        workingDirectory: _pythonDir,
        environment: {
          'HF_TOKEN': '', //todo pass from client
          'GOOGLE_API_KEY': '', //todo pass from client
          'MODEL_DOWNLOAD_URL':
              'https://gcs-file-downloader-10805446439.us-central1.run.app', // todo get from remote config
        },
      );

      // Write new PID to file
      try {
        pidFile.writeAsStringSync('${_pythonProc!.pid}');
        debugPrint('[python] Wrote PID ${_pythonProc!.pid} to ${pidFile.path}');
      } catch (e) {
        debugPrint('[python] Failed to write PID file: $e');
      }

      await _pipeOutput(_pythonProc!);

      //Start default session
      MainApp.llmServiceUrl.listen((llmServiceUrl) async {
        if (llmServiceUrl != null) {
          final session = await http.post(
            Uri.parse("$llmServiceUrl/start-session"),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, dynamic>{
              "model_name": "google/gemma-3-4b-it",
            }),
          );
          debugPrint(
            'Started default session: ${session.statusCode} ${session.body}',
          );
        }
      });

      stdoutLines.listen((line) {
        debugPrint('[python] $line');
      });

      final urlRegex = RegExp(r'(http?:\/\/[^\s]+)');
      stderrLines.listen((line) {
        debugPrint('[python] $line');
        final match = urlRegex.firstMatch(line);
        if (match != null) {
          final url = match.group(1);
          if (url != null) {
            debugPrint('[python] AI Chat service is running at: $url');
            // Store this URL in a variable for later use.
            MainApp.llmServiceUrl.add(url);
            isLLMServiceRunning.value = true;
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        }
      });
    } catch (e) {
      _stderrController.add('Failed to start AI Chat service: $e');
      completer.completeError(e);
    }

    return completer.future;
  }

  Future<void> stopAiChatService() async {
    // stop python proc first
    if (_pythonProc != null) {
      try {
        _pythonProc!.kill(ProcessSignal.sigterm);
        await _pythonProc!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => -1,
        );
      } catch (_) {}
      _pythonProc = null;
    }
    if (_pipProc != null) {
      try {
        _pipProc!.kill(ProcessSignal.sigterm);
        await _pipProc!.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () => -1,
        );
      } catch (_) {}
      _pipProc = null;
    }

    // Cleanup PID file
    if (_pythonDir != null) {
      try {
        final pidFile = File(p.join(_pythonDir!, 'aichat.pid'));
        if (pidFile.existsSync()) {
          pidFile.deleteSync();
          debugPrint('[python] Deleted PID file');
        }
      } catch (e) {
        debugPrint('[python] Error deleting PID file: $e');
      }
    }

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
  }

  /// Ensure the bundled aichat zip is unzipped into Application Support/aichat.
  /// If the destination directory already exists, this is a no-op.
  Future<void> ensureAichatUnzipped() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final destDir = Directory(p.join(supportDir.path, 'aichat'));

      if (destDir.existsSync()) {
        _stdoutController.add(
          'aichat directory already exists at ${destDir.path}; skipping unzip.',
        );
        return;
      }

      String zipName = 'aichat.zip';
      if (Platform.isMacOS) {
        zipName = 'aichat-macos.zip';
      } else if (Platform.isWindows) {
        zipName = 'aichat-windows.zip';
      } else if (Platform.isLinux) {
        zipName = 'aichat-linux.zip';
      }

      // Candidate locations for the zip file in common run contexts
      final candidates =
          <String>[
            // when running from the project root
            p.join(Directory.current.path, 'app', zipName),
            // fallback to generic name
            p.join(Directory.current.path, 'app', 'aichat.zip'),
            // when running from a built executable next to an `app` folder
            p.join(p.dirname(Platform.resolvedExecutable), 'app', zipName),
            p.join(p.dirname(Platform.resolvedExecutable), 'app', 'aichat.zip'),
            // inside a macOS .app bundle Resources folder
            p.join(
              p.dirname(Platform.resolvedExecutable),
              '..',
              'Resources',
              'app',
              zipName,
            ),
            p.join(
              p.dirname(Platform.resolvedExecutable),
              '..',
              'Resources',
              'app',
              'aichat.zip',
            ),
          ].map((s) => p.normalize(s)).toList();

      String? zipPath;
      for (final c in candidates) {
        if (File(c).existsSync()) {
          zipPath = c;
          break;
        }
      }

      if (zipPath == null) {
        _stderrController.add(
          'aichat zip not found. Searched: ${candidates.join(', ')}',
        );
        return;
      }

      _stdoutController.add('Unzipping `$zipPath` -> `${destDir.path}`');
      destDir.createSync(recursive: true);

      if (Platform.isWindows) {
        // On Windows, use PowerShell to expand the archive
        final result = await Process.run('powershell', [
          '-command',
          'Expand-Archive -Path "$zipPath" -DestinationPath "${destDir.path}" -Force',
        ]);
        if (result.exitCode != 0) {
          _stderrController.add(
            'Expand-Archive failed (exit ${result.exitCode}): ${result.stderr}',
          );
        } else {
          _stdoutController.add('Unzip completed via PowerShell');
        }
      } else {
        // Use system `unzip` for macOS/Linux
        final result = await Process.run('unzip', [
          '-o',
          zipPath,
          '-d',
          destDir.path,
        ]);
        if (result.exitCode != 0) {
          _stderrController.add(
            'unzip failed (exit ${result.exitCode}): ${result.stderr}',
          );
        } else {
          final out = (result.stdout ?? '').toString();
          _stdoutController.add('Unzip completed: ${out.trim()}');
        }
      }
    } catch (e) {
      _stderrController.add('Exception while unzipping aichat bundle: $e');
    }
  }

  Future<void> dispose() async {
    await stopAiChatService();
    await _stdoutController.close();
    await _stderrController.close();
  }

  Future<void> _pipeOutput(Process proc) async {
    _stdoutSub = proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_stdoutController.add);
    _stderrSub = proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_stderrController.add);
    proc.exitCode.then((code) {
      _stdoutController.add('Python exited with code $code');
      // cleanup references when it exits
      _pythonProc = null;
    });
  }

  /**
  Future<void> diagnoseAndStartPython() async {
    final pythonDir = _pythonDir;
    if (pythonDir == null) {
      _stderrController.add('pythonDir not initialized');
      return;
    }

    // Ensure bundled aichat assets are available in Application Support before proceeding.
    await ensureAichatUnzipped();

    if (!Directory(pythonDir).existsSync()) {
      _stderrController.add('Directory not found: `$pythonDir`');
      return;
    }

    final venvPython = p.join(pythonDir, '.venv', 'bin', 'python3');
    final mainPy = p.join(pythonDir, 'main.py');

    if (!File(mainPy).existsSync()) {
      _stderrController.add('`main.py` not found in `$pythonDir`');
      return;
    }

    String pythonExe = 'python3'; // fallback
    if (File(venvPython).existsSync()) {
      final stat = FileStat.statSync(venvPython);
      final hasExec = (stat.mode & 0x111) != 0;
      _stdoutController.add('venv python mode: ${stat.mode.toRadixString(8)} exec? $hasExec');

      if (!hasExec) {
        try {
          final chmod = await Process.run('chmod', ['+x', venvPython]);
          if (chmod.exitCode == 0) {
            _stdoutController.add('Made `$venvPython` executable');
            if ((FileStat.statSync(venvPython).mode & 0x111) != 0) {
              pythonExe = venvPython;
            }
          } else {
            _stderrController.add('chmod failed: ${chmod.stderr}');
          }
        } catch (e) {
          _stderrController.add('chmod exception: $e');
        }
        if (pythonExe != venvPython) {
          _stdoutController.add('Falling back to system `python3`');
        }
      } else {
        pythonExe = venvPython;
      }
    } else {
      _stdoutController.add('venv python not found; using system `python3`');
    }

    final isInAppBundle = Platform.resolvedExecutable.contains('.app');
    if (isInAppBundle) {
      _stdoutController.add('App appears to be running from a `.app` bundle. Packaged/sandboxed apps may be prevented from spawning processes or accessing some paths.');
    }

    try {
      // optional: install requirements first
      _pipProc = await Process.start(
        pythonExe,
        ['-m', 'pip', 'install', '-r', 'requirements.txt'],
        workingDirectory: pythonDir,
        runInShell: false,
      );
      _pipProc!.stdout.transform(utf8.decoder).listen((d) => _stdoutController.add('PIP: $d'));
      _pipProc!.stderr.transform(utf8.decoder).listen((d) => _stderrController.add('PIP ERR: $d'));
      final pipExit = await _pipProc!.exitCode;
      if (pipExit != 0) _stderrController.add('pip install exit code $pipExit');

      // start python app
      _pythonProc = await Process.start(
        pythonExe,
        ['main.py'],
        workingDirectory: pythonDir,
        runInShell: false,
      );
      await _pipeOutput(_pythonProc!);
      _stdoutController.add('Python server process started.');
    } catch (e) {
      _stderrController.add('Failed to start python process: $e');
    }
  }
**/
}
