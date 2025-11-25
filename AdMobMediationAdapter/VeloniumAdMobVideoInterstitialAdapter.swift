

import Foundation
import GoogleMobileAds
import VeloniumSDK

@objc(VeloniumAdMobVideoInterstitialAdapter)
public class VeloniumAdMobVideoInterstitialAdapter:
    VeloniumAdMobMediationBaseAdapter,
    GoogleMobileAds.MediationInterstitialAd,
    InterstitialControllerLoadingDelegate,
    InterstitialControllerInteractionDelegate {
    
    // MARK: - Private Properties
    
    var interstitialController: InterstitialController?
    weak var rootViewController: UIViewController?
    var adAvailable = false
    
    public weak var delegate: GoogleMobileAds.MediationInterstitialAdEventDelegate?
    var completionHandler: GADMediationInterstitialLoadCompletionHandler?
    
    public func loadInterstitial(
        for adConfiguration: GoogleMobileAds.MediationInterstitialAdConfiguration,
        completionHandler: @escaping GADMediationInterstitialLoadCompletionHandler
    ) {
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
        interstitialController?.adFormats = [.video]
        
        if let videoAdConfig = eventExtrasDictionary[PBMMediationVideoAdConfiguration] as? VideoControlsConfiguration {
            interstitialController?.videoControlsConfig = videoAdConfig
        }
        
        if let videoParameters = eventExtrasDictionary[PBMMediationVideoParameters] as? VideoParameters {
            interstitialController?.videoParameters = videoParameters
        }
        
        interstitialController?.loadAd()
    }
    
    public func present(from viewController: UIViewController) {
        if adAvailable {
            rootViewController = viewController
            interstitialController?.show()
        } else {
            let error = AdMobAdaptersError.noAd
            delegate?.didFailToPresentWithError(error)
        }
    }
    
    // MARK: - InterstitialControllerLoadingDelegate
    
    public func interstitialControllerDidLoadAd(
        _ interstitialController: VeloniumSDKInterstitialControllerProtocol
    ) {
        adAvailable = true
        
        if let handler = completionHandler {
            delegate = handler(self, nil)
        }
    }
    
    public func interstitialController(
        _ interstitialController: VeloniumSDKInterstitialControllerProtocol,
        didFailWithError error: Error
    ) {
        adAvailable = false
        
        if let handler = completionHandler {
            delegate = handler(nil, error)
        }
    }
    
    // MARK: - InterstitialControllerInteractionDelegate
    
    public func trackImpression(forInterstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.reportImpression()
    }
    
    public func viewControllerForModalPresentation(
        fromInterstitialController: VeloniumSDKInterstitialControllerProtocol
    ) -> UIViewController? {
        rootViewController
    }
    
    public func interstitialControllerDidClickAd(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.reportClick()
    }
    
    public func interstitialControllerDidCloseAd(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.willDismissFullScreenView()
        delegate?.didDismissFullScreenView()
    }
    
    public func interstitialControllerDidDisplay(_ interstitialController: VeloniumSDKInterstitialControllerProtocol) {
        delegate?.willPresentFullScreenView()
    }
    
    public func interstitialControllerDidLeaveApp(
        _ interstitialController: VeloniumSDKInterstitialControllerProtocol
    ) {}
    
    public func interstitialControllerDidComplete(
        _ interstitialController: VeloniumSDKInterstitialControllerProtocol
    ) {}
}
