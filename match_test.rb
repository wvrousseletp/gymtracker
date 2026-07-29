require 'fastlane'
puts Fastlane::Actions::AppStoreConnectApiKeyAction.available_options.map(&:key)
