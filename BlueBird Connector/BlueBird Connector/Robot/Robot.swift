//
//  Robot.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/3/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import BirdbrainBLE
import os

protocol Robot {
    
    var log: OSLog { get }
    
    var manageableRobot: ManageableRobot { get }
    var currentRobotState: RobotState { set get }
    var nextRobotState: RobotState { set get }
    var commandPending: Data? { set get }
    var setAllTimer: SetAllTimer { get }
    var isConnected: Bool { set get }
    var writtenCondition: NSCondition { get }
    
    //Robot specific
    var buttonShakeIndex: Int { get }
    var accXindex: Int { get }
    
    //calculated values
    var accelerometer: [Double]? { get }
    var magnetometer: [Double]? { get }
    var compass: Int { get }
 
    init(_ mRobot: ManageableRobot)
    
    func getAdditionalCommand(_ nextCopy: RobotState) -> Data?
}

extension Robot {
    
    
    var name: String {
        return manageableRobot.advertisementSignature?.advertisedName ?? ""
    }
    var fancyName: String {
        return manageableRobot.advertisementSignature?.memorableName ?? manageableRobot.advertisementSignature?.advertisedName ?? ""
    }
    var uuid: UUID {
        return manageableRobot.uuid
    }
    //calculated private values
    private var buttonShakeBits: [UInt8]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return byteToBits(raw[buttonShakeIndex])
    }
    
    
    var buttonA: Bool {
        return (buttonShakeBits?[4] == 0)
    }
    var buttonB: Bool {
        return (buttonShakeBits?[5] == 0)
    }
    var shake: Bool {
        return (buttonShakeBits?[0] == 1)
    }
    var accX: Double {
        return accelerometer?[0] ?? 0
    }
    var accY: Double {
        return accelerometer?[1] ?? 0
    }
    var accZ: Double {
        return accelerometer?[2] ?? 0
    }
    var magX: Int {
        return Int(magnetometer?[0].rounded() ?? 0)
    }
    var magY: Int {
        return Int(magnetometer?[1].rounded() ?? 0)
    }
    var magZ: Int {
        return Int(magnetometer?[2].rounded() ?? 0)
    }
    
    mutating func setAll() {

        if let command = self.commandPending {
            print("sending a pending command.")
            self.manageableRobot.sendData(command)
            self.commandPending = nil
            return
        }
        
        
        let nextCopy = self.nextRobotState
        let changeOccurred = !(nextCopy == self.currentRobotState)

        guard changeOccurred else { return }
     
        let command = nextCopy.setAllCommand()
        let oldCommand = currentRobotState.setAllCommand()
        
        //reset the buzzer state so a buzzer command is only sent once
        if (nextCopy.buzzer != nil) && (nextCopy.buzzer == self.nextRobotState.buzzer) {
            self.nextRobotState.buzzer = Buzzer()
        }
        
        var sentSetAll = false
        if command != oldCommand {
            var commandArray: [UInt8] = []
            commandArray = Array(command)
            NSLog("Sending set all. \(commandArray)")
            //self.sendData(data: command)
            self.manageableRobot.sendData(command)
            sentSetAll = true
        }
        
        if let additionalCommand = getAdditionalCommand(nextCopy) {
            if sentSetAll {
                commandPending = additionalCommand
            } else {
                self.manageableRobot.sendData(additionalCommand)
            }
        }
        
        currentRobotState = nextCopy
        
    }
    
    /**
     * Set a specific output to be set next time setAll is sent.
     * Returns false if this output cannot be set
     */
    func setOutput(ifCheck isValid: Bool, when predicate: (() -> Bool), set work: (() -> ())) -> Bool {
        
        guard isConnected else {
            os_log("Tried to set output on disconnected device [%s]", log: log, type: .error, self.name)
            return false
        }
        if !isValid {
            os_log("Tried to set output on device [%s] with invalid check", log: log, type: .error, self.name)
            return false
        }
        
        writtenCondition.lock()
        
        while !predicate() && isConnected {
            print("waiting...")
            writtenCondition.wait(until: Date(timeIntervalSinceNow: 0.05))
        }
        
        work()
        
        writtenCondition.signal()
        writtenCondition.unlock()
        
        return true
    }
    
}


