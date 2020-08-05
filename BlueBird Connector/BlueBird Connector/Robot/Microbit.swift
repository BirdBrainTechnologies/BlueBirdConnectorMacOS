//
//  Microbit.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os

class Microbit: Robot {
    var log: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "Microbit")
    
    var manageableRobot: ManageableRobot
    var currentRobotState: RobotState
    var nextRobotState: RobotState
    var commandPending: Data?
    var setAllTimer: SetAllTimer
    var isConnected: Bool
    var writtenCondition: NSCondition = NSCondition()
    
    //Microbit specific values
    var buttonShakeIndex: Int = 7
    var accXindex: Int = 4
    
    internal var accelerometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        return [rawToAccelerometer(rawAcc[0]), rawToAccelerometer(rawAcc[1]), rawToAccelerometer(rawAcc[2])]
    }
    internal var magnetometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return [Double(rawToMagnetometer(raw[8], raw[9])), Double(rawToMagnetometer(raw[10], raw[11])), Double(rawToMagnetometer(raw[12], raw[13]))]
    }
    
    var compass: Int {
        guard let raw = self.manageableRobot.rawInputData else { return 0 }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        let rawMag = Array(raw[8...13])
        return rawToCompass(rawAcc: rawAcc, rawMag: rawMag) ?? 0
    }
    
    required init(_ mRobot: ManageableRobot) {
        self.manageableRobot = mRobot
        isConnected = true
        currentRobotState = RobotState(robotType: .MicroBit)
        nextRobotState = currentRobotState
        setAllTimer = SetAllTimer()
        setAllTimer.setRobot(self)
        setAllTimer.resume()
    }
    
    internal func getAdditionalCommand(_ nextCopy: RobotState) -> Data? {
        guard nextCopy.ledArray != currentRobotState.ledArray,
        nextCopy.ledArray != RobotState.flashSent,
            let ledArrayCommand = nextCopy.ledArrayCommand() else {
            return nil
        }
        
        if nextCopy.ledArray.starts(with: "F") {
            print("And now setting to \(RobotState.flashSent)")
            nextRobotState.ledArray = RobotState.flashSent
        }
        
        return ledArrayCommand
    }
}
