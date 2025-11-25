Pod::Spec.new do |s|
  s.name             = 'VeloniumAdMobAdapter'
  s.version          = '1.0.1'
  s.summary          = 'AdMob mediation adapter for VeloniumSDK'
  s.description      = <<-DESC
    This adapter enables AdMob mediation support for VeloniumSDK.
    It provides banner, interstitial, native, and rewarded ad adapters
    that work with Google Mobile Ads SDK.
  DESC
  
  s.homepage         = 'https://github.com/VeloniumLTD/Velonium-SDK-iOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Velonium' => 'support@velonium.com' }
  s.source           = { :git => 'https://github.com/VeloniumLTD/Velonium-SDK-iOS.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '15.6'
  s.swift_version = '5.0'
  
  # Depend on Core VeloniumSDK (same version as adapter)
  s.dependency 'VeloniumSDK', s.version.to_s
  
  # Depend on GoogleMobileAds
  s.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'
  
  # Static framework - to prevent duplicates, ensure pod is only added to Unity-iPhone target
  s.static_framework = true
  
  # Include AdMob adapter source files
  s.source_files = 'AdMobMediationAdapter/**/*.{swift,h,m}'
  s.public_header_files = 'AdMobMediationAdapter/**/*.h'
  
  s.requires_arc = true
end

