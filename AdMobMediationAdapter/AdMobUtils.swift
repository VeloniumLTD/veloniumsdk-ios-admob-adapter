

import Foundation
import GoogleMobileAds
import VeloniumSDK

fileprivate let HBKeywordPrefix = "hb_"

@objcMembers
public class AdMobUtils: NSObject {
    
    public static func initializeGAD() {
        MobileAds.shared.start()
    }
    
    static func removeHBKeywordsFrom(_ keywords: [String]) -> [String]  {
        return keywords.filter { !$0.hasPrefix(HBKeywordPrefix) }
    }
    
    static func buildKeywords(existingKeywords: [String]?, targetingInfo: [String: String]?) -> [String]? {
        guard let targetingInfo = targetingInfo else {
            return nil
        }
        
        let VeloniumKeywords = targetingInfo.map { $0 + ":" + $1 }
        if let existingKeywords = existingKeywords, !existingKeywords.isEmpty {
            let joinedKeywords = existingKeywords + VeloniumKeywords
            return !joinedKeywords.isEmpty ? joinedKeywords : nil
        }
       
        return !VeloniumKeywords.isEmpty ? VeloniumKeywords : nil
    }
}
