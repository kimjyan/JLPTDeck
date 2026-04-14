#!/usr/bin/env ruby
# Adds pointfreeco/swift-composable-architecture as an SPM dependency
# to the JLPTDeck Xcode target. Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../JLPTDeck.xcodeproj', __dir__)
TCA_URL = 'https://github.com/pointfreeco/swift-composable-architecture'
TCA_MIN_VERSION = '1.15.0'
PRODUCT_NAME = 'ComposableArchitecture'

project = Xcodeproj::Project.open(PROJECT_PATH)
app_target = project.targets.find { |t| t.name == 'JLPTDeck' }
raise 'JLPTDeck target missing' unless app_target

existing = project.root_object.package_references.find { |r| r.repositoryURL == TCA_URL }
if existing
  puts "Package ref already present (#{existing.requirement.inspect})"
  package_ref = existing
else
  package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  package_ref.repositoryURL = TCA_URL
  package_ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => TCA_MIN_VERSION }
  project.root_object.package_references << package_ref
  puts "Added package ref: #{TCA_URL} >= #{TCA_MIN_VERSION}"
end

already_linked = app_target.package_product_dependencies.any? { |d| d.product_name == PRODUCT_NAME }
if already_linked
  puts "Product dependency #{PRODUCT_NAME} already linked to target JLPTDeck"
else
  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.package = package_ref
  product_dep.product_name = PRODUCT_NAME
  app_target.package_product_dependencies << product_dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  app_target.frameworks_build_phase.files << build_file
  puts "Linked #{PRODUCT_NAME} to JLPTDeck target"
end

project.save
puts "Saved #{PROJECT_PATH}"
