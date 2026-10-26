#ifndef FLUTTER_PLUGIN_PRISM_UPDATER_PLUGIN_H_
#define FLUTTER_PLUGIN_PRISM_UPDATER_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

namespace prism_updater {

class PrismUpdaterPlugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PrismUpdaterPlugin();
};

}  // namespace prism_updater

#endif  // FLUTTER_PLUGIN_PRISM_UPDATER_PLUGIN_H_
