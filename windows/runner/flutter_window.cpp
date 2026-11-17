#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  navigation_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "tjsp_planner/navigation",
          &flutter::StandardMethodCodec::GetInstance());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Open the Planner maximized in the monitor work area. SW_MAXIMIZE keeps
    // the Windows taskbar visible, unlike a borderless fullscreen window.
    // The first ShowWindow call can be overridden by STARTUPINFO (for example
    // when launched from a shortcut or PowerShell). Consume that state first,
    // then explicitly maximize so startup is deterministic.
    ShowWindow(this->GetHandle(), SW_SHOW);
    ShowWindow(this->GetHandle(), SW_MAXIMIZE);
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  navigation_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (data == nullptr || data->dwData != 1 || data->lpData == nullptr ||
          data->cbData == 0) {
        break;
      }
      const auto* route = static_cast<const char*>(data->lpData);
      const size_t length = strnlen(route, data->cbData);
      if (navigation_channel_) {
        navigation_channel_->InvokeMethod(
            "openRoute", std::make_unique<flutter::EncodableValue>(
                             std::string(route, length)));
      }
      if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
      ShowWindow(hwnd, SW_SHOW);
      SetForegroundWindow(hwnd);
      return TRUE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
