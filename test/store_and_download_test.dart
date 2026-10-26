import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_updater/prism_updater.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoreFlowLauncher', () {
    test('returns unavailable when the native side is missing', () async {
      final launcher = StoreFlowLauncher();
      expect(await launcher.launch(), StoreLaunchResult.unavailable);
    });

    test('maps launched result', () async {
      final channel = MethodChannel('prism_updater/store_flow_test_launched');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'launched');
      final launcher = StoreFlowLauncher(methodChannel: channel);
      expect(await launcher.launch(), StoreLaunchResult.launched);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps failed result', () async {
      final channel = MethodChannel('prism_updater/store_flow_test_failed');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => 'failed');
      final launcher = StoreFlowLauncher(methodChannel: channel);
      expect(await launcher.launch(), StoreLaunchResult.failed);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('passes the iOS apple id through', () async {
      String? receivedAppleId;
      final channel = MethodChannel('prism_updater/store_flow_test_args');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        receivedAppleId = call.arguments?['appleId'] as String?;
        return 'launched';
      });
      final launcher = StoreFlowLauncher(
        methodChannel: channel,
        iosAppleId: '123456789',
      );
      await launcher.launch();
      expect(receivedAppleId, '123456789');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('PrismDownloadManager', () {
    HttpOverrides? previousOverrides;
    late HttpServer server;
    late String serverUrlBase;

    setUp(() async {
      previousOverrides = HttpOverrides.current;
      HttpOverrides.global = _RealHttpOverrides();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrlBase = 'http://localhost:${server.port}';
      server.listen((request) async {
        final bytes = List.generate(64, (i) => i);
        request.response.headers.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      });
    });

    tearDown(() {
      HttpOverrides.global = previousOverrides;
      server.close(force: true);
    });

    test('streams progress and completes', () async {
      final manager = PrismDownloadManager();
      final savePath =
          '${Directory.systemTemp.path}/prism_updater_test_${DateTime.now().millisecondsSinceEpoch}.bin';
      final events = <PrismDownloadEvent>[];

      await for (final event in manager.download(
        url: Uri.parse('$serverUrlBase/file.bin'),
        savePath: savePath,
      )) {
        events.add(event);
      }

      expect(events.last, isA<PrismDownloadComplete>());
      final complete = events.last as PrismDownloadComplete;
      expect(complete.bytes, 64);
      expect(complete.file.existsSync(), isTrue);
      expect(complete.file.lengthSync(), 64);
      expect(events.whereType<PrismDownloadProgress>(), isNotEmpty);
      manager.close();
      File(savePath).deleteSync();
    });

    test('reports failure on server error', () async {
      await server.close(force: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrlBase = 'http://localhost:${server.port}';
      server.listen((request) async {
        request.response.statusCode = 500;
        await request.response.close();
      });

      final manager = PrismDownloadManager();
      final events = <PrismDownloadEvent>[];
      await for (final event in manager.download(
        url: Uri.parse('$serverUrlBase/file.bin'),
        savePath:
            '${Directory.systemTemp.path}/prism_updater_fail.bin',
      )) {
        events.add(event);
      }
      expect(events.single, isA<PrismDownloadFailed>());
      manager.close();
    });
  });
}
