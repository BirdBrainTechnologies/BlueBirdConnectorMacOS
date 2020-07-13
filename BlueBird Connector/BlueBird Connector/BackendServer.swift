//
//  BackendServer.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 7/4/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Foundation
import Swifter

class BackendServer {
    let server: HttpServer
    
    public init() {
        server = HttpServer()
        
        setupPaths()
        
        do {
            try server.start(30061)
            print("Server has started ( port = \(try server.port()) ). Try to connect now...")
        } catch {
            print("Server start error: \(error)")
        }
        
    }
    
    private func setupPaths() {
        server["/hummingbird/out/"] = { request in
            print ("Got a start request \(request) \(request.path)")
            return HttpResponse.ok(.text("<html string>"))
        }
        /*server["/hummingbird/out/:command/:robot/:dir/:dist/:speed"] = { request in
            print ("Got a request \(request) \(request.path)")
            return HttpResponse.ok(.text("<html string>"))
        }*/
        server["/hummingbird/out/move/:robot/:dir/:dist/:speed"] = finchMove(_:)
        server["/"] = { request in
            print ("Got a request \(request)")
            return HttpResponse.ok(.text("<html string>"))
        }
    }
    
    private func finchMove (_ request: HttpRequest) -> HttpResponse {
        print ("Got a request \(request.path)")
        return HttpResponse.ok(.text("<html string>"))
    }
    
    
}
