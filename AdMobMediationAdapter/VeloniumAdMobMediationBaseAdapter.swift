

import Foundation
import VeloniumSDK
import GoogleMobileAds

public class VeloniumAdMobMediationBaseAdapter: NSObject, GoogleMobileAds.MediationAdapter {
    
    public static func adapterVersion() -> GoogleMobileAds.VersionNumber {
        let adapterVersionComponents = AdMobConstants
            .VeloniumAdMobRewardedAdapterVersion
            .components(separatedBy: ".")
            .map( { Int($0) ?? 0})
        
        return adapterVersionComponents.count == 3 ? GoogleMobileAds.VersionNumber(
            majorVersion: adapterVersionComponents[0],
            minorVersion: adapterVersionComponents[1],
            patchVersion: adapterVersionComponents[2]
        ) : GoogleMobileAds.VersionNumber()
    }
    
    public static func adSDKVersion() -> GoogleMobileAds.VersionNumber {
        let sdkVersionComponents = Velonium
            .shared
            .version
            .components(separatedBy: ".")
            .map( { Int($0) ?? 0})
        
        return sdkVersionComponents.count == 3 ? GoogleMobileAds.VersionNumber(
            majorVersion: sdkVersionComponents[0],
            minorVersion: sdkVersionComponents[1],
            patchVersion: sdkVersionComponents[2]
        ) : GoogleMobileAds.VersionNumber()
    }
    
    public static func networkExtrasClass() -> GoogleMobileAds.AdNetworkExtras.Type? {
        GoogleMobileAds.CustomEventExtras.self
    }
        
    // Added for tests
    static func latestTestedGMAVersion() -> GoogleMobileAds.VersionNumber {
        GoogleMobileAds.VersionNumber(
            majorVersion: 12,
            minorVersion: 12,
            patchVersion: 0
        )
    }
    
    required public override init() {
        super.init()
    }
    
    public static func setUp(
        with configuration: GoogleMobileAds.MediationServerConfiguration,
        completionHandler: @escaping GADMediationAdapterSetUpCompletionBlock
    ) {
        // TODO: Add Velonium SDK initialization logic
    }
}
