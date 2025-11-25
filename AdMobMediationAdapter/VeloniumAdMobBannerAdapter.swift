


import Foundation
import GoogleMobileAds
import VeloniumSDK

@objc(VeloniumAdMobBannerAdapter)
public class VeloniumAdMobBannerAdapter:
    VeloniumAdMobMediationBaseAdapter,
    GoogleMobileAds.MediationBannerAd,
    DisplayViewLoadingDelegate,
    DisplayViewInteractionDelegate {
    
    public var view: UIView {
        displayView ?? UIView()
    }
    
    var displayView: DisplayView?
    
    weak var delegate: GoogleMobileAds.MediationBannerAdEventDelegate?
    var adConfiguration: GoogleMobileAds.MediationBannerAdConfiguration?
    var completionHandler: GADMediationBannerLoadCompletionHandler?
    
    public func loadBanner(
        for adConfiguration: GoogleMobileAds.MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
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
        
        let frame = CGRect(origin: .zero, size: bid.size)
        
        displayView = DisplayView(frame: frame, bid: bid, configId: configId)
        displayView?.interactionDelegate = self
        displayView?.loadingDelegate = self
        
        displayView?.loadAd()
    }

    // MARK: - Direct render from fetched Bid (used when demand fetched inside mediation adapter)
    public func render(
        bid: Bid,
        configId: String,
        for adConfiguration: GoogleMobileAds.MediationBannerAdConfiguration,
        completionHandler: @escaping GADMediationBannerLoadCompletionHandler
    ) {
        self.adConfiguration = adConfiguration
        self.completionHandler = completionHandler

        let frame = CGRect(origin: .zero, size: bid.size)
        displayView = DisplayView(frame: frame, bid: bid, configId: configId)
        displayView?.interactionDelegate = self
        displayView?.loadingDelegate = self
        displayView?.loadAd()
    }
    
    // MARK: - DisplayViewLoadingDelegate
    
    public func displayViewDidLoadAd(_ displayViewManager: UIView) {
        if let handler = completionHandler {
            delegate = handler(self, nil)
        }
    }
    
    public func displayView(_ displayViewManager: UIView, didFailWithError error: Error) {
        if let handler = completionHandler {
            delegate = handler(nil, error)
        }
    }
    
    // MARK: - PBMDisplayViewInteractionDelegate
    
    public func trackImpression(forDisplayView: UIView) {
        delegate?.reportImpression()
    }
    
    public func viewControllerForModalPresentation(fromDisplayView: UIView) -> UIViewController? {
        adConfiguration?.topViewController ?? UIApplication.shared.windows.first?.rootViewController
    }
    
    public func didLeaveApp(from displayView: UIView) {
        delegate?.reportClick()
    }
    
    public func willPresentModal(from displayView: UIView) {
        delegate?.willPresentFullScreenView()
    }
    
    public func didDismissModal(from displayView: UIView) {
        delegate?.willDismissFullScreenView()
        delegate?.didDismissFullScreenView()
    }
}
