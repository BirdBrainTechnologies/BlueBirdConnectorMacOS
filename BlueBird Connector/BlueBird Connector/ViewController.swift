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
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self.frontendServer, name: "serverSubstitute")
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: self.view.bounds, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html"), let resourceDir = Bundle.main.resourcePath else {
            NSLog("Unable to find frontend resources")
            return
        }
        
        let html = URL(fileURLWithPath: htmlPath)
        let dir = URL(fileURLWithPath: resourceDir, isDirectory: true)
        self.webView.loadFileURL(html, allowingReadAccessTo: dir)
        
        print("add view")
        self.view.addSubview(self.webView)
        
       /* let js = """
            
                window.webkit.messageHandlers.serverSubstitute.postMessage({paramter1 : "value1", parameter2 : "value2"})
            
        """
        self.webView.evaluateJavaScript(js) { (response, error) in
            if let _ = error {
                print("error: \(error)")
            }
            else {
                print("response: \(response)")
            }
        }*/
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func sendToFrontend(_ javascript: String) {
        self.webView.evaluateJavaScript(javascript) { (response, error) in
            if let _ = error {
                print("error: \(error)")
            }
            else {
                print("response: \(response)")
            }
        }
    }

    //MARK: WKNavigationDelegate methods
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail provisional navigation %@", error as NSError)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("did fail navigation %@", error as NSError)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NSLog("didFinish navigation")
        self.webView.evaluateJavaScript("alert('Hello from evaluateJavascript()')", completionHandler: nil)
    }

}

