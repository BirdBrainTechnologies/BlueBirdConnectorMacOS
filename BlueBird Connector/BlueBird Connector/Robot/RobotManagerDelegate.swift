//
//  RobotManagerDelegate.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/28/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE
import os


class RobotManagerDelegate: UARTDeviceManagerDelegate {
    
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "RobotManagerDelegate")
    
    
    func didUpdateState(to state: UARTDeviceManagerState) {
        os_log("UARTDeviceManagerDelegate.didUpdateState to: [%s]", log: log, type: .debug, state.rawValue)
        switch state {
        case .enabled:
            Shared.frontendServer.startScan()
        case .disabled:
            os_log("manager disabled", log: log, type: .debug)
            Shared.frontendServer.notifyBleDisabled()
        case .error:
            os_log("manager error", log: log, type: .error)
        }
    }

    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        
        os_log("DID DISCOVER [%s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
        guard let advertisementSignature = advertisementSignature else {
            os_log("Ignoring device [%s] because it is missing advertisement info.", log: log, type: .debug, uuid.uuidString)
            return
        }
        
        Shared.frontendServer.notifyDeviceDiscovery(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
        
    }

    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        os_log("DID REDISCOVER [%s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
        
        Shared.frontendServer.updateDeviceInfo(uuid: uuid, adSig: advertisementSignature, rssi: rssi)

    }

    func didDisappear(uuid: UUID) {
        os_log("DID DISAPPEAR [%s]", log: log, type: .debug, uuid.uuidString)
        Shared.frontendServer.notifyDeviceDidDisappear(uuid: uuid)
    }

    func didConnectTo(uuid: UUID) {
        os_log("DID CONNECT TO [%s]", log: log, type: .debug, uuid.uuidString)
        guard let mRobot = Shared.robotManager.getDevice(uuid: uuid) else {
            os_log("Connected robot not found with uuid [%s]", log: log, type: .error, uuid.uuidString)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
            return
        }
        
        /*guard robot.type != .Unknown else {
            os_log("Connected to robot of unknown type!", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
            return
        }*/
        
        guard mRobot.notificationsRunning else {
            os_log("Connected robot failed to start notifications", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
            return
        }
        
        guard let robot = robotFactory(mRobot) else {
            os_log("Failed to create robot type", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
            return
        }
        
        var letterAssigned = false
        for devLetter in DeviceLetter.allCases {
            if !letterAssigned && Shared.backendServer.connectedRobots[devLetter] == nil {
                Shared.backendServer.connectedRobots[devLetter] = robot
                letterAssigned = true
                Shared.frontendServer.notifyDeviceDidConnect(uuid: uuid, name: robot.name, fancyName: robot.fancyName, deviceLetter: devLetter)
            }
        }
        
        if !letterAssigned {
            os_log("Too many connections", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
        }
    }
    
    func robotFactory(_ mRobot: ManageableRobot) -> Robot? {
        let prefix = mRobot.advertisementSignature?.advertisedName.prefix(2) ?? "XX"
        switch prefix {
        case "FN": return Finch(mRobot)
        case "BB": return Hummingbird(mRobot)
        case "MB": return Microbit(mRobot)
        default: return nil
        }
    }

    func didDisconnectFrom(uuid: UUID, error: Error?) {
        os_log("DID DISCONNECT FROM [%s]", log: log, type: .debug, uuid.uuidString)
        if let error = error {
            os_log("Error: [%s]", log: log, type: .error, error.localizedDescription)
        }
        
        for (letter, robot) in Shared.backendServer.connectedRobots {
            if robot.uuid == uuid {
                Shared.backendServer.connectedRobots[letter]?.isConnected = false
                Shared.backendServer.connectedRobots[letter] = nil
                Shared.frontendServer.notifyDeviceDidDisconnect(uuid: uuid)
            }
        }
    }

    func didFailToConnectTo(uuid: UUID, error: Error?) {
        os_log("DID FAIL TO CONNECT TO [%s] with error [%s]", log: log, type: .error, uuid.uuidString, error?.localizedDescription ?? "no error")
    }
}

