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
    }
    
    
    //MARK: - Public Methods
    
    func getHummingbirdSensor(_ port: Int) -> UInt8? {
        if (port > 3 || port < 1) { return nil }
        guard let raw = self.manageableRobot.rawInputData else { return nil }
        return raw[port - 1]
    }
    
    func setTriLED(port: Int, R: Int, G: Int, B: Int) {
        
    }
}
