import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'download_manager.dart';
import 'update_controller.dart';
import 'update_platform.dart';
import 'update_policy.dart';

/// Full-screen page shown when an update is required.
///
/// When [canDismiss] is true it acts as a soft-update page with a skip
/// action; otherwise the user cannot proceed without updating.
class PrismForceUpdateScreen extends StatelessWidget {
  /// Creates the update screen.
  const PrismForceUpdateScreen({
    required this.state,
    this.canDismiss = false,
    this.onSkip,
    this.platformInfo,
    super.key,
  });

  /// The update state to render.
  final PrismUpdateAvailable state;

  /// Whether the user may skip the update.
  final bool canDismiss;

  /// Called when the user skips a dismissible update.
  final VoidCallback? onSkip;

  /// Platform info used to choose the action label/flow. Defaults to
  /// [PrismUpdatePlatformInfo.detect].
  final PrismUpdatePlatformInfo? platformInfo;

  void _launch(BuildContext context, Uri? url) {
    if (url == null) return;
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = platformInfo ?? PrismUpdatePlatformInfo.detect();
    final downloadUrl = state.downloadUrl;
    final actionLabel = platform.hasStoreFlow
        ? 'Update now'
        : downloadUrl != null
            ? 'Download latest version'
            : 'Check for updates';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                canDismiss ? 'A new version is available' : 'Update required',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                state.notes ??
                    (canDismiss
                        ? 'Update to version ${state.latest} for the latest '
                            'improvements.'
                        : 'This version is no longer supported. Please update '
                            'to continue using the app.'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () =>
                    _launch(context, downloadUrl ?? state.downloadUrl),
                child: Text(actionLabel),
              ),
              if (canDismiss) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Maybe later'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact dismissible card for optional updates.
class PrismSoftUpdateCard extends StatelessWidget {
  /// Creates the soft-update card.
  const PrismSoftUpdateCard({
    required this.state,
    this.onDismiss,
    this.platformInfo,
    super.key,
  });

  /// The update state to render.
  final PrismUpdateAvailable state;

  /// Called when the user dismisses the card.
  final VoidCallback? onDismiss;

  /// Platform info used to choose the action label/flow.
  final PrismUpdatePlatformInfo? platformInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = platformInfo ?? PrismUpdatePlatformInfo.detect();
    final downloadUrl = state.downloadUrl;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version ${state.latest} available',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (state.notes != null)
                    Text(
                      state.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                final url = downloadUrl;
                if (url != null) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(platform.hasStoreFlow ? 'Update' : 'Get'),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

/// Small inline widget showing an update-in-progress status.
class PrismUpdateProgress extends StatelessWidget {
  /// Creates the progress indicator.
  const PrismUpdateProgress({this.label = 'Checking for updates…', super.key});

  /// Label shown under the spinner.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Full-screen page with a live progress bar while a direct download runs.
///
/// Wraps `PrismDownloadManager.download` for a complete, branded download
/// experience on desktop/web flows.
class PrismDownloadScreen extends StatefulWidget {
  /// Creates the download screen.
  const PrismDownloadScreen({
    required this.url,
    required this.savePath,
    this.title = 'Downloading update',
    this.manager,
    this.onComplete,
    super.key,
  });

  /// The file to download.
  final Uri url;

  /// Where to save it.
  final String savePath;

  /// Headline shown above the progress bar.
  final String title;

  /// Override the manager (tests).
  final PrismDownloadManager? manager;

  /// Called with the terminal event.
  final ValueChanged<PrismDownloadEvent>? onComplete;

  @override
  State<PrismDownloadScreen> createState() => _PrismDownloadScreenState();
}

class _PrismDownloadScreenState extends State<PrismDownloadScreen> {
  PrismDownloadProgress? _progress;
  StreamSubscription<PrismDownloadEvent>? _sub;

  @override
  void initState() {
    super.initState();
    final manager = widget.manager ?? PrismDownloadManager();
    _sub = manager
        .download(url: widget.url, savePath: widget.savePath)
        .listen((event) {
      if (event is PrismDownloadProgress) {
        setState(() => _progress = event);
      } else {
        widget.onComplete?.call(event);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  String _label(PrismDownloadProgress progress) {
    final fraction = progress.fraction;
    final percent =
        fraction == null ? null : (fraction * 100).toStringAsFixed(0);
    final speed = (progress.bytesPerSecond / 1024).toStringAsFixed(0);
    return percent == null
        ? '$speed KB/s'
        : '$percent% · $speed KB/s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 24),
              if (progress == null || progress.isIndeterminate)
                const LinearProgressIndicator()
              else ...[
                LinearProgressIndicator(value: progress.fraction),
                const SizedBox(height: 8),
                Text(
                  _label(progress),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => unawaited(_sub?.cancel()),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only summary widget of any controller state, useful for debug pages.
class PrismUpdateStatusView extends StatelessWidget {
  /// Creates the status view.
  const PrismUpdateStatusView({required this.state, super.key});

  /// The state to summarize.
  final PrismUpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (state) {
      PrismUpdateIdle() => 'Not checked yet',
      PrismUpdateChecking() => 'Checking…',
      PrismUpdateUpToDate(:final latest) =>
        latest == null ? 'Up to date' : 'Up to date (latest $latest)',
      PrismUpdateAvailable(:final result, :final latest) =>
        latest == null
            ? 'Update available'
            : switch (result.decision) {
                UpdateDecision.forcedUpdate =>
                  'Update required — latest $latest',
                _ => 'Update available — latest $latest',
              },
      PrismUpdateSkipped() => 'Update skipped for now',
      PrismUpdateFailure(:final error) => 'Check failed: $error',
    };
    return Text(text, style: theme.textTheme.bodyMedium);
  }
}
