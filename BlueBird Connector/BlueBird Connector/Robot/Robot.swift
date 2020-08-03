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
    
    //Robot specific
    var buttonShakeIndex: Int { get }
    var accXindex: Int { get }
    
    var accelerometer: [Double]? { get }
    var magnetometer: [Double]? { get }
    var compass: Int { get }
 
    init(_ mRobot: ManageableRobot)
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
    
    
    
}


