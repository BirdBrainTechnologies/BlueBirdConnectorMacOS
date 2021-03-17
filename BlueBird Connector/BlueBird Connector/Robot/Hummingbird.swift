//
//  Hummingbird.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os

class Hummingbird: Robot {
    var log: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "Hummingbird")
    
    var manageableRobot: ManageableRobot
    var currentRobotState: RobotState
    var nextRobotState: RobotState
    //var commandPending: Data?
    var commandPending: [UInt8]?
    var setAllTimer: SetAllTimer
    var isConnected: Bool
    var writtenCondition: NSCondition = NSCondition()
    var inProgressPrintID: Int = 0
    
    //Hummingbird specific values
    let buttonShakeIndex: Int = 7
    let accXindex: Int = 4
    let type: RobotType = .HummingbirdBit
    //let turnOffCommand: Data = Data(bytes: UnsafePointer<UInt8>([0xCB, 0xFF, 0xFF, 0xFF] as [UInt8]), count: 4)
    let turnOffCommand: [UInt8] = [0xCB, 0xFF, 0xFF, 0xFF]
    
    internal var accelerometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        return [rawToAccelerometer(rawAcc[0]), rawToAccelerometer(rawAcc[1]), rawToAccelerometer(rawAcc[2])]
    }
    internal var magnetometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return [Double(rawToMagnetometer(raw[8], raw[9])), Double(rawToMagnetometer(raw[10], raw[11])), Double(rawToMagnetometer(raw[12], raw[13]))]
    }
    
    
    //MARK: Public calculated values
    
    var V2sound: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        return Int(raw[14])
    }
    
    var V2temperature: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        return Int(raw[15])
    }
    
    var compass: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        let rawMag = Array(raw[8...13])
        return rawToCompass(rawAcc: rawAcc, rawMag: rawMag) ?? 0
    }
    
    
    //MARK: init
    required init(_ mRobot: ManageableRobot) {
        self.manageableRobot = mRobot
        isConnected = true
        currentRobotState = RobotState(robotType: .HummingbirdBit)
        nextRobotState = currentRobotState
        setAllTimer = SetAllTimer()
        setAllTimer.setRobot(self)
        setAllTimer.resume()
    }
    
    
    //MARK: Internal methods
    
    /**
       Get the command to set the led array to its next value.
    */
    //internal func getAdditionalCommand(_ nextCopy: RobotState) -> Data? {
    internal func getAdditionalCommand(_ nextCopy: RobotState) -> [UInt8]? {
        guard nextCopy.ledArray != currentRobotState.ledArray,
        nextCopy.ledArray != RobotState.flashSent,
            let ledArrayCommand = nextCopy.ledArrayCommand() else {
            return nil
        }
        
        if nextCopy.ledArray.starts(with: "F") {
            os_log("Setting flash sent...", log: log, type: .debug)
            nextRobotState.ledArray = RobotState.flashSent
        }
        
        return ledArrayCommand
    }
    
    
    //MARK: - Public Methods
    
    /**
        Get the raw value of the sensor at a given port
     */
    func getHummingbirdSensor(_ port: Int) -> UInt8? {
        if (port > 3 || port < 1) { return nil }
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return raw[port - 1]
    }
    
    /**
        Set the intensities of the tri-led at the specified port
     */
    func setTriLED(port: Int, R: UInt8, G: UInt8, B: UInt8) -> Bool {
        let i = port - 1
        return setOutput(ifCheck: (port > 0 && port <= 2),
                         when: {self.nextRobotState.trileds[i] == self.currentRobotState.trileds[i]},
                         set: {self.nextRobotState.trileds[i] = TriLED(R, G, B)})
    }
    
    /**
        Set the intensity of the led at the specified port
     */
    func setLED(port: Int, intensity: UInt8) -> Bool {
        let i = port - 1
        return setOutput(ifCheck: (port > 0 && port <= 3),
                         when: {self.nextRobotState.leds[i] == self.currentRobotState.leds[i]},
                         set: {self.nextRobotState.leds[i] = intensity})
    }
    
    /**
        Set the value of the servo at the given port
     */
    func setServo(port: Int, value: UInt8) -> Bool {
        let i = port - 1
        return setOutput(ifCheck: (port > 0 && port <= 4),
            when: {self.nextRobotState.servos[i] == self.currentRobotState.servos[i]},
            set: {self.nextRobotState.servos[i] = value})
    }
}
