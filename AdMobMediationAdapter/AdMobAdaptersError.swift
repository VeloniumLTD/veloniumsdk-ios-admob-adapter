

import Foundation

enum AdMobAdaptersError {
    case emptyCustomEventExtras
    case noTargetingInfoInEventExtras
    case noBidInEventExtras
    case noConfigIDInEventExtras
    case noServerParameter
    case wrongServerParameter
    case emptyUserKeywords
    case noAd
    case adNotValid
    case adExpired
}

extension AdMobAdaptersError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            
        case .emptyCustomEventExtras        : return "The custom event extras is empty"
        case .noTargetingInfoInEventExtras  : return "The targeting info dictionary is absent in the extras"
        case .noBidInEventExtras            : return "The Bid object is absent in the extras"
        case .noConfigIDInEventExtras       : return "The Config ID is absent in the extras"
        case .noServerParameter             : return "Server parameter is absent in request"
        case .wrongServerParameter          : return "User keywords don't contain server parameter"
        case .emptyUserKeywords             : return "User keywords are empty"
        case .noAd                          : return "No ad available"
        case .adNotValid                    : return "Ad is not valid"
        case .adExpired                     : return "Ad expired"
        }
    }
}
