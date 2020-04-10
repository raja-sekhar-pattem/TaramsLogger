#
# Be sure to run `pod lib lint TaramsLogger.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TaramsLogger'
  s.version          = '0.1.1'
  s.summary          = 'A utility class on top of AWSLogs to updlad logd to AWS'
  s.swift_version    = '5.0'
  s.homepage         = 'https://github.com/raja-sekhar-pattem/TaramsLogger'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'rajasekhar.pattem@tarams.com' => 'rajasekhar.pattem@tarams.com' }
  s.source           = { :git => 'https://github.com/raja-sekhar-pattem/TaramsLogger.git', :tag => s.version.to_s }
  s.ios.deployment_target = '11.0'
  s.source_files = 'TaramsLogger/Classes/**/*'
  
  # s.resource_bundles = {
  #   'TaramsLogger' => ['TaramsLogger/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
#   s.frameworks = 'UIKit', 'Foundation'
   s.dependency 'AWSLogs', '~> 2.13.1'
end
