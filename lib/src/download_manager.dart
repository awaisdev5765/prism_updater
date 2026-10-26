import 'dart:async';
import 'dart:io';

/// Events emitted while a download is running.
sealed class PrismDownloadEvent {
  const PrismDownloadEvent();
}

/// Progress snapshot for a running download.
class PrismDownloadProgress extends PrismDownloadEvent {
  /// Creates a progress snapshot.
  const PrismDownloadProgress({
    required this.received,
    required this.total,
    required this.bytesPerSecond,
  });

  /// Bytes received so far.
  final int received;

  /// Total bytes, or `-1` when the server did not send a content length.
  final int total;

  /// Measured throughput in bytes/second over the recent window.
  final double bytesPerSecond;

  /// Progress as a 0..1 fraction; `null` when the total is unknown.
  double? get fraction =>
      total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  /// Whether the total size is known.
  bool get isIndeterminate => total <= 0;
}

/// Terminal event: download completed; [file] points at the saved artifact.
class PrismDownloadComplete extends PrismDownloadEvent {
  /// Creates a completion event.
  const PrismDownloadComplete(this.file, {required this.bytes});

  /// The downloaded file.
  final File file;

  /// Total bytes written.
  final int bytes;
}

/// Terminal event: download failed.
class PrismDownloadFailed extends PrismDownloadEvent {
  /// Creates a failure event.
  const PrismDownloadFailed(this.error, [this.stackTrace]);

  /// The error that caused the failure.
  final Object error;

  /// Optional stack trace.
  final StackTrace? stackTrace;
}

/// Terminal event: download was cancelled by the caller.
class PrismDownloadCancelled extends PrismDownloadEvent {
  /// Creates a cancellation event.
  const PrismDownloadCancelled();
}

/// Streams a file to disk with progress reporting and cancellation.
///
/// Used for direct downloads on platforms without a store flow
/// (Windows, macOS, Linux, web-style links). Pure Dart — works everywhere.
///
/// ```dart
/// final manager = PrismDownloadManager();
/// await for (final event in manager.download(
///   url: Uri.parse('https://example.com/app.exe'),
///   savePath: '/tmp/app.exe',
/// )) {
///   if (event is PrismDownloadProgress) {
///     print('${(event.fraction ?? 0) * 100}%');
///   } else if (event is PrismDownloadComplete) {
///     print('saved to ${event.file.path}');
///   }
/// }
/// ```
class PrismDownloadManager {
  /// Creates a download manager. [client] is injectable for tests.
  PrismDownloadManager({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Set<StreamSubscription<List<int>>> _active = {};

  /// Streams [url] into [savePath], emitting [PrismDownloadProgress] events
  /// on every chunk and exactly one terminal event at the end.
  ///
  /// Cancelling the subscription cancels the HTTP response and stops writing.
  Stream<PrismDownloadEvent> download({
    required Uri url,
    required String savePath,
    Duration throughputWindow = const Duration(seconds: 1),
  }) async* {
    IOSink? sink;
    StreamSubscription<List<int>>? responseSub;

    try {
      final request = await _client.getUrl(url);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield PrismDownloadFailed(
          HttpException('Download failed (${response.statusCode})', uri: url),
        );
        return;
      }

      final total = response.contentLength == -1 ? -1 : response.contentLength;
      final file = File(savePath);
      await file.parent.create(recursive: true);
      sink = file.openWrite();

      var received = 0;
      var windowBytes = 0;
      var speed = 0.0;
      final windowSw = Stopwatch()..start();
      final windowSeconds = throughputWindow.inMilliseconds / 1000;

      // Bridge response chunks through a controller so that cancelling the
      // generator's subscription cancels the underlying HTTP response.
      final chunks = StreamController<List<int>>();
      responseSub = response.listen(
        chunks.add,
        onError: chunks.addError,
        onDone: chunks.close,
        cancelOnError: true,
      );
      _active.add(responseSub);

      await for (final chunk in chunks.stream) {
        received += chunk.length;
        windowBytes += chunk.length;
        final elapsed = windowSw.elapsedMicroseconds / 1e6;
        if (elapsed >= windowSeconds && elapsed > 0) {
          speed = windowBytes / elapsed;
          windowBytes = 0;
          windowSw.reset();
        }
        sink.add(chunk);
        yield PrismDownloadProgress(
          received: received,
          total: total,
          bytesPerSecond: speed,
        );
      }

      await sink.flush();
      await sink.close();
      yield PrismDownloadComplete(file, bytes: received);
    } catch (e, st) {
      yield PrismDownloadFailed(e, st);
    } finally {
      if (responseSub != null) {
        _active.remove(responseSub);
        unawaited(responseSub.cancel());
      }
      try {
        await sink?.close();
      } catch (_) {
        // Best-effort cleanup; the terminal event already reported status.
      }
    }
  }

  /// Cancels all active downloads.
  void cancelAll() {
    for (final sub in List.of(_active)) {
      unawaited(sub.cancel());
    }
    _active.clear();
  }

  /// Closes the manager and its client.
  void close() {
    cancelAll();
    _client.close(force: true);
  }
}
