#!/usr/bin/env ruby
# F3: register new source + test files in the JLPTDeck Xcode project.
# Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../JLPTDeck.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

app_target  = project.targets.find { |t| t.name == 'JLPTDeck' }
test_target = project.targets.find { |t| t.name == 'JLPTDeckTests' }
raise 'JLPTDeck target missing'      unless app_target
raise 'JLPTDeckTests target missing' unless test_target

APP_SOURCES = [
  'JLPTDeck/Domain/FeatureFlags.swift',
  'JLPTDeck/Domain/SRS/RelearnPolicy.swift',
]

TEST_SOURCES = [
  'JLPTDeckTests/SRS/RelearnPolicyTests.swift',
  'JLPTDeckTests/Features/RelearnReducerTests.swift',
]

def add_file(project, target, rel_path)
  abs = File.expand_path("../#{rel_path}", __dir__)
  raise "missing #{rel_path}" unless File.exist?(abs)

  # Already in build phase?
  already = target.source_build_phase.files_references.any? { |fr| fr&.real_path&.to_s == abs }
  if already
    puts "skip (already in target): #{rel_path}"
    return
  end

  # Find or build the group chain matching the path.
  parts = rel_path.split('/')
  group = project.main_group
  parts[0..-2].each do |seg|
    sub = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == seg }
    sub ||= group.new_group(seg, seg)
    group = sub
  end

  file_ref = group.files.find { |f| f.path == parts.last } ||
             group.new_reference(parts.last)
  target.add_file_references([file_ref])
  puts "added: #{rel_path} -> #{target.name}"
end

APP_SOURCES.each  { |p| add_file(project, app_target,  p) }
TEST_SOURCES.each { |p| add_file(project, test_target, p) }

project.save
puts 'project saved'
