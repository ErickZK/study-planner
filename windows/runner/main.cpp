#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <filesystem>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kInstanceMutexName[] = L"Local\\TJSPPlannerMainWindow";
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

std::string RouteFromArguments(const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (argument.rfind("--study=", 0) == 0) {
      const auto value = argument.substr(8);
      const auto separator = value.find(':');
      if (separator != std::string::npos) {
        return "/study/" + value.substr(0, separator) + "/" +
               value.substr(separator + 1);
      }
    }
    if (argument.rfind("--open=", 0) == 0) {
      const auto route = argument.substr(7);
      return route.empty() ? "/" : route;
    }
  }
  return "/";
}

bool ActivateExistingWindow(const std::string& route) {
  HWND existing = FindWindowW(kWindowClassName, L"study_planner");
  if (existing == nullptr) return false;

  COPYDATASTRUCT message{};
  message.dwData = 1;
  message.cbData = static_cast<DWORD>(route.size() + 1);
  message.lpData = const_cast<char*>(route.c_str());
  SendMessageW(existing, WM_COPYDATA, 0,
               reinterpret_cast<LPARAM>(&message));
  if (IsIconic(existing)) ShowWindow(existing, SW_RESTORE);
  ShowWindow(existing, SW_SHOW);
  SetForegroundWindow(existing);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  if (std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--background") != command_line_arguments.end()) {
    wchar_t executable_path[MAX_PATH];
    const DWORD length = GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
    if (length > 0 && length < MAX_PATH) {
      const std::filesystem::path widget_path =
          std::filesystem::path(executable_path).parent_path() /
          L"taskbar_widget" / L"TJSP.Planner.TaskbarWidget.exe";
      std::wstring command = L"\"" + widget_path.wstring() + L"\"";
      STARTUPINFOW startup_info{};
      startup_info.cb = sizeof(startup_info);
      PROCESS_INFORMATION process_info{};
      if (CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                         CREATE_NO_WINDOW, nullptr, nullptr, &startup_info,
                         &process_info)) {
        CloseHandle(process_info.hThread);
        CloseHandle(process_info.hProcess);
      }
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  HANDLE instance_mutex = CreateMutexW(nullptr, FALSE, kInstanceMutexName);
  if (instance_mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
    const auto route = RouteFromArguments(command_line_arguments);
    for (int attempt = 0; attempt < 20; ++attempt) {
      if (ActivateExistingWindow(route)) break;
      Sleep(50);
    }
    CloseHandle(instance_mutex);
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"study_planner", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (instance_mutex != nullptr) CloseHandle(instance_mutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
