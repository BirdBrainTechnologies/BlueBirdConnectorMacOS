//
//  ManageableRobot.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE
import os

class ManageableRobot: ManageableUARTDevice {

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "ManageableRobot")
    
    static public let scanFilter: UARTDeviceScanFilter = AdvertisedNamePrefixesScanFilter(prefixes: ["FN", "BB", "MB"])
    
    private var uartDevice: UARTDevice      // Required by the Bluetooth package
    public var uuid: UUID {         // Used by the Bluetooth package
        uartDevice.uuid
    }
    public var advertisementSignature: AdvertisementSignature? {
        uartDevice.advertisementSignature
    }
    
    var notificationsRunning: Bool
    private var rawInputState: RawInputState?
    public var rawInputData: Data? {
        return rawInputState?.data
    }
    private var batteryStatus: BatteryStatus?
    private var type: RobotType
    private var isCalibrating: Bool
    
    public required init (blePeripheral: BLEPeripheral) {
        self.uartDevice = BaseUARTDevice(blePeripheral: blePeripheral)
        self.notificationsRunning = self.uartDevice.startStateChangeNotifications()
        let prefix = self.uartDevice.advertisementSignature?.advertisedName.prefix(2) ?? ""
        self.type = RobotType.getTypeFromPrefix(prefix)
        self.isCalibrating = false
        self.uartDevice.delegate = self
    }
    
    func sendData(_ data: Data) {
        uartDevice.writeWithoutResponse(data: data)
    }
    
    func startCalibration() {
        sendData(RobotConstants.CALIBRATE_COMMAND)
        //Give calibration a chance to start. Otherwise, we will read an
        // old calibration result in the notification data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isCalibrating = true
        }
    }
    
}


extension ManageableRobot: UARTDeviceDelegate {
    
    /* This function determines what happens when the Bluetooth device changes whether or not it is sending notifications. */
    public func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool) {
        os_log("uartDevice isSendingChangeNotifications [%{public}s]", log: log, type: .debug, String(describing: isSendingStateChangeNotifications))
        self.notificationsRunning = isSendingStateChangeNotifications
    }
    
    /* This function determines what happens when the Bluetooth device has new data. */
    public func uartDevice(_ device: UARTDevice, newState stateData: Data) {
        guard let rawState = RawInputState(data: stateData, type: type) else {
            os_log("uartDevice [%{public}s] state update fail", log: log, type: .error, self.advertisementSignature?.advertisedName ?? "unknown")
            self.rawInputState?.isStale = true
            return
        }
        
        self.rawInputState = rawState
        
        //Check the state of compass calibration
        if self.isCalibrating {
            var index = 7
            if type == .Finch { index = 16 }
            let byte = rawState.data[index]
            let bits = byteToBits(byte)
            os_log("CALIBRATION VALUES %{public}d %{public}d", log: log, type: .debug, bits[2], bits[3])
            
            if bits[3] == 1 {
                self.isCalibrating = false
                os_log("CALIBRATION FAILED %{public}s", log: log, type: .debug, bits.description)
                Shared.frontendServer.notifyCalibrationResult(false)
            } else if bits[2] == 1 {
                self.isCalibrating = false
                os_log("CALIBRATION SUCCESSFUL %{public}s", log: log, type: .debug, bits.description)
                Shared.frontendServer.notifyCalibrationResult(true)
            } else {
                os_log("CALIBRATION UNKNOWN %{public}s", log: log, type: .debug, bits.description)
            }
        }
        
        //Check battery status.
        if let i = type.batteryVoltageIndex, let greenThreshold = type.batteryGreenThreshold, let yellowThreshold = type.batteryYellowThreshold {
            //let voltage = rawToVoltage( lastSensorUpdate[i] )
            let voltage = (Double(rawState.data[i]) + self.type.batteryConstant) * self.type.rawToBatteryVoltage
            
            
            let newStatus: BatteryStatus
            if let oldStatus = self.batteryStatus {
                switch oldStatus {
                case .green:
                    if voltage < yellowThreshold {
                        newStatus = .red
                    } else if voltage < greenThreshold - 0.05 {
                        newStatus = .yellow
                    } else {
                        newStatus = .green
                    }
                case .yellow:
                    if voltage > greenThreshold + 0.05 {
                        newStatus = .green
                    } else if voltage < yellowThreshold - 0.05 {
                        newStatus = .red
                    } else {
                        newStatus = .yellow
                    }
                case .red:
                    if voltage > greenThreshold {
                        newStatus = .green
                    } else if voltage > yellowThreshold + 0.05 {
                        newStatus = .yellow
                    } else {
                        newStatus = .red
                    }
                }
            } else {
                if voltage > greenThreshold {
                    newStatus = BatteryStatus.green
                } else if voltage > yellowThreshold {
                    newStatus = BatteryStatus.yellow
                } else {
                    newStatus = BatteryStatus.red
                }
            }
            
            if self.batteryStatus != newStatus {
                self.batteryStatus = newStatus
                //let _ = FrontendCallbackCenter.shared.robotUpdateBattery(id: self.peripheral.identifier.uuidString, batteryStatus: newStatus.rawValue)
                Shared.frontendServer.notifyDeviceBatteryUpdate(uuid: uuid, newState: newStatus)
            }
        }
    }
    
    /* This function determines what happens when the Bluetooth devices gets an error instead of data. */
    public func uartDevice(_ device: UARTDevice, errorGettingState error: Error) {
        self.rawInputState?.isStale = true
        os_log("uartDevice [%{public}s] error getting state [%{public}s]", log: log, type: .error, device.advertisementSignature?.advertisedName ?? "unknown", error.localizedDescription)
    }
}



/* This structure contains the raw bytes sent by the Robot over Bluetooth, along with a timestamp for the data. */
public struct RawInputState {
    public let timestamp: Date
    public let data: Data
    public fileprivate(set) var isStale: Bool   // is the data old?
    
    init?(data: Data, type: RobotType) {
        if data.count == type.expectedRawStateByteCount {
            self.timestamp = Date()
            self.data = data
            self.isStale = false
        } else {
            return nil
        }
    }
}

