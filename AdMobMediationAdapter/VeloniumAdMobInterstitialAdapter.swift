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
import VeloniumSDK

@objc(VeloniumAdMobInterstitialAdapter)
public class VeloniumAdMobInterstitialAdapter:
    VeloniumAdMobMediationBaseAdapter,
    GoogleMobileAds.MediationInterstitialAd,
    InterstitialControllerLoadingDelegate,
    InterstitialControllerInteractionDelegate {
    
    var interstitialController: InterstitialController?
    
    weak var delegate: GoogleMobileAds.MediationInterstitialAdEventDelegate?
    var adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration?
    var completionHandler: GADMediationInterstitialLoadCompletionHandler?
    
    public func loadInterstitialAd(
        for adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        self.adConfiguration = adConfiguration
        self.completionHandler = completionHandler
        guard let serverParameter = adConfiguration.credentials.settings["parameter"] as? String else {
            let error = AdMobAdaptersError.noServerParameter
            delegate = completionHandler(nil, error)
            return
        }
                
        guard let eventExtras = adConfiguration.extras as? GoogleMobileAds.CustomEventExtras,
              let eventExtrasDictionary = eventExtras.extras(forLabel: AdMobConstants.VeloniumAdMobEventExtrasLabel),
              !eventExtrasDictionary.isEmpty else {
            let error = AdMobAdaptersError.emptyCustomEventExtras
            delegate = completionHandler(nil, error)
            return
        }

        guard let targetingInfo = eventExtrasDictionary[PBMMediationTargetingInfoKey] as? [String: String] else {
            let error = AdMobAdaptersError.noTargetingInfoInEventExtras
            delegate = completionHandler(nil, error)
            return
        }
                
        guard AdMobMediationUtils.isServerParameterInTargetingInfoDict(serverParameter, targetingInfo) else {
            let error = AdMobAdaptersError.wrongServerParameter
            delegate = completionHandler(nil, error)
            return
        }
        
        guard let bid = eventExtrasDictionary[PBMMediationAdUnitBidKey] as? Bid else {
            let error = AdMobAdaptersError.noBidInEventExtras
            delegate = completionHandler(nil, error)
            return
        }
                
        guard let configId = eventExtrasDictionary[PBMMediationConfigIdKey] as? String else {
            let error = AdMobAdaptersError.noConfigIDInEventExtras
            delegate = completionHandler(nil, error)
            return
        }
        
        interstitialController = InterstitialController(bid: bid, configId: configId)
        interstitialController?.loadingDelegate = self
        interstitialController?.interactionDelegate = self
        interstitialController?.loadAd()
    }

    // MARK: - Direct render from fetched Bid (used when demand fetched inside mediation adapter)
    public func render(
        bid: Bid,
        configId: String,
        for adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
        
        self.adConfiguration = adConfiguration
        self.completionHandler = completionHandler
        
        interstitialController = InterstitialController(bid: bid, configId: configId)
        
        guard let controller = interstitialController else {
            let error = NSError(domain: "VeloniumAdapter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create controller"])
            delegate = completionHandler(nil, error)
            return
        }
                
        controller.loadingDelegate = self
        controller.interactionDelegate = self
        controller.loadAd()
    }
    
    // MARK: - MediationInterstitialAd
    
    public func present(from viewController: UIViewController) {
        
        guard let controller = interstitialController else {
            return
        }

        controller.show()
    }
    
    // MARK: - InterstitialControllerLoadingDelegate
    
    public func interstitialControllerDidLoadAd(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
    
        if let handler = completionHandler {
            delegate = handler(self, nil)
        }
    }
    
    public func interstitialController(_ interstitialController: VeloniumSDKInterstitialControllerProtocol, didFailWithError error: Error) {
        if let handler = completionHandler {
            delegate = handler(nil, error)
        }
    }
    
    // MARK: - InterstitialControllerInteractionDelegate
    
    public func trackImpression(forInterstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.reportImpression()
    }
    
    public func interstitialControllerDidClickAd(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.reportClick()
    }
    
    public func interstitialControllerDidLeaveApp(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        // AdMob doesn't have separate leave app event
    }
    
    public func interstitialControllerDidDisplay(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.willPresentFullScreenView()
    }
    
    public func interstitialControllerDidComplete(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        // For interstitial, this is equivalent to dismiss
        delegate?.didDismissFullScreenView()
    }
    
    public func interstitialControllerDidCloseAd(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.willDismissFullScreenView()
        delegate?.didDismissFullScreenView()
    }
    
    public func viewControllerForModalPresentation(fromInterstitialController: VeloniumSDKInterstitialControllerProtocol) -> UIViewController? {
        return adConfiguration?.topViewController ?? UIApplication.shared.windows.first?.rootViewController
    }
}
