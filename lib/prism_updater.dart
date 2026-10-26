/// In-app update experience for Flutter.
///
/// Part of the Prism package family:
///
/// - [prism_markdown](https://pub.dev/packages/prism_markdown)
/// - [prism_code_view](https://pub.dev/packages/prism_code_view)
/// - [prism_adaptive_scaffold](https://pub.dev/packages/prism_adaptive_scaffold)
/// - [prism_adaptive_dialog](https://pub.dev/packages/prism_adaptive_dialog)
/// - [prism_state_views](https://pub.dev/packages/prism_state_views)
/// - [prism_master_detail](https://pub.dev/packages/prism_master_detail)
/// - [prism_banner](https://pub.dev/packages/prism_banner)
/// - [prism_search](https://pub.dev/packages/prism_search)
/// - [prism_toast](https://pub.dev/packages/prism_toast)
/// - [prism_pagination](https://pub.dev/packages/prism_pagination)
/// - [prism_form](https://pub.dev/packages/prism_form)
library;

export 'src/version.dart' show PrismVersion, PrismVersionException;
export 'src/update_policy.dart'
    show UpdatePolicy, UpdatePolicyResult, UpdateDecision, UpdateChannel;
export 'src/update_source.dart'
    show PrismUpdateSource, RemoteUpdateSource, StaticUpdateSource;
export 'src/update_controller.dart'
    show
        PrismUpdateController,
        PrismUpdateState,
        PrismUpdateIdle,
        PrismUpdateChecking,
        PrismUpdateUpToDate,
        PrismUpdateAvailable,
        PrismUpdateSkipped,
        PrismUpdateFailure;
export 'src/update_gate.dart' show PrismUpdateGate, GateBehavior;
export 'src/update_screens.dart'
    show
        PrismForceUpdateScreen,
        PrismSoftUpdateCard,
        PrismUpdateProgress,
        PrismUpdateStatusView;
export 'src/update_platform.dart' show PrismUpdatePlatformInfo;
export 'src/download_manager.dart'
    show
        PrismDownloadManager,
        PrismDownloadEvent,
        PrismDownloadProgress,
        PrismDownloadComplete,
        PrismDownloadFailed,
        PrismDownloadCancelled;
export 'src/store_flow.dart' show StoreFlowLauncher, StoreLaunchResult;
export 'src/skip_store.dart' show PrismSkipStore;
