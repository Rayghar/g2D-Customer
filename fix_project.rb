require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Find the "Runner" group
group = project.main_group.find_subpath(File.join('Runner'), true)

# 2. Get the file reference for Runner.entitlements
# (If it's already there, this gets it; if not, it creates it)
file_ref = group.new_reference('Runner.entitlements')

# 3. Add this file to the "Runner" target
target = project.targets.first # The 'Runner' target is usually first
target.add_file_references([file_ref])

# 4. Save the project
project.save

puts "✅ Successfully added Runner.entitlements to the Xcode project structure."