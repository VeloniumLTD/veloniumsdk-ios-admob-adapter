

import Foundation
import VeloniumSDK
import GoogleMobileAds

@objcMembers
public class AdMobMediationInterstitialUtils: NSObject, VeloniumMediationDelegate {
    
    public let gadRequest: GoogleMobileAds.Request
    
    public init(gadRequest: GoogleMobileAds.Request) {
        self.gadRequest = gadRequest
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
        nil
    }
}
