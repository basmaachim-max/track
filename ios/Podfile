# Podfile جاهز لمشروع sales_track
platform :ios, '15.0'

use_frameworks!
use_modular_headers!

target 'Runner' do
  flutter_application_path = '../'
  eval(File.read(File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')), binding)

  # Firebase pods (تُضاف تلقائيًا عن طريق Flutter plugins)
  # Pod examples إذا حبيت تضيفها يدويًا:
  # pod 'Firebase/Firestore'
  # pod 'Firebase/Auth'
  # pod 'Firebase/Messaging'
  # pod 'Firebase/Storage'

  # إضافات أخرى إذا استخدمت:
  # pod 'GoogleMaps'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_setting
