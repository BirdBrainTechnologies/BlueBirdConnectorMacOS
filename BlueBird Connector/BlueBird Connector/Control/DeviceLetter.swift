//
//  DeviceLetter.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation

enum DeviceLetter: CaseIterable {
    case A, B, C
    
    func toString() -> String {
        switch self{
        case .A: return "A"
        case .B: return "B"
        case .C: return "C"
        }
    }
    
    static func fromString(_ string: String) -> DeviceLetter? {
        switch string {
        case "A": return .A
        case "B": return .B
        case "C": return .C
        default: return nil
        }
    }
}
