//
//  RobotType.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation

enum RobotType {
    case Finch
    case HummingbirdBit
    case MicroBit
    case Unknown
    
    static func getTypeFromPrefix(_ prefix: Substring) -> RobotType {
        switch prefix {
        case "FN": return .Finch
        case "BB": return .HummingbirdBit
        case "MB": return .MicroBit
        default: return .Unknown
        }
    }
    
    
    func expectedRawStateByteCount(_ hasV2: Bool) -> Int {
        switch self {
        case .Finch: return 20
        case .HummingbirdBit, .MicroBit:
            return hasV2 ? 16 : 14
        case .Unknown: return 0
        }
    }
    
    
    //MARK: Battery Thresholds
    var batteryVoltageIndex: Int? {
        switch self{
        case .HummingbirdBit: return 3
        case .Finch: return 6
        case .MicroBit: return nil
        case .Unknown: return nil
        }
    }
    var rawToBatteryVoltage: Double {
        switch self {
        case .Finch: return 0.00937
        default: return 0.0406
        }
    }
    var batteryConstant: Double { //value to add to raw before conversion
        switch self {
        case .Finch: return 320
        default: return 0
        }
    }
    var batteryGreenThreshold: Double? { //battery must be > this value for green status
        switch self {
        case .HummingbirdBit: return 4.75
        case .Finch: return 3.51375 //3.385
        case .MicroBit: return nil
        case .Unknown: return nil
        }
    }
    var batteryYellowThreshold: Double? { //battery must be > this value for yellow status
        switch self {
        //case .HummingbirdBit, .Hummingbird: return 4.63
        case .HummingbirdBit: return 4.4
        case .Finch: return 3.3732 //3.271
        case .MicroBit: return nil
        case .Unknown: return nil
        }
    }
}
