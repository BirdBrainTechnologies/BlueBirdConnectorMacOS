//
//  ViewController.swift
//  BlueBird Connector
//
//  Created by Kristina Lauwers on 6/30/20.
//  Copyright © 2020 BirdBrain Technologies. All rights reserved.
//

import Cocoa
import WebKit


class ViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
    
    var webView = WKWebView()
    let frontendServer = FrontendServer()
    
    
    /*override func loadView() {
        //let config = WKWebViewConfiguration()
        //let contentController = WKUserContentController()
        //contentController.add(self.frontendServer, name: "frontendServer")
        //config.userContentController = contentController
        
        //self.webView = WKWebView(frame: self.view.bounds, configuration: config)
        //self.webView = WKWebView()
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        self.webView.navigationDelegate = self
        view = webView
    }*/

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewdidload")
        self.webView = WKWebView(frame: self.view.bounds)
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        //guard let bundleLocation = URL(string: Bundle.main.bundleURL.path) else {
        //    NSLog("Could not find bundle location")
        //    return
        //}
        /*guard let bundleLocation = URL(string: Bundle.main.bundlePath) else {
            NSLog("Could not find bundle location")
            return
        }*/
        
        /*print(Bundle.main.path(forResource: "prototype", ofType: "html"))
        
        let bundleLocation = Bundle.main.bundleURL
        let frontendFolder = URL(fileURLWithPath: bundleLocation.appendingPathComponent("BlueBird Connector/Frontend").path)
        let frontendPage = frontendFolder.appendingPathComponent("prototype.html")
        print(frontendPage)
        self.webView.loadFileURL(frontendPage, allowingReadAccessTo: frontendFolder)*/
        //self.webView.loadHTMLString(<#T##string: String##String#>, baseURL: <#T##URL?#>)
        
        guard let htmlPath = Bundle.main.path(forResource: "prototype", ofType: "html"), let resourceDir = Bundle.main.resourcePath else {
            NSLog("Unable to find frontend resources")
            return
        }
        print(htmlPath)
        print(resourceDir)
        
        do {
            let list = try FileManager.default.contentsOfDirectory(atPath: resourceDir)
            print(list)
        } catch {
            print("fail")
        }
        
        let html = URL(fileURLWithPath: htmlPath)
        let dir = URL(fileURLWithPath: resourceDir, isDirectory: true)
        self.webView.loadFileURL(html, allowingReadAccessTo: dir)
        
        print("add view")
        self.view.addSubview(self.webView)
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

