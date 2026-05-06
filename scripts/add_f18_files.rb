#!/usr/bin/env ruby
# F18 (CP3.5): register screenshot UITest. Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../JLPTDeck.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

ui_target = project.targets.find { |t| t.name == 'JLPTDeckUITests' }
raise 'JLPTDeckUITests target missing' unless ui_target

UI_SOURCES = [
  'JLPTDeckUITests/SpotCheckScreenshotTests.swift',
]

def add_file(project, target, rel_path)
  abs = File.expand_path("../#{rel_path}", __dir__)
  raise "missing #{rel_path}" unless File.exist?(abs)

  already = target.source_build_phase.files_references.any? { |fr| fr&.real_path&.to_s == abs }
  if already
    puts "skip (already in target): #{rel_path}"
    return
  end

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

UI_SOURCES.each { |p| add_file(project, ui_target, p) }
project.save
puts 'project saved'
