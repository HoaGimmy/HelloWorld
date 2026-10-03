# MPWindows CRM — Native iOS integration

This folder contains the native iOS layer used by the Flutter CRM.

## Features

- Native local notifications through `UserNotifications`.
- Appointment reminders 30 minutes before the appointment.
- Task reminders at 09:00 on the due date.
- Home Screen widget built with WidgetKit/SwiftUI.
- Shared widget snapshot through App Group `group.vn.mpwindows.crm`.
- Flutter ↔ Swift bridge through `vn.mpwindows.crm/native`.

## Generate/configure iOS locally

From the repository root:

```bash
flutter create --platforms=ios .
flutter pub get
ruby -e "require 'xcodeproj'" || gem install xcodeproj --no-document
ruby native/ios/setup_native.rb
open ios/Runner.xcworkspace
```

The setup script copies the native sources into the generated Flutter iOS project,
adds the WidgetKit extension target, embeds it in Runner, and configures the App
Group entitlements.

## Apple Developer signing requirement

Before installing a signed build on a physical iPhone, register the App Group
`group.vn.mpwindows.crm` in the Apple Developer account and enable it for both
the Runner App ID and the widget extension App ID. Regenerate provisioning
profiles after enabling the capability.

The GitHub Actions workflow builds without code signing to validate compilation.
