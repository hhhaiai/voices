Pod::Spec.new do |s|
  s.name         = 'LlamaCpp'
  s.version      = '0.2.2'
  s.summary      = 'llama.cpp native framework for llama_cpp_dart'
  s.homepage     = 'https://github.com/nicordev/llama_cpp_dart'
  s.license      = { :type => 'MIT' }
  s.author       = 'llama_cpp_dart'
  s.source       = { :path => '.' }

  s.platform     = :ios, '13.0'
  s.swift_version = '5.0'

  s.vendored_frameworks = '../Llama.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '',
  }
end
