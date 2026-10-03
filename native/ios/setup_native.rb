#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
IOS = File.join(ROOT, 'ios')
NATIVE = File.join(ROOT, 'native', 'ios')
PROJECT_PATH = File.join(IOS, 'Runner.xcodeproj')

abort 'Run flutter create --platforms=ios . before this script.' unless File.exist?(PROJECT_PATH)

FileUtils.mkdir_p(File.join(IOS, 'Runner'))
FileUtils.mkdir_p(File.join(IOS, 'MPWindowsWidget'))
FileUtils.cp(File.join(NATIVE, 'Runner', 'AppDelegate.swift'), File.join(IOS, 'Runner', 'AppDelegate.swift'))
FileUtils.cp(File.join(NATIVE, 'Runner', 'Runner.entitlements'), File.join(IOS, 'Runner', 'Runner.entitlements'))
FileUtils.cp(File.join(NATIVE, 'MPWindowsWidget', 'MPWindowsTodayWidget.swift'), File.join(IOS, 'MPWindowsWidget', 'MPWindowsTodayWidget.swift'))
FileUtils.cp(File.join(NATIVE, 'MPWindowsWidget', 'MPWindowsWidget.entitlements'), File.join(IOS, 'MPWindowsWidget', 'MPWindowsWidget.entitlements'))
FileUtils.cp(File.join(NATIVE, 'MPWindowsWidget', 'Info.plist'), File.join(IOS, 'MPWindowsWidget', 'Info.plist'))

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target not found.' unless runner

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

widget = project.targets.find { |target| target.name == 'MPWindowsWidget' }
unless widget
  widget = project.new_target(:app_extension, 'MPWindowsWidget', :ios, '17.0', nil, :swift)

  group = project.main_group.groups.find { |item| item.display_name == 'MPWindowsWidget' }
  group ||= project.main_group.new_group('MPWindowsWidget', 'MPWindowsWidget')

  swift_ref = group.files.find { |item| item.path == 'MPWindowsTodayWidget.swift' }
  swift_ref ||= group.new_file('MPWindowsTodayWidget.swift')
  widget.add_file_references([swift_ref])

  info_ref = group.files.find { |item| item.path == 'Info.plist' }
  group.new_file('Info.plist') unless info_ref
  entitlements_ref = group.files.find { |item| item.path == 'MPWindowsWidget.entitlements' }
  group.new_file('MPWindowsWidget.entitlements') unless entitlements_ref

  widget.add_system_framework('WidgetKit')
  widget.add_system_framework('SwiftUI')

  runner.add_dependency(widget)

  embed = runner.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
  embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  build_file = embed.add_file_reference(widget.product_reference, true)
  build_file.settings = {
    'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy']
  }
end

widget.build_configurations.each do |config|
  runner_config = runner.build_configurations.find { |candidate| candidate.name == config.name }
  runner_bundle = runner_config&.build_settings&.fetch('PRODUCT_BUNDLE_IDENTIFIER', nil)
  runner_bundle = 'com.example.mpwindowsCrm' if runner_bundle.nil? || runner_bundle.empty?

  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{runner_bundle}.MPWindowsWidget"
  settings['INFOPLIST_FILE'] = 'MPWindowsWidget/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'MPWindowsWidget/MPWindowsWidget.entitlements'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SKIP_INSTALL'] = 'YES'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['MARKETING_VERSION'] = '1.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

project.save
puts 'MPWindows native iOS notifications + WidgetKit target configured.'
