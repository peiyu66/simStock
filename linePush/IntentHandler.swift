//
//  IntentHandler.swift
//  linePush
//
//  Created by peiyu on 2020/4/9.
//  Copyright © 2020 unlock.com.tw. All rights reserved.
//

import Intents
import Foundation

@available(iOS 13.0, *)
class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        let line = linePushHandler()
        return line
    }
}

@available(iOS 13.0, *)
class linePushHandler:NSObject, LinePushIntentHandling {
    let bot = lineBot()
    func handle(intent: LinePushIntent, completion: @escaping (LinePushIntentResponse) -> Void) {
        if let message = intent.message {
            switch intent.to {
            case .team0:
                bot.pushTextMessage(to: "team0", message: message)
            case .team1:
                bot.pushTextMessage(to: "team1", message: message)
            case .team4:
                bot.pushTextMessage(to: "team4", message: message)
            case .team5:
                bot.pushTextMessage(to: "team5", message: message)
            default:
                bot.pushTextMessage(to: "user", message: message)
            }
        }
        let response = LinePushIntentResponse()
        completion(response)
    }
    
    func resolveTo(for intent: LinePushIntent, with completion: @escaping (ToResolutionResult) -> Void) {
        var result: ToResolutionResult = .unsupported()
        defer { completion(result) }
        let to = intent.to
        if to != .unknown {
          result = .success(with: to)
        }
    }
    
    func resolveMessage(for intent: LinePushIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        var result: INStringResolutionResult = .unsupported()
        defer { completion(result) }
        if let msg = intent.message {
            if msg.count > 0 {
              result = .success(with: msg)
            }
        }
    }
}



