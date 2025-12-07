#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pocketsphinx_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pocketsphinx_flutter'
  s.version          = '0.1.0'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  
  # 1. Include ONLY the pocketsphinx static library
  s.vendored_libraries = 'PocketSphinx/libpocketsphinx.a'
  
  # 2. Point to the headers so the C/C++ wrapper can compile
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/PocketSphinx'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '-lstdc++ -all_load',
  }
  s.swift_version = '5.0'
end
