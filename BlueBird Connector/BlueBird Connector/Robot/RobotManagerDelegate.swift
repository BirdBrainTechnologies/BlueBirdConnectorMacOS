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
    
    /**
        When the manager is enabled, start scan immediately. The frontendServer will notify
        the frontend of the change automatically. When disabled, just notify the frontend.
        The manager sends an update at the start of the program, and whenever the user
        enables or disables ble.
     */
    func didUpdateState(to state: UARTDeviceManagerState) {
        os_log("UARTDeviceManagerDelegate.didUpdateState to: [%{public}s]", log: log, type: .debug, state.rawValue)
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
    /**
        Called when a new device is discovered. Send the info to update the frontend.
     */
    func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        
        os_log("DID DISCOVER [%{public}s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
        guard let advertisementSignature = advertisementSignature else {
            os_log("Ignoring device [%{public}s] because it is missing advertisement info.", log: log, type: .debug, uuid.uuidString)
            return
        }
        
        Shared.frontendServer.notifyDeviceDiscovery(uuid: uuid, advertisementSignature: advertisementSignature, rssi: rssi)
        
    }
    /**
        Called when a previously discovered device is seen again. Update frontend if there
        are changes in the info.
     */
    func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {
        os_log("DID REDISCOVER [%{public}s]", log: log, type: .debug, advertisementSignature?.advertisedName ?? "unknown")
        
        Shared.frontendServer.updateDeviceInfo(uuid: uuid, adSig: advertisementSignature, rssi: rssi)

    }
    /**
        Called when a device hasn't been seen in a while.
     */
    func didDisappear(uuid: UUID) {
        os_log("DID DISAPPEAR [%{public}s]", log: log, type: .debug, uuid.uuidString)
        Shared.frontendServer.notifyDeviceDidDisappear(uuid: uuid)
    }
    /**
        Called when a connection to a device has been established. Make sure everything is set
        up properly, add the device to the backend's list of connected devices, and then notify the
        frontend.
     */
    func didConnectTo(uuid: UUID) {
        os_log("DID CONNECT TO [%{public}s]", log: log, type: .debug, uuid.uuidString)
        guard let mRobot = Shared.robotManager.getDevice(uuid: uuid) else {
            os_log("Connected robot not found with uuid [%{public}s]", log: log, type: .error, uuid.uuidString)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
            return
        }
        
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
        
        //var letterAssigned = false
        var letterAssigned: DeviceLetter?
        if let letter = Shared.frontendServer.availableDevices[uuid]?.shouldAutoConnectAs, Shared.backendServer.connectedRobots[letter] == nil {
            letterAssigned = letter
        } else {
            for devLetter in DeviceLetter.allCases {
                if (letterAssigned == nil && Shared.backendServer.connectedRobots[devLetter] == nil) {
                    letterAssigned = devLetter
                }
            }
        }
        if let l = letterAssigned {
            Shared.backendServer.connectedRobots[l] = robot
            Shared.frontendServer.notifyDeviceDidConnect(uuid: uuid, name: robot.name, fancyName: robot.fancyName, deviceLetter: l)
        } else {
            os_log("Too many connections", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
        }
        /*for devLetter in DeviceLetter.allCases {
            if !letterAssigned && Shared.backendServer.connectedRobots[devLetter] == nil {
                Shared.backendServer.connectedRobots[devLetter] = robot
                letterAssigned = true
                Shared.frontendServer.notifyDeviceDidConnect(uuid: uuid, name: robot.name, fancyName: robot.fancyName, deviceLetter: devLetter)
            }
        }
        
        if !letterAssigned {
            os_log("Too many connections", log: log, type: .error)
            let _ = Shared.robotManager.disconnectFromDevice(havingUUID: uuid)
        }*/
    }
    /**
        Helper function creates a robot object of the correct type for the given connected device.
     */
    private func robotFactory(_ mRobot: ManageableRobot) -> Robot? {
        let prefix = mRobot.advertisementSignature?.advertisedName.prefix(2) ?? "XX"
        switch prefix {
        case "FN": return Finch(mRobot)
        case "BB": return Hummingbird(mRobot)
        case "MB": return Microbit(mRobot)
        default: return nil
        }
    }
    /**
        Called when a device disconnects either by user choice or otherwise.
     */
    func didDisconnectFrom(uuid: UUID, error: Error?) {
        os_log("DID DISCONNECT FROM [%{public}s]", log: log, type: .debug, uuid.uuidString)
        if let error = error {
            os_log("Error: [%{public}s]", log: log, type: .error, error.localizedDescription)
        }
        
        for (letter, robot) in Shared.backendServer.connectedRobots {
            if robot.uuid == uuid {
                Shared.backendServer.connectedRobots[letter]?.isConnected = false
                Shared.backendServer.connectedRobots[letter] = nil
                Shared.frontendServer.notifyDeviceDidDisconnect(uuid: uuid)
            }
        }
    }
    /**
        Called on connection failure.
     */
    func didFailToConnectTo(uuid: UUID, error: Error?) {
        os_log("DID FAIL TO CONNECT TO [%{public}s] with error [%{public}s]", log: log, type: .error, uuid.uuidString, error?.localizedDescription ?? "no error")
    }
}

