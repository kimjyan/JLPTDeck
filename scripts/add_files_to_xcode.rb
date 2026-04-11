#!/usr/bin/env ruby
# Adds Task 1 + Task 2 source and test files to the JLPTDeck Xcode targets.
# Idempotent: files already in the project are skipped.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../JLPTDeck.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

app_target  = project.targets.find { |t| t.name == 'JLPTDeck' }
test_target = project.targets.find { |t| t.name == 'JLPTDeckTests' }
raise 'JLPTDeck target missing'     unless app_target
raise 'JLPTDeckTests target missing' unless test_target

APP_SOURCES = [
  'JLPTDeck/Domain/SRS/SRSQuality.swift',
  'JLPTDeck/Domain/SRS/SRSUpdate.swift',
  'JLPTDeck/Domain/SRS/SRSSnapshot.swift',
  'JLPTDeck/Domain/SRS/SM2.swift',
  'JLPTDeck/Domain/SRS/CardScheduler.swift',
  'JLPTDeck/Data/Models/SRSState.swift',
  'JLPTDeck/Data/Models/VocabCard.swift',
  'JLPTDeck/Data/JMdict/JLPTLevel.swift',
  'JLPTDeck/Data/JMdict/JMdictEntry.swift',
  'JLPTDeck/Data/JMdict/JMdictImporter.swift',
  'JLPTDeck/Data/Repository/RepositoryError.swift',
  'JLPTDeck/Data/Repository/LocalRepository.swift'
]

TEST_SOURCES = [
  'JLPTDeckTests/SRS/SM2Tests.swift',
  'JLPTDeckTests/SRS/SchedulerTests.swift',
  'JLPTDeckTests/SRS/SRSStateTests.swift',
  'JLPTDeckTests/Data/JMdictImporterTests.swift',
  'JLPTDeckTests/Data/LocalRepositoryTests.swift'
]

TEST_RESOURCES = [
  'JLPTDeckTests/Data/Fixtures/jmdict_sample.json'
]

def ensure_group(project, path_components)
  group = project.main_group
  path_components.each do |name|
    child = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name }
    group = child || group.new_group(name, name)
  end
  group
end

def already_has?(target, path)
  target.source_build_phase.files_references.any? { |ref| ref && ref.real_path.to_s.end_with?(path) } ||
    target.resources_build_phase.files_references.any? { |ref| ref && ref.real_path.to_s.end_with?(path) }
end

def add_file(project, target, relative_path, phase: :source)
  return if already_has?(target, relative_path)
  dir_components = File.dirname(relative_path).split('/')
  group = ensure_group(project, dir_components)
  file_ref = group.files.find { |f| f.real_path.to_s.end_with?(relative_path) }
  file_ref ||= group.new_reference(File.expand_path("../#{relative_path}", __dir__))
  case phase
  when :source
    target.add_file_references([file_ref])
  when :resource
    target.add_resources([file_ref])
  end
  puts "  + #{relative_path}"
end

puts "App target sources:"
APP_SOURCES.each { |p| add_file(project, app_target, p, phase: :source) }

puts "Test target sources:"
TEST_SOURCES.each { |p| add_file(project, test_target, p, phase: :source) }

puts "Test target resources:"
TEST_RESOURCES.each { |p| add_file(project, test_target, p, phase: :resource) }

project.save
puts "Saved #{PROJECT_PATH}"
