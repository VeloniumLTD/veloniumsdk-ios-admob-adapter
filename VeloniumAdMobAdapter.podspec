Pod::Spec.new do |s|
  s.name             = 'VeloniumAdMobAdapter'
  s.version          = '1.0.5'
  s.module_name = s.name
  s.summary          = 'AdMob mediation adapter for VeloniumSDK'
  s.description      = <<-DESC
    This adapter enables AdMob mediation support for VeloniumSDK.
    It provides banner, interstitial, native, and rewarded ad adapters
    that work with Google Mobile Ads SDK.
  DESC
  
  s.homepage         = 'https://github.com/VeloniumLTD/veloniumsdk-ios-admob-adapter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Velonium' => 'support@velonium.com' }
  s.source           = { :git => 'https://github.com/VeloniumLTD/veloniumsdk-ios-admob-adapter.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '15.6'
  s.swift_version = '5.0'
  s.static_framework = true

  # Depend on Core VeloniumSDK (same version as adapter)
  s.dependency 'VeloniumSDK', s.version.to_s
  
  # Depend on GoogleMobileAds
  s.dependency 'Google-Mobile-Ads-SDK', '~> 12.0'
    
  # Include AdMob adapter source files
  s.source_files = 'AdMobMediationAdapter/**/*.swift'
  
  s.requires_arc = true
  
  # Add compiler flags to ensure VeloniumSDK headers are available
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    # Google Mobile Ads loads the adapter by class name at runtime, so no Objective-C
    # header is needed. Generating it fails on Xcode 26 because the generated header
    # references VeloniumSDK Swift protocols that have no Objective-C header.
    'SWIFT_INSTALL_OBJC_HEADER' => 'NO'
  }
end

