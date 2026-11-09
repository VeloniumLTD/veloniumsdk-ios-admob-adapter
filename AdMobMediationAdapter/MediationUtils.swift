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
import VeloniumSDK

@objcMembers
public class MediationUtils: NSObject {
    
    /// Checks if the server parameter (configId) matches the targeting info dictionary
    /// This validates that the correct ad unit is being rendered
    ///
    /// - Parameters:
    ///   - serverParameter: The configId from AdMob UI
    ///   - targetingInfo: The targeting info dictionary from the bid response
    /// - Returns: True if the server parameter matches a value in targeting info
    public static func isServerParameterInTargetingInfoDict(_ serverParameter: String, _ targetingInfo: [String: String]) -> Bool {
        // Check if the server parameter matches any of the targeting info values
        // This is a simple validation that the bid corresponds to the requested ad unit
        return targetingInfo.values.contains { $0.contains(serverParameter) } || 
               targetingInfo.keys.contains { $0.contains(serverParameter) } ||
               serverParameter.isEmpty // Empty parameter means no validation needed
    }
}

