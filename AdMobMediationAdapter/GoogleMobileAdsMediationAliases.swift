/*   Copyright 2018-2021 Velonium.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import GoogleMobileAds

// MARK: - Core Adapter Types
public typealias MediationAdapter = GoogleMobileAds.MediationAdapter
public typealias MediationServerConfiguration = GoogleMobileAds.MediationServerConfiguration

// MARK: - Banner Types
public typealias MediationBannerAd = GoogleMobileAds.MediationBannerAd
public typealias MediationBannerAdConfiguration = GoogleMobileAds.MediationBannerAdConfiguration
public typealias MediationBannerAdEventDelegate = GoogleMobileAds.MediationBannerAdEventDelegate
public typealias GADMediationBannerLoadCompletionHandler = GoogleMobileAds.GADMediationBannerLoadCompletionHandler

// MARK: - Interstitial Types
public typealias MediationInterstitialAd = GoogleMobileAds.MediationInterstitialAd
public typealias MediationInterstitialAdConfiguration = GoogleMobileAds.MediationInterstitialAdConfiguration
public typealias MediationInterstitialAdEventDelegate = GoogleMobileAds.MediationInterstitialAdEventDelegate
public typealias GADMediationInterstitialLoadCompletionHandler = GoogleMobileAds.GADMediationInterstitialLoadCompletionHandler

// MARK: - Rewarded Types
public typealias MediationRewardedAd = GoogleMobileAds.MediationRewardedAd
public typealias MediationRewardedAdConfiguration = GoogleMobileAds.MediationRewardedAdConfiguration
public typealias MediationRewardedAdEventDelegate = GoogleMobileAds.MediationRewardedAdEventDelegate
public typealias GADMediationRewardedLoadCompletionHandler = GoogleMobileAds.GADMediationRewardedLoadCompletionHandler

// MARK: - Native Types
public typealias MediationNativeAd = GoogleMobileAds.MediationNativeAd
public typealias MediationNativeAdConfiguration = GoogleMobileAds.MediationNativeAdConfiguration
public typealias MediationNativeAdEventDelegate = GoogleMobileAds.MediationNativeAdEventDelegate
public typealias GADMediationNativeLoadCompletionHandler = GoogleMobileAds.GADMediationNativeLoadCompletionHandler

// MARK: - Version and Other Types
public typealias VersionNumber = GoogleMobileAds.VersionNumber
public typealias MobileAds = GoogleMobileAds.MobileAds
public typealias CustomEventExtras = GoogleMobileAds.CustomEventExtras
