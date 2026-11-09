

import Foundation
import GoogleMobileAds
import VeloniumSDK

@objcMembers
public class AdMobMediationBannerUtils: NSObject, VeloniumMediationDelegate {
    
    public let gadRequest: GoogleMobileAds.Request
    
    public let bannerView: GoogleMobileAds.BannerView
    
    public init(gadRequest: GoogleMobileAds.Request, bannerView: GoogleMobileAds.BannerView) {
        self.gadRequest = gadRequest
        self.bannerView = bannerView
        super.init()
    }
    
    public func setUpAdObject(with values: [String: Any]) -> Bool {
        let extras = GoogleMobileAds.CustomEventExtras()
        extras.setExtras(values, forLabel: AdMobConstants.VeloniumAdMobEventExtrasLabel)
        
        gadRequest.register(extras)
        gadRequest.keywords = AdMobUtils.buildKeywords(
            existingKeywords: gadRequest.keywords,
            targetingInfo: values[PBMMediationTargetingInfoKey] as? [String: String]
        )
        
        return true
    }
    
    public func cleanUpAdObject() {
        if let gadKeywords = gadRequest.keywords {
            gadRequest.keywords = AdMobUtils.removeHBKeywordsFrom(gadKeywords)
        }
        
        let extras = GoogleMobileAds.CustomEventExtras()
        extras.setExtras(nil, forLabel: AdMobConstants.VeloniumAdMobEventExtrasLabel)
        gadRequest.register(extras)
    }
    
    public func getAdView() -> UIView? {
        bannerView
    }
}
