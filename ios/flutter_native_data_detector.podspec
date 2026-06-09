#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_native_data_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_native_data_detector'
  s.version          = '0.0.1'
  s.summary          = 'Native text data detection (NSDataDetector) for Flutter.'
  s.description      = <<-DESC
Detects phone numbers, URLs, emails, addresses, and dates in text using
NSDataDetector on iOS.
                       DESC
  s.homepage         = 'https://github.com/xcc3641/flutter_native_data_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hugo' => 'hugo@starfruitlab.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_native_data_detector_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
