package com.prism.updater

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * Flutter plugin entry point that registers the native store-flow handler.
 *
 * Apps embedding prism_updater as a source dependency add this to their
 * FlutterEngine plugins list; as a published plugin it is registered
 * automatically via the plugin declaration in pubspec.yaml.
 */
class PrismUpdaterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AppContextHolder.context = binding.applicationContext
        StoreFlowHandler.register(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AppContextHolder.context = null
    }
}
