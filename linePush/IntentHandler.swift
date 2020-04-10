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
        let linePush = linePushHandler()
        return linePush
    }
}

@available(iOS 13.0, *)
class linePushHandler:NSObject, LinePushIntentHandling {
    func handle(intent: LinePushIntent, completion: @escaping (LinePushIntentResponse) -> Void) {
        if let message = intent.message {
            let lineCode = myCode()
            switch intent.to {
            case .team0:
                pushTextMessage(to: lineCode.lineIdTeam0, message: message, token: lineCode.lineChannelToken)
            case .team1:
                pushTextMessage(to: lineCode.lineIdTeam1, message: message, token: lineCode.lineChannelToken)
            case .team4:
                pushTextMessage(to: lineCode.lineIdTeam4, message: message, token: lineCode.lineChannelToken)
            case .team5:
                pushTextMessage(to: lineCode.lineIdTeam5, message: message, token: lineCode.lineChannelToken)
            case .peiyu:
                pushTextMessage(to: lineCode.lineIdPeiyu, message: message, token: lineCode.lineChannelToken)
            default:
                break
            }
        }

        let response = LinePushIntentResponse()
        response.result = "OK"
        completion(response)
    }
    
    func pushTextMessage (to:String, message:String, token:String) {
        let textMessages1 = ["type":"text","text":message]
        let jsonMessages  = ["to":to,"messages":[textMessages1]] as [String : Any]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonMessages)

        let url = URL(string: "https://api.line.me/v2/bot/message/push")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                NSLog(error?.localizedDescription ?? "No response from LINE.")
                return
            }
            let responseJSONData = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSONData as? [String: Any] {
                if responseJSON.count > 0 {
                    NSLog("Response from LINE:\n\(responseJSON)\n")
                }
            }
        }
        task.resume()
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



