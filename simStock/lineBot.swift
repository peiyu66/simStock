//
//  self.swift
//  simStock
//
//  Created by peiyu on 2017/6/9.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import Foundation
import LineSDK  //v4.1.1
import Intents

class lineBot:NSObject, LineSDKLoginDelegate {
    
//  這裡記錄了LINE的token, group Id, user Id等明碼，定義於myCode.swift
//    class myCode:NSObject {
//        let lineChannelToken = "???"
//        let lineIdPeiyu:String = "???"
//        let lineIdTeam0:String = "???"
//        let lineIdTeam1:String = "???"
//        let lineIdTeam2:String = "???"
//        let lineIdTeam3:String = "???"
//        let lineIdTeam4:String = "???"
//        let lineIdTeam5:String = "???"
//        let keychainGroup = "???""
//        let appGroup = "???"
//    }

    let lineCode:myCode = myCode()
    var userProfile:LineSDKProfile?
    var lineClient:LineSDKAPI = LineSDKAPI(configuration: LineSDKConfiguration.defaultConfig())


    override init() {
        super.init()
        LineSDKLogin.sharedInstance().delegate = self
    }


    func pushTextMessage (to:String="user", message:String="") {
        var toUser:String = ""
        if let u = self.userProfile {
            if to == "team" && u.userID == lineCode.lineIdPeiyu {
                toUser = lineCode.lineIdTeam0
            } else if to == "team0" {
                toUser = lineCode.lineIdTeam0
            } else if to == "team1" {
                toUser = lineCode.lineIdTeam1
            } else if to == "team2" {
                toUser = lineCode.lineIdTeam2
            } else if to == "team3" {
                toUser = lineCode.lineIdTeam3
            } else if to == "team4" {
                toUser = lineCode.lineIdTeam4
            } else if to == "team5" {
                toUser = lineCode.lineIdTeam5
            } else {
                toUser = u.userID
            }
        } else {
            return
        }

        let textMessages1 = ["type":"text","text":message]
        let jsonMessages  = ["to":toUser,"messages":[textMessages1]] as [String : Any]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonMessages)

        let url = URL(string: "https://api.line.me/v2/bot/message/push")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(lineCode.lineChannelToken)", forHTTPHeaderField: "Authorization")

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
    
    @available(iOS 13.0, *)
    func donatePushMessage() {
        if let u = userProfile {
            let defaults = UserDefaults(suiteName: lineCode.appGroup)
            defaults?.set(u.userID, forKey: "userID@LINE")

            let intent = LinePushIntent()
            intent.suggestedInvocationPhrase = "小確幸傳送訊息給我"
            intent.to = .user
            intent.message = "嗨。"
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.groupIdentifier = "linePush"
            interaction.donate { (error) in
                if let error = error as NSError? {
                    NSLog("Interaction donation failed: \(error.description)")
                } else {
                    NSLog("donated:賴訊息")
                }
            }
        }
    }


    func didLogin(_ login: LineSDKLogin, credential: LineSDKCredential?, profile: LineSDKProfile?, error: Error?) {

        if let error = error {
            NSLog("LINE login failed with error: \(error.localizedDescription)\n")
            return
        }
        guard let profile = profile, let credential = credential, let _ = credential.accessToken else {
            NSLog("LINE invalid profile.\n")
            return
        }

        NSLog("LINE login succeeded, id:\(profile.userID) name:\(profile.displayName).")
        self.userProfile = profile
        if #available(iOS 13.0, *) {
            donatePushMessage()
        }


    }

    func verifyToken() {
        lineClient.verifyToken(queue: .main) {(result, error) in
            if let error = error {
                NSLog("LINE verifing token but Invalid: \(error.localizedDescription)\n")
                self.refreshToken()
                return
            }
            guard let result = result, let _ = result.permissions else {
                NSLog("LINE verifing token but null.\n")
                self.refreshToken()
                return
            }
            NSLog("LINE token is valid.") // with permission:\n\(permissions)")
            self.getProfile()
        }
    }

    func refreshToken() {
        lineClient.refreshToken(queue: .main) {(accessToken, error) in
            if let error = error {
                NSLog("LINE refreshing token error: \(error.localizedDescription)\n")
                LineSDKLogin.sharedInstance().start()
                return
            }
            guard let _ = accessToken else {
                NSLog ("LINE refreshing token but null.\n")
                LineSDKLogin.sharedInstance().start()
                return
            }
            NSLog("LINE access token was refreshed.")
        }
    }


    func getProfile() {
        lineClient.getProfile(queue: .main) {
            (profile, error) in
            self.userProfile = nil
            if let error = error {
                NSLog("LINE getting profile error: \(error.localizedDescription)\n")
                return
            }
            if let p = profile {
                self.userProfile = p
                NSLog("LINE get profile for \(profile!.displayName).")
                if #available(iOS 13.0, *) {
                    self.donatePushMessage()
                }
            } else {
                NSLog("LINE profile is null.\n")
            }
        }
    }

    func logout() {
        lineClient.logout(queue: .main) {
            (success, error) in
            if let error = error {
                NSLog("LINE logout error: \(error.localizedDescription)\n")
                return
            }
            NSLog("LINE logout.\n")
            INInteraction.delete(with: "linePush", completion: nil)
//            if #available(iOS 12.0, *) {
//                NSUserActivity.deleteAllSavedUserActivities(completionHandler: {})
//            }
        }
    }


}
