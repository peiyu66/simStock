//
//  lineBot.swift
//  simStock
//
//  Created by peiyu on 2017/6/9.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import Foundation
import LineSDK  //v4.1.1

protocol lineBotDelegate:class {
    func masterLog(_ msg:String)
}


class lineBot:NSObject, LineSDKLoginDelegate {
    
//  這裡記錄了LINE的token, group Id, user Id等明碼，定義於myCode.swift
//    class myCode:NSObject {
//        let lineChannelToken = "???"
//        let lineIdTeam:String = "???"
//        let lineIdPeiyu:String = "???"
//    }

    let lineCode:myCode = myCode()
    var masterView:lineBotDelegate?
    var userProfile:LineSDKProfile?
    var lineClient:LineSDKAPI = LineSDKAPI(configuration: LineSDKConfiguration.defaultConfig())


    override init() {
        super.init()
        LineSDKLogin.sharedInstance().delegate = self
    }


    func pushTextMessages (to:String="user", message:String="") {
        var toUser:String = ""

        if let _ = userProfile {
            if to == "team" && userProfile!.userID == lineCode.lineIdPeiyu {
                toUser = lineCode.lineIdTeam
            } else {
                toUser = userProfile!.userID
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
                self.masterView?.masterLog(error?.localizedDescription ?? "No response from LINE.")
                return
            }
            let responseJSONData = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSONData as? [String: Any] {
                if responseJSON.count > 0 {
                    self.masterView?.masterLog("Response from LINE:\n\(responseJSON)\n")
                }
            }
        }

        task.resume()

    }



    func didLogin(_ login: LineSDKLogin, credential: LineSDKCredential?, profile: LineSDKProfile?, error: Error?) {

        if let error = error {
            self.masterView?.masterLog("LINE login failed with error: \(error.localizedDescription)\n")
            return
        }
        guard let profile = profile, let credential = credential, let _ = credential.accessToken else {
            self.masterView?.masterLog("LINE invalid profile.\n")
            return
        }

        self.masterView?.masterLog("LINE login succeeded, id:\(profile.userID) name:\(profile.displayName).")
        self.userProfile = profile

    }

    func verifyToken() {
        lineClient.verifyToken(queue: .main) {
        (result, error) in

            if let error = error {
                self.masterView?.masterLog("LINE verifing token but Invalid: \(error.localizedDescription)\n")
                self.refreshToken()
                return
            }
            guard let result = result, let _ = result.permissions else {
                self.masterView?.masterLog("LINE verifing token but null.\n")
                self.refreshToken()
                return
            }

            self.masterView?.masterLog("LINE token is valid.") // with permission:\n\(permissions)")
            self.getProfile()
        }
    }

    func refreshToken() {
        lineClient.refreshToken(queue: .main) {
            (accessToken, error) in

            if let error = error {
                self.masterView?.masterLog("LINE refreshing token error: \(error.localizedDescription)\n")
                LineSDKLogin.sharedInstance().start()
                return
            }
            guard let _ = accessToken else {
                self.masterView?.masterLog ("LINE refreshing token but null.\n")
                LineSDKLogin.sharedInstance().start()
                return
            }

            self.masterView?.masterLog("LINE access token was refreshed.")
        }
    }


    func getProfile() {
        lineClient.getProfile(queue: .main) {
            (profile, error) in
            self.userProfile = nil
            if let error = error {
                self.masterView?.masterLog("LINE getting profile error: \(error.localizedDescription)\n")
                return
            }
            if let _ = profile {
                self.userProfile = profile
                self.masterView?.masterLog("LINE get profile for \(profile!.displayName).\n")
            } else {
                self.masterView?.masterLog("LINE profile is null.\n")
            }
        }
    }

    func logout() {
        lineClient.logout(queue: .main) {
            (success, error) in
        }
    }


}
