#!/usr/bin/env ruby
# Remove duplicate PBXBuildFile entries from the Xcode project.
# Xcode 16 synchronized file groups auto-include files; the manual
# entries from add_files_to_xcode.rb cause "Skipping duplicate" warnings.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../JLPTDeck.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

project.targets.each do |target|
  [target.source_build_phase, target.resources_build_phase].compact.each do |phase|
    seen = {}
    dupes = []
    phase.files.each do |bf|
      ref = bf.file_ref
      next unless ref
      key = ref.real_path.to_s
      if seen[key]
        dupes << bf
      else
        seen[key] = bf
      end
    end
    dupes.each do |bf|
      puts "  removing duplicate: #{bf.file_ref&.real_path} from #{target.name}"
      bf.remove_from_project
    end
  end
end

project.save
puts "Saved. Removed #{project.targets.sum { |t| 0 }} — check xcodebuild warnings."
