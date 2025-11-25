

import Foundation
import GoogleMobileAds
import VeloniumSDK

@objc(VeloniumAdMobNativeAdapter)
public class VeloniumAdMobNativeAdapter:
    VeloniumAdMobMediationBaseAdapter,
    GoogleMobileAds.MediationNativeAd,
    NativeAdEventDelegate {
    
    public var headline: String? {
        VeloniumNativeAd?.title
    }
    
    public var images: [GoogleMobileAds.NativeAdImage]?
    
    public var body: String? {
        VeloniumNativeAd?.text
    }
    
    public var icon: GoogleMobileAds.NativeAdImage?
    
    public var callToAction: String? {
        VeloniumNativeAd?.callToAction
    }
    
    public var starRating: NSDecimalNumber? {
        NSDecimalNumber(string: VeloniumNativeAd?.dataObjects(of: .rating).first?.value)
    }
    
    public var store: String?
    
    public var price: String? {
        VeloniumNativeAd?.dataObjects(of: .salePrice).first?.value
    }
    
    public var advertiser: String? {
        VeloniumNativeAd?.sponsoredBy
    }
    
    public var extraAssets: [String: Any]?
    
    var VeloniumNativeAd: VeloniumSDK.NativeAd?
    
    public weak var delegate: GoogleMobileAds.MediationNativeAdEventDelegate?
    var completionHandler: GADMediationNativeLoadCompletionHandler?
    
    public func loadNativeAd(
        for adConfiguration: GoogleMobileAds.MediationNativeAdConfiguration,
        completionHandler: @escaping GADMediationNativeLoadCompletionHandler
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
        
        switch MediationNativeUtils.findNative(in: eventExtrasDictionary) {
        case .success(let nativeAd):
            VeloniumNativeAd = nativeAd
            VeloniumNativeAd?.delegate = self
            downloadImages { [weak self] in
                // Images are downloaded; native ad is ready to be displayed
                guard let self = self else { return }
                self.delegate = completionHandler(self, nil)
            }
        
        case .failure(let error):
            delegate?.didFailToPresentWithError(error)
        }
    }
    
    public func didRender(
        in view: UIView,
        clickableAssetViews: [GADNativeAssetIdentifier : UIView],
        nonclickableAssetViews: [GADNativeAssetIdentifier : UIView],
        viewController: UIViewController
    ) {
        VeloniumNativeAd?.registerView(view: view, clickableViews: Array(clickableAssetViews.values))
    }
    
    public func handlesUserClicks() -> Bool {
        return false
    }
    
    public func handlesUserImpressions() -> Bool {
        return false
    }
    
    // MARK: - NativeAdEventDelegate
    
    public func adDidExpire(ad: VeloniumSDK.NativeAd) {
        let error = AdMobAdaptersError.adExpired
        if let handler = completionHandler {
           delegate = handler(nil, error)
        }
    }
    
    public func adWasClicked(ad: VeloniumSDK.NativeAd) {
        delegate?.reportClick()
    }
    
    public func adDidLogImpression(ad: VeloniumSDK.NativeAd) {
        delegate?.reportImpression()
    }
    
    func downloadImages(completion: @escaping () -> Void) {
        guard let imageUrl = VeloniumNativeAd?.imageUrl, let iconUrl = VeloniumNativeAd?.iconUrl else { return }
        
        ImageHelper.downloadImageAsync(imageUrl) { [weak self] result in
            if case .success(let image) = result {
                self?.images = [GoogleMobileAds.NativeAdImage(image: image)]
            }
            
            ImageHelper.downloadImageAsync(iconUrl) { [weak self] result in
                if case .success(let image) = result {
                    self?.icon = GoogleMobileAds.NativeAdImage(image: image)
                    completion()
                }
            }
        }
    }
}
