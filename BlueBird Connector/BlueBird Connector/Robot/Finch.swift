//
//  Finch.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 8/2/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import os

class Finch: Robot {

    var log: OSLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BlueBird-Connector", category: "Finch")
    
    var manageableRobot: ManageableRobot
    
    //Finch specific values
    var buttonShakeIndex: Int = 16
    var accXindex: Int = 13
    
    internal var accelerometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        let rawAcc = Array(raw[accXindex...(accXindex + 2)])
        let rawFinchAcc = rawToRawFinchAccelerometer(rawAcc)
        return [rawToAccelerometer(rawFinchAcc[0]), rawToAccelerometer(rawFinchAcc[1]), rawToAccelerometer(rawFinchAcc[2])]
    }
    internal var magnetometer: [Double]? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return rawToFinchMagnetometer(Array(raw[17...19]))
    }
    private var currentBeak: TriLED? { //TODO: this.
        return TriLED(100, 100, 100)
    }
    
    var compass: Int {
        if let acc = accelerometer, let mag = magnetometer, let compass = DoubleToCompass(acc: acc, mag: mag) {
            //turn it around so that the finch beak points north at 0
            return (compass + 180) % 360
        } else {
            return 0
        }
    }
    
    var finchDistance: Int? {
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        let msb = Int(raw[0])
        let lsb = Int(raw[1])
        return (msb << 8) + lsb
    }
    
    required init(_ mRobot: ManageableRobot) {
        self.manageableRobot = mRobot
    }
    
    
    //MARK: - Public Methods
    
    func getFinchLight(onRight getRightLightSensor: Bool) -> Int? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
        //We must add a correction to remove the light cast by the finch beak
        guard let currentBeak = currentBeak else { return nil }
        let R = Double(currentBeak.red) / 2.55
        let G = Double(currentBeak.green) / 2.55
        let B = Double(currentBeak.blue) / 2.55
        
        var correction = 0.0
        var raw = 0.0
        if getRightLightSensor {
            correction = 6.40473070e-03*R + 1.41015162e-02*G + 5.05547817e-02*B + 3.98301391e-04*R*G + 4.41091223e-04*R*B + 6.40756862e-04*G*B + -4.76971242e-06*R*G*B
            raw = Double(rawData[3])
        } else {
            correction = 1.06871493e-02*R + 1.94526614e-02*G + 6.12409825e-02*B + 4.01343475e-04*R*G + 4.25761981e-04*R*B + 6.46091068e-04*G*B + -4.41056971e-06*R*G*B
            raw = Double(rawData[2])
        }
        print("correcting raw light value \(raw) with \(R), \(G), \(B) -> \(correction)")
        let finalVal = raw - correction
        return bound(Int(finalVal.rounded()), min: 0, max: 100)
    }
    func getFinchLine(onRight getRightLineSensor: Bool) -> Int? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
        var raw: UInt8
        if getRightLineSensor {
            raw = rawData[5]
        } else {
            //the value for the left line sensor also contains the move flag
            raw = rawData[4]
            if raw > 127 { raw -= 128 }
        }
        let final = bound(100 - Int(round(Double(raw - 6) * 100/121)), min: 0, max: 100)
        return final
    }
    func getFinchEncoder(onRight getRightEncoder: Bool) -> Double? {
        guard let rawData = self.manageableRobot.rawInputData else { return nil }
        var i = 7
        if getRightEncoder { i = 10 }
        
        let uNum = (UInt32(rawData[i]) << 24) + (UInt32(rawData[i+1]) << 16) + (UInt32(rawData[i+2]) << 8)
        let num = Int32(bitPattern: uNum) / 256
        return (Double(num) * 1/792)
    }
    
    func setMotors(leftSpeed: Double, leftTicks: Int, rightSpeed: Double, rightTicks: Int) {
        
    }
    func setTriLED(port: Int, R: Int, G: Int, B: Int) {
        
    }
}

struct FinchConstants {
    static public let FINCH_TICKS_PER_CM = 49.7;
    static public let FINCH_TICKS_PER_DEGREE = 4.335;
}
