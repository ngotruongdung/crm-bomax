Pod::Spec.new do |s|
  s.name           = 'OpsDeskOfficeWifi'
  s.version        = '0.1.0'
  s.summary        = 'OpsDesk office Wi-Fi bridge'
  s.description    = 'Reads the current SSID/BSSID for strict office attendance diagnostics.'
  s.author         = 'OpsDesk'
  s.homepage       = 'https://example.invalid/opsdesk'
  s.platforms      = { :ios => '14.0' }
  s.source         = { :git => '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end
