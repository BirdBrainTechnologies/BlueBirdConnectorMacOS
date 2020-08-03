//
//  Shared.swift
//  BlueBird Connector
//
//  Class to contain all shared singleton instances
//
//  Created by Kristina Lauwers on 7/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE

class Shared {
    private static let rmSingleton = UARTDeviceManager<ManageableRobot>(scanFilter: ManageableRobot.scanFilter)
    public static var robotManager: UARTDeviceManager<ManageableRobot> {
        return rmSingleton
    }
    
    private static let fsSingleton = FrontendServer()
    public static var frontendServer: FrontendServer {
        return fsSingleton
    }
    
    private static let bsSingleton = BackendServer()
    public static var backendServer: BackendServer {
        return bsSingleton
    }
    
}
