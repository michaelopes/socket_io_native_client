Pod::Spec.new do |s|
  s.name             = 'socket_io_native_client'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for Socket.IO client with native platform support.'
  s.description      = <<-DESC
A Flutter plugin for Socket.IO client with native platform support for Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/Dev-Devarsh/socket_io_native_client'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Devarsh' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'Socket.IO-Client-Swift', '~> 16.1.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end 