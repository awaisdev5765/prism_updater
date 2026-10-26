#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'prism_updater'
  s.version          = '0.2.0'
  s.summary          = 'Cross-platform in-app update experience for Flutter.'
  s.description      = 'Native store flows, staged rollouts, and direct downloads.'
  s.homepage         = 'https://github.com/awaisdev5765/prism_updater'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Awais Rehman' => 'awais@airtechsolutions.pk' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.frameworks       = 'StoreKit'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
