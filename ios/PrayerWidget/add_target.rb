#!/usr/bin/env ruby
# Adds the "PrayerWidget" WidgetKit extension target to ios/Runner.xcodeproj.
# Idempotent: re-running is a no-op once the target exists. Re-run this if the
# iOS project is ever regenerated. Run from the repo root:
#   ruby ios/PrayerWidget/add_target.rb
require 'xcodeproj'

WIDGET = 'PrayerWidget'
# App Group is a shared-container id, independent of the bundle id — it keeps its
# original spelling (matches Runner/PrayerWidget.entitlements + WidgetPublisher
# in Dart). The bundle id was unified to com.almarfa.alquran.
APP_GROUP = 'group.com.almarfa.alQuran'
BUNDLE_ID = 'com.almarfa.alquran.PrayerWidget'

project_path = File.expand_path('../../Runner.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(project_path)

runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'

if project.targets.any? { |t| t.name == WIDGET }
  puts "#{WIDGET} target already exists — nothing to do."
  exit 0
end

# 1. The app-extension target.
widget = project.new_target(:app_extension, WIDGET, :ios, '14.0')

# 2. Mirror the project's build configurations (Flutter adds a Profile config).
project.build_configurations.each do |proj_conf|
  next if widget.build_configurations.any? { |c| c.name == proj_conf.name }
  template = widget.build_configurations.find { |c| c.name == 'Release' }
  added = widget.add_build_configuration(proj_conf.name, template.type)
  added.build_settings = template.build_settings.dup
end

# 3. File references under a PrayerWidget group.
group = project.main_group.find_subpath(WIDGET, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(WIDGET)
swift_ref = group.new_reference('PrayerWidget.swift')
group.new_reference('Info.plist')
group.new_reference('PrayerWidget.entitlements')
widget.source_build_phase.add_file_reference(swift_ref)

# 4. Build settings on every configuration.
widget.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  bs['INFOPLIST_FILE'] = 'PrayerWidget/Info.plist'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'PrayerWidget/PrayerWidget.entitlements'
  bs['CODE_SIGN_STYLE'] = 'Automatic'
  bs['SWIFT_VERSION'] = '5.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['SKIP_INSTALL'] = 'YES'
  bs['MARKETING_VERSION'] = '1.0'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

# 5. Runner depends on + embeds the extension (.appex into PlugIns).
runner.add_dependency(widget)
embed = runner.build_phases.find do |p|
  p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.symbol_dst_subfolder_spec == :plug_ins
end
embed ||= runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.dst_path = ''
build_file = embed.add_file_reference(widget.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# 5b. The embed phase MUST run before Flutter's "Thin Binary" / pods-embed
# script phases, or Xcode reports "Cycle inside Runner; building could produce
# unreliable results."
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end

# 6. App Group entitlement on the Runner app (so it can write the shared store).
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts "Added #{WIDGET} extension target (#{BUNDLE_ID}), App Group #{APP_GROUP}."
