//
//  simStock.swift
//  simStockOsx
//
//  Created by peiyu on 2019/11/6.
//  Copyright © 2019 peiyu. All rights reserved.
//

import Foundation

class simStock:NSObject {
    var delegate:simStockDelegate?

    let defaults:UserDefaults = UserDefaults.standard
    let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    var versionNow:String = ""    //versionNo + "," + buildNo
    var versionLast:String = ""

    var stocks:[String:stock] = [:]               //每支股票Id所對照的模擬參數
    var frontStockId:String   = "2330"
    var frontStockName:String = "台積電"
    
    var initMoney:Double = 50       //起始本金
    var defaultYears:Int = 3        //預設起始3年前 = 3
    var defaultYearsMax:Int = 13    //起始日限13年內 = 13
    var realtimeSource:String = "twse"

    var dateStart:Date = Date.distantPast       //模擬起始日
    var dateEarlier:Date = Date.distantFuture   //dateStart往前(earlyMonths)個月數
    let earlyMonths:Int = -18   //往前撈1年半價格以得完整統計之ma60z




    
    func connectDelegate(_ delegate:simStockDelegate) {
        self.delegate = delegate
        loadDefaults()
    }
        
    func loadDefaults() {
        versionNow = versionNo + (buildNo <= "1" ? "" : "(\(buildNo))")
        if let d = defaults.string(forKey: "frontStockId") {
            frontStockId = d
            if let d = defaults.string(forKey: "frontStockName") {
                frontStockName = d
            }
            if let d = defaults.string(forKey: "realtimeSource") {
                realtimeSource = d
            }
            initMoney = defaults.double(forKey: "initMoney")
            defaultYears = defaults.integer(forKey: "defaultYears")
            defaultYearsMax = defaults.integer(forKey: "defaultYearsMax")
            if let d = defaults.string(forKey: "version") {
                versionLast = d
            }
            if let d = defaults.object(forKey: "stocks") {
                do {
                    if let s = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(d as! Data) as? [String:stock] {
                        stocks = s
                        for sId in stocks.keys {
                            stocks[sId]!.connectDelegate(self.delegate!)
                        }
                    }
                } catch {
                    print("Couldn't read stocks.")
                }
            }


            if versionLast != versionNow  {
                defaults.set(versionNow, forKey: "version")
            }
        } else {    //第一次，則建立預設股群
            initDefaults()
        }


//        if let t = defaults.object(forKey: "timePriceDownloaded") {
//            timePriceDownloaded = t as! Date
//        }
    }
    
    func initDefaults() {    //預設參數：起始本金、期間年、往前年限
        defaults.set("2330", forKey: "frontStockId")
        defaults.set("台積電", forKey: "frontStockName")
        defaults.set(realtimeSource, forKey: "realtimeSource")  //打開從twse下載盤中價的開關
        defaults.set(initMoney, forKey: "initMoney")    //本金50萬元  = 50
        defaults.set(defaultYears, forKey: "defaultYears")     //預設起始3年前 = 3
        defaults.set(defaultYearsMax, forKey: "defaultYearsMax") //起始日限10年內 = 10
        defaults.set(versionNow, forKey: "version")
        defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期則下次搜尋時可重新下載清單
        
        let _ = addNewStock(stockId: "2330", stockName: "台積電")
    }
    
    func addNewStock(stockId:String, stockName:String) {
        if stocks[stockId] == nil {
            stocks[stockId] = stock(stockId: stockId, stockName: stockName, delegate:delegate!)
//            sortedStocks = sortStocks()
//            self.masterUI?.masterLog ("*\(id) \(simPrices[id]!.name) \tadded to simPrices.")
        }
        do {
            let d = try NSKeyedArchiver.archivedData(withRootObject: stocks, requiringSecureCoding: false)
            defaults.set(d, forKey: "stocks")
        } catch {
            print("Couldn't write stocks.")
        }

     }

    
}
