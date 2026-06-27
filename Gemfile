# frozen_string_literal: true

source "https://rubygems.org"

# fastlane drives the App Store / TestFlight pipeline. Pinned via Gemfile.lock
# (commit it after the first `bundle install`) so CI is reproducible.
gem "fastlane", "~> 2.225"

plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
