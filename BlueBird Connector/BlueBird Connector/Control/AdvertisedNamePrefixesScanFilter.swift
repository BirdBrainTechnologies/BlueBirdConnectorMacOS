//
//  AdvertisedNamePrefixesScanFilter.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/12/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import CoreBluetooth
import BirdbrainBLE

public class AdvertisedNamePrefixesScanFilter: UARTDeviceScanFilter {
    
    private let prefixes: [String]
    private let isCaseSensitive: Bool
    
    public init(prefix: String, isCaseSensitive: Bool = true) {
        self.isCaseSensitive = isCaseSensitive
        self.prefixes = [isCaseSensitive ? prefix : prefix.lowercased()]
    }
    
    public init(prefixes: [String]) {
        self.isCaseSensitive = true
        self.prefixes = prefixes
    }
    
    public func isOfType(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) -> Bool {
        guard let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return false
        }
        
        let advertisedNameStr = isCaseSensitive ? advertisedName : advertisedName.lowercased()
        
        var hasValidPrefix = false
        prefixes.forEach { prefix in
            if advertisedNameStr.hasPrefix(prefix) { hasValidPrefix = true }
        }
        return hasValidPrefix
    }
}
