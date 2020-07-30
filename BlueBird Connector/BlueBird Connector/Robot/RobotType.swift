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
    case Hummingbird
    case Microbit
    case Unknown
    
    static func getTypeFromPrefix(_ prefix: Substring) -> RobotType {
        switch prefix {
        case "FN": return .Finch
        case "BB": return .Hummingbird
        case "MB": return .Microbit
        default: return .Unknown
        }
    }
    
    var stringDescribing: String {
        switch self {
        case .Finch: return "Finch"
        case .Hummingbird: return "Hummingbird"
        case .Microbit: return "micro:bit"
        case .Unknown: return "UNKNOWN"
        }
    }
    
    var expectedRawStateByteCount: Int {
        switch self {
        case .Finch: return 20
        case .Hummingbird: return 14
        case .Microbit: return 14
        case .Unknown: return 0
        }
    }
}
