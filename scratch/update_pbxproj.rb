require 'fileutils'

file_path = 'ios/Runner.xcodeproj/project.pbxproj'
content = File.read(file_path)

# Find all blocks for the WatchApp targets and modify their build settings
# The target name is 'WatchApp Watch App'
# We need to change GENERATE_INFOPLIST_FILE from YES to NO
# And add INFOPLIST_FILE = "WatchApp Watch App/Info.plist";
# Also, we can remove the INFOPLIST_KEY_* entries to clean up, but they will just be ignored if GENERATE_INFOPLIST_FILE is NO.

content.gsub!(/GENERATE_INFOPLIST_FILE = YES;\s*INFOPLIST_KEY_CFBundleDisplayName = "Los Mooscles";\s*INFOPLIST_KEY_CFBundleName = "Los Mooscles";\s*INFOPLIST_KEY_CFBundleShortVersionString = "\$\(MARKETING_VERSION\)";\s*INFOPLIST_KEY_CFBundleVersion = "\$\(CURRENT_PROJECT_VERSION\)";\s*INFOPLIST_KEY_NSHealthShareUsageDescription = "[^"]+";\s*INFOPLIST_KEY_NSHealthUpdateUsageDescription = "[^"]+";\s*INFOPLIST_KEY_UIBackgroundModes = "workout-processing";\s*INFOPLIST_KEY_UISupportedInterfaceOrientations = "[^"]+";\s*INFOPLIST_KEY_WKCompanionAppBundleIdentifier = com\.vicente\.losmooscles;\s*INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp = YES;/) do |match|
  "GENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = \"WatchApp Watch App/Info.plist\";"
end

# In case the regex missed due to ordering or something, let's just do a simpler replace.
# Actually, it's safer to just iterate lines.

lines = File.readlines(file_path)
new_lines = []
in_watch_app_config = false

lines.each do |line|
  if line.include?('PRODUCT_BUNDLE_IDENTIFIER = com.vicente.losmooscles.watchkitapp;')
    in_watch_app_config = true
  end
  
  if in_watch_app_config && line.include?('GENERATE_INFOPLIST_FILE = YES;')
    new_lines << line.sub('YES', 'NO')
    new_lines << "\t\t\t\tINFOPLIST_FILE = \"WatchApp Watch App/Info.plist\";\n"
  elsif in_watch_app_config && line.include?('INFOPLIST_KEY_')
    # Skip INFOPLIST_KEY lines for the Watch App
  else
    new_lines << line
  end
  
  if in_watch_app_config && line.strip == '};'
    in_watch_app_config = false
  end
end

File.write(file_path, new_lines.join)
puts "Successfully updated project.pbxproj"
