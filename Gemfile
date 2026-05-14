source "https://rubygems.org"

# iOS distribution toolchain. Pinned to gems that work on macOS system Ruby
# (2.6+) and GitHub macOS-14 runners (Ruby 3.x). `bundle install` produces
# Gemfile.lock that pins resolved versions per maintainer's machine.

gem "fastlane", "~> 2.222"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
