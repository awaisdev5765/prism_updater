#include "include/prism_updater/prism_updater_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <shellapi.h>
#include <memory>
#include <string>

namespace prism_updater {

// Windows has no store flow; updates go through direct download URLs.
// The channel responds "unavailable" so Dart-side falls back gracefully.
void PrismUpdaterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "prism_updater/store_flow",
      &flutter::StandardMethodCodec::GetInstance());

  auto *channel_ptr = channel.get();
  channel->SetMethodCallHandler(
      [channel_ptr](const auto &call, auto result) {
        if (call.method_name().compare("launchStore") == 0) {
          result(flutter::EncodableValue(std::string("unavailable")));
        } else {
          result->NotImplemented();
        }
      });

  registrar->AddPlugin(std::make_unique<PrismUpdaterPlugin>());
}

PrismUpdaterPlugin::PrismUpdaterPlugin() {}

}  // namespace prism_updater
