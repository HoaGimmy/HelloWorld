# POSE STUDIO iOS

This directory contains a native SwiftUI camera posing app.

GitHub Actions builds the unsigned iOS application using XcodeGen and packages an IPA artifact on pushes to `pose-studio-ios`.

Find the artifact in **Actions → Build POSE STUDIO IPA → POSEStudio_unsigned_ipa** after a successful run. The unsigned IPA requires code signing before installation on a physical iPhone.

This branch is isolated from the CRM source on `main`.
