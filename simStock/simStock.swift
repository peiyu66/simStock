//
//  simStock.swift
//  simStock
//
//  Created by peiyu on 2017/12/18.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import Foundation

//股群的下載和計算進度、介面和清單狀態等控制
class simStock: NSObject {

// >>>>>>>>>> ＊＊＊＊＊ 版本參數 ＊＊＊＊＊ >>>>>>>>>>

    var simTesting:Bool = false  //執行模擬測試 = false >>> 注意updateMA是否省略？ <<<
    let justTestIt:Bool = false  //這個開關在simTesting前有需要才手動打開，就執行預設測試

    let defaultYears:Int  = 3      //預設起始3年前 = 3
    let defaultMoney:Double = 50   //本金50萬元  = 50
    let defaultYearsMax:Int = 13    //起始日限10年內 = 10
    let defaultId:String = "2330"   //預設為2330
    let defaultName:String = "台積電"  //預設為台積電

    var simPrices:[String:simPrice] = [:]   //每支股票Id所對照的模擬參數
    var sortedStocks:[(id:String,name:String)] = []   //依股票名稱排序的模擬中股票清單
    var simId:String = ""                   //目前主畫面顯示的股票Id
    var simName:String = ""
    



    let defaults:UserDefaults = UserDefaults.standard
    let buildNo:String = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    let versionNo:String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    var versionLast:String  = ""    //上次記錄的程式版本 versionNow
    var versionNow:String   = ""    //versionNo + "," + buildNo


    var masterUI:masterUIDelegate?
//    var t00P:[Date:(highDiff:Double,lowDiff:Double)] = [:] //加權指數現價距離1年內的最高價和最低價的差(%)，來排除跌深了可能持續崩盤的情形


    func setSimId(newId:String) -> String {
        let oldId = simId
        if oldId != newId {
            simId = newId
            defaults.set(simId, forKey: "simId")
            if let name = simPrices[simId]?.name {
                simName = name
            }
            if Thread.current == Thread.main {
                self.masterUI?.setSegment()
            } else {
                DispatchQueue.main.async {[unowned self] in
                    self.masterUI?.setSegment()
                }
            }
        }
        return oldId
    }

    func connectMasterUI(_ master:masterUIDelegate) {
//        if let _ = master {
            self.masterUI = master
            loadDefaults()  //先載入simPrices才能接下來指定masterUI
//        }
    }


    func loadDefaults() {
        if simTesting {
            masterUI?.globalQueue().maxConcurrentOperationCount = 8
        } else {
            masterUI?.globalQueue().maxConcurrentOperationCount = 4
        }

        versionNow = versionNo + (buildNo <= "1" ? "" : "(\(buildNo))")
        if let ver = defaults.string(forKey: "version") {
            versionLast = ver
            if versionLast < "3.2" {
                resetDefaults()
            }
        }

        if let Id = defaults.string(forKey: "simId") {
            if let simData = defaults.object(forKey: "simPrices") as? Data {
                simPrices = NSKeyedUnarchiver.unarchiveObject(with: simData) as! [String:simPrice]
            }
            for id in simPrices.keys {
                simPrices[id]!.masterUI = self.masterUI
            }
            sortedStocks = sortStocks()
            let _ = setSimId(newId: Id) //要等simPrices & sortedStocks好了，才能設定simId & simName
            if versionLast != versionNow  {
                self.masterUI?.masterLog("\(versionLast) -> \(versionNow)")
                self.setDefaults()

                if versionLast < "3.3.5" {
                    //v3.2.1 新增ma20L,ma20H,ma60L,ma60H的計算
                    //v3.3.5 新增ma60Z 標準差分
                    self.resetAllSimUpdated()
                }
                if versionLast < "3.2.4" {
                    self.deleteOneMonth()               //Google下載失效強迫重下改版時當月股價（2018/03）
                }
                if versionLast < "3.2.5" {
                    self.defaults.set(true, forKey: "realtimeSource")   //打開從twse下載盤中價的開關
                    let _ = self.removeStock("TAIEX")   //之前從google下的TAIEX加權指，以後改從twse下，代號是t00
                    if let dt0101 = twDateTime.dateFromString("2018/01/01") {
                        for id in simPrices.keys {      //刪除1～3月股價，以補之前cnyes 2018/1/3缺漏資料
                            simPrices[id]!.deleteFrom(date:dt0101)
                        }
                    }
                }
                if versionLast < "3.3.3(7)" {   //移除舊的載入測試股群開關
                    defaults.removeObject(forKey: "Test5")
                    defaults.removeObject(forKey: "Test10")
                    defaults.removeObject(forKey: "Test50")
                    defaults.removeObject(forKey: "TW50")
                    defaults.removeObject(forKey: "removeStocks")
                    defaults.removeObject(forKey: "deleteAllPrices")
                    defaults.removeObject(forKey: "delete1month")
                    defaults.removeObject(forKey: "resetAllSim")
                }
                //變更買賣規則時，才要重算模擬、重配加碼，清除反轉買賣
                if versionLast < "3.3.5" {
                    self.masterUI?.masterLog("＊＊＊ 清除反轉及重算模擬 ＊＊＊")
                    self.resetAllSimStatus()
                } else if versionLast < "3.3.4(4)" {
                    //2018.04.16 3.3    高漲時延賣
                    //2018.07.10 3.3.3  微調賣出    2018.07.16 3.3.3(2) 顯示現金股利
                    //2018.09.19 3.3.4  承低買入    2018.09.26 3.3.4(3) 下輪間隔天數
                    self.masterUI?.masterLog("＊＊＊ 重算模擬 ＊＊＊")
                    for id in simPrices.keys {
                        simPrices[id]!.willUpdateAllSim = true     //至少要重算模擬、重配加碼，但不清除反轉
                        simPrices[id]!.willResetMoney = true
                        simPrices[id]!.willGiveMoney = true
                        simPrices[id]!.willResetReverse = false
                        simPrices[id]!.maxMoneyMultiple = 0
                    }
                }
                
                defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
                if !simTesting {    //如果已經收盤而且才更新過盤價，就需要強制啟動再更新重算
                    setupPriceTimer(mode: "all", delay: 2)
                }
            }
        } else {    //第一次，則建立預設股群
            setDefaults()
            let _ = addNewStock(defaultId, name: defaultName, saveDefaults: true)
        }


        if let t = defaults.object(forKey: "timePriceDownloaded") {
            timePriceDownloaded = t as! Date
        }

    }

    func resetDefaults() {
        defaults.removeObject(forKey: "stockId")
        defaults.removeObject(forKey: "simStocks")
        defaults.removeObject(forKey: "dateDownloaded")
        defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期則下次搜尋時可重新下載清單
    }

    func setDefaults() {    //預設參數：起始本金、期間年、往前年限
        if defaults.object(forKey: "realtimeSource") == nil {   //打開從twse下載盤中價的開關
            defaults.set(true, forKey: "realtimeSource")
        }
        if defaults.object(forKey: "defaultMoney") == nil {
            defaults.set(defaultMoney, forKey: "defaultMoney")
        }
        if defaults.object(forKey: "defaultYears") == nil {
            defaults.set(defaultYears, forKey: "defaultYears")            
        }
        defaults.set(defaultYearsMax, forKey: "defaultYearsMax")
        defaults.set(versionNow,      forKey: "version")
        defaults.removeObject(        forKey: "dateStockListDownloaded")   //清除日期則下次搜尋時可重新下載清單
    }


    func addNewStock(_ id:String,name:String, saveDefaults:Bool?=false) -> [String:simPrice] {
        if simPrices[id] == nil {
            simPrices[id] = simPrice(id: id, name: name, master:self.masterUI)
            sortedStocks = sortStocks()
            let _ = setSimId(newId: id)
            if saveDefaults! { //addStocksTest()在股群新增後要負責保存defaults
                defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
            }
            self.masterUI?.masterLog ("*\(id) \(simPrices[id]!.name) \tadded to simPrices.")
        }
        return simPrices
    }

    func sortStocks(includePaused:Bool=false) -> [(id:String,name:String)] {
        var unSorted:[(id:String,name:String)] = []
        for id in simPrices.keys {
            if !simPrices[id]!.paused || includePaused {
                unSorted.append((id,simPrices[id]!.name))
            }
        }
        if includePaused {
            return unSorted.sorted{$0.name<$1.name}
        } else {    //sortedStocks一定是只有模擬中的而不含暫停模擬的
            sortedStocks = unSorted.sorted{$0.name<$1.name}
            segmentedByFirstCharacter(sortedStocks)
            return sortedStocks
        }

    }

    var segment:[String] = []               //首字
    var segmentId:[String:String] = [:]     //首字 -> Id
    var segmentIndex:[String:Int] = [:]     //Id  -> 首字的Index
    func segmentedByFirstCharacter(_ sorted:[(id:String,name:String)]) {
        segment = []           //首字
        segmentId = [:]        //首字 -> Id
        segmentIndex = [:]     //Id  -> 首字的Index
        var last:String = ""
        for s in sorted {
            if let s0 = s.name.first {
                let s1:String = String(s0)
                if s1 != last {
                    segment.append(s1)
                    segmentId[s1] = s.id
                }
                last = s1
            }
            segmentIndex[s.id] = segment.count - 1
        }
    }
    
    func pausePriceSwitch(_ id:String) -> [String:simPrice] {
        //shiftLeft --> setSimId(只有simId不同時) --> setSegment
        if simId == id && !simPrices[id]!.paused {  //將由模擬中改為暫停則需先切換主畫面simId
            let _ = shiftLeft() //至少還有1個模擬中的股可以把simId切換過去
        }
        simPrices[id]!.paused = !simPrices[id]!.paused
        sortedStocks = self.sortStocks()
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
        if !simPrices[id]!.paused {
            let _ = self.setSimId(newId: id)    //simId是新的就必然會執行到setSegment
        } else {
            if Thread.current == Thread.main {  //若是暫停模擬就要重新再setSegment
                self.masterUI?.setSegment()
            } else {
                DispatchQueue.main.async {[unowned self] in
                    self.masterUI?.setSegment()
                }
            }
        }
        return simPrices
    }

    func removeStock(_ id:String) -> [String:simPrice] {
        guard let _ = simPrices[id] else { return simPrices }
        if simId == defaultId && simPrices.count == 1 { //反正刪除預設股還得加回來，不如別刪了
            self.masterUI?.masterLog ("*\(id) \(simPrices[id]!.name) \tskip removing the one simPrice.")
            return simPrices
        }
        self.masterUI?.masterLog ("*\(id) \(simPrices[id]!.name) \tremoving from simPrices(\(simPrices.count)).")
        if simId == id {        //先切換simId不然稍後被刪就不知隔壁是誰了，刪後setSegment只好重複執行
            let _ = shiftLeft() //也有可能只剩1支股切換了simId不會變，而且稍後就被刪了
        }
        simPrices[id]!.deletePrice()
        simPrices.removeValue(forKey: id)
        if simPrices.count == 0 {
            let _ = addNewStock(defaultId, name: defaultName, saveDefaults: true)
        }
        sortedStocks = self.sortStocks()
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")
        if Thread.current == Thread.main {
            self.masterUI?.setSegment()
        } else {
            DispatchQueue.main.async {[unowned self] in
                self.masterUI?.setSegment()
            }
        }

        return simPrices


    }

    func copySimPrice(_ simSource:simPrice) -> simPrice {
        let simData = NSKeyedArchiver.archivedData(withRootObject: simSource)
        let simPrice = NSKeyedUnarchiver.unarchiveObject(with: simData) as! simPrice
        if let _ = self.masterUI {
            simPrice.connectMaster(self.masterUI!)
        }
        return simPrice
    }


    var needModeALL:Bool = false
    func resetAllSimStatus() {
        needModeALL = true
        for id in Array(self.simPrices.keys) {
            self.simPrices[id]!.resetSimStatus()
        }
        defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")

    }

//    下載股票排行於Google SpreadSheets，使用試算表函數產生測試股群名單
//    A2=9904
//    B2=寶成
//    C2="let _ = addNewStock("&char(34)&A2&char(34)&", name:"&char(34)&B2&char(34)&")"
    
    func addTestStocks(_ group:String) {
        
        switch group {
        case "Test5":
            let _ = addNewStock("1590", name:"亞德客-KY")
            let _ = addNewStock("1301", name:"台塑")
            let _ = addNewStock("2376", name:"技嘉")
            let _ = addNewStock("1312", name:"國喬")
            let _ = addNewStock("9910", name:"豐泰", saveDefaults: true)
            
        case "Test10":
            let _ = addNewStock("1476", name:"儒鴻")
            let _ = addNewStock("2474", name:"可成")
            let _ = addNewStock("6505", name:"台塑化")
            let _ = addNewStock("2330", name:"台積電")
            let _ = addNewStock("3406", name:"玉晶光")
            let _ = addNewStock("2912", name:"統一超")
            let _ = addNewStock("2327", name:"國巨")
            let _ = addNewStock("2377", name:"微星")
            let _ = addNewStock("1605", name:"華新")
            let _ = addNewStock("2303", name:"聯電", saveDefaults: true)
            
        case "Test50":
            let _ = addNewStock("1590", name:"亞德客-KY")
            let _ = addNewStock("2324", name:"仁寶")
            let _ = addNewStock("1227", name:"佳格")
            let _ = addNewStock("1476", name:"儒鴻")
            let _ = addNewStock("0050", name:"元大台灣50")
            let _ = addNewStock("1303", name:"南亞")
            let _ = addNewStock("1702", name:"南僑")
            let _ = addNewStock("2332", name:"友訊")
            let _ = addNewStock("2409", name:"友達")
            let _ = addNewStock("2474", name:"可成")
            
            let _ = addNewStock("1301", name:"台塑")
            let _ = addNewStock("6505", name:"台塑化")
            let _ = addNewStock("3045", name:"台灣大")
            let _ = addNewStock("2330", name:"台積電")
            let _ = addNewStock("1722", name:"台肥")
            let _ = addNewStock("2308", name:"台達電")
            let _ = addNewStock("1536", name:"和大")
            let _ = addNewStock("4938", name:"和碩")
            let _ = addNewStock("1312", name:"國喬")
            let _ = addNewStock("2327", name:"國巨")
            let _ = addNewStock("2882", name:"國泰金")
            let _ = addNewStock("2371", name:"大同")
            let _ = addNewStock("2353", name:"宏碁")
            let _ = addNewStock("9904", name:"寶成")
            let _ = addNewStock("2498", name:"宏達電")
            let _ = addNewStock("9921", name:"巨大")
            
            let _ = addNewStock("1537", name:"廣隆")
            let _ = addNewStock("6116", name:"彩晶")
            let _ = addNewStock("2377", name:"微星")
            let _ = addNewStock("2376", name:"技嘉")
            let _ = addNewStock("2105", name:"正新")
            let _ = addNewStock("6552", name:"易華電")
            let _ = addNewStock("6414", name:"樺漢")
            let _ = addNewStock("3406", name:"玉晶光")
            let _ = addNewStock("2395", name:"研華")
            let _ = addNewStock("1216", name:"統一")
            let _ = addNewStock("2912", name:"統一超")
            let _ = addNewStock("3231", name:"緯創")
            let _ = addNewStock("9914", name:"美利達")
            
            let _ = addNewStock("2454", name:"聯發科")
            let _ = addNewStock("1229", name:"聯華")
            let _ = addNewStock("2303", name:"聯電")
            let _ = addNewStock("3450", name:"聯鈞")
            let _ = addNewStock("1605", name:"華新")
            let _ = addNewStock("2357", name:"華碩")
            let _ = addNewStock("2344", name:"華邦電")
            let _ = addNewStock("2201", name:"裕隆")
            let _ = addNewStock("9910", name:"豐泰")
            let _ = addNewStock("2731", name:"雄獅")
            let _ = addNewStock("2317", name:"鴻海", saveDefaults: true)
            
        case "TW50":    //根據[維基百科「台灣50指數」](https://zh.wikipedia.org/wiki/臺灣50指數)
            let _ = addNewStock("2301", name:"光寶科")
            let _ = addNewStock("2303", name:"聯電")
            let _ = addNewStock("2308", name:"臺達電")
            let _ = addNewStock("2317", name:"鴻海")
            let _ = addNewStock("2327", name:"國巨")
            let _ = addNewStock("2330", name:"臺積電")
            let _ = addNewStock("2354", name:"鴻準")
            let _ = addNewStock("2357", name:"華碩")
            let _ = addNewStock("2382", name:"廣達")
            let _ = addNewStock("2395", name:"研華")
            let _ = addNewStock("2408", name:"南亞科")
            let _ = addNewStock("2409", name:"友達")
            let _ = addNewStock("2412", name:"中華電")
            let _ = addNewStock("2454", name:"聯發科")
            let _ = addNewStock("2474", name:"可成")
            let _ = addNewStock("2492", name:"華新科")
            let _ = addNewStock("3008", name:"大立光")
            let _ = addNewStock("3045", name:"臺灣大")
            let _ = addNewStock("3711", name:"日月光")
            let _ = addNewStock("3481", name:"群創")
            let _ = addNewStock("4904", name:"遠傳")
            let _ = addNewStock("4938", name:"和碩")

            let _ = addNewStock("1101", name:"臺泥")
            let _ = addNewStock("1102", name:"亞泥")
            let _ = addNewStock("1216", name:"統一")
            let _ = addNewStock("1301", name:"臺塑")
            let _ = addNewStock("1303", name:"南亞")
            let _ = addNewStock("1326", name:"臺化")
            let _ = addNewStock("1402", name:"遠東新")
            let _ = addNewStock("2002", name:"中鋼")
            let _ = addNewStock("2105", name:"正新")
            let _ = addNewStock("2633", name:"臺灣高鐵")
            let _ = addNewStock("2912", name:"統一超")
            let _ = addNewStock("6505", name:"臺塑化")
            let _ = addNewStock("9904", name:"寶成")

            let _ = addNewStock("2801", name:"彰銀")
            let _ = addNewStock("2823", name:"中壽")
            let _ = addNewStock("2880", name:"華南金")
            let _ = addNewStock("2881", name:"富邦金")
            let _ = addNewStock("2882", name:"國泰金")
            let _ = addNewStock("2883", name:"開發金")
            let _ = addNewStock("2884", name:"玉山金")
            let _ = addNewStock("2885", name:"元大金")
            let _ = addNewStock("2886", name:"兆豐金")
            let _ = addNewStock("2887", name:"臺新金")
            let _ = addNewStock("2890", name:"永豐金")
            let _ = addNewStock("2891", name:"中信金")
            let _ = addNewStock("2892", name:"第一金")
            let _ = addNewStock("5871", name:"中租KY")
            let _ = addNewStock("5880", name:"合庫金", saveDefaults: true)
            
        case "t00":
            let _ = addNewStock("t00",name:"*加權指", saveDefaults: true)
            
        default:
            break
        }
        
    }
    



    func removeAllStocks() {
        for id in self.simPrices.keys {
            let _ = self.removeStock(id)
        }
        self.defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期以強制重載股票清單
        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
        self.timePriceDownloaded = Date.distantPast
        self.defaults.removeObject(forKey: "timePriceDownloaded")
    }
    
    func deleteAllPrices() {
        for id in self.simPrices.keys {
            self.simPrices[id]!.deletePrice("reset")
        }
        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
        self.timePriceDownloaded = Date.distantPast
        self.defaults.removeObject(forKey: "timePriceDownloaded")
    }


    func deleteOneMonth() {
        for (id,_) in self.sortedStocks {   //暫停模擬的股不處理
            self.simPrices[id]!.deleteLastMonth(allStocks: true)
        }
        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
        self.timePriceDownloaded = Date.distantPast
        self.defaults.removeObject(forKey: "timePriceDownloaded")
    }


    func resetAllSimUpdated() {
        for id in simPrices.keys {
            simPrices[id]!.resetSimUpdated()
        }
        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
        self.timePriceDownloaded = Date.distantPast
        self.defaults.removeObject(forKey: "timePriceDownloaded")
    }


    func shiftRight() -> Bool {
        var shiftToId:String = simId
        if let index = sortedStocks.index(where: {$0.id == simId}) {
            if index < sortedStocks.count - 1 {
                shiftToId = sortedStocks[index+1].id
            } else {        //循環到首筆
                if index != 0 { //有首筆而且不是自己
                    shiftToId = sortedStocks[0].id
                }   //else 首筆是自己而且沒有下一筆，那就不需要動作
            }
        } else {
            if sortedStocks.count > 0 {
                shiftToId = sortedStocks[0].id
            }
        }
        if shiftToId != simId {
            let _ = setSimId(newId: shiftToId)
            return true
        } else {
            return false
        }
    }


    func shiftLeft() -> Bool {
        var shiftToId:String = simId
        if let index = sortedStocks.index(where: {$0.id == simId}) {
            if index > 0 {
                shiftToId = sortedStocks[index-1].id
            } else {        //循環到末筆
                shiftToId = sortedStocks[sortedStocks.count-1].id
            }
        } else {
            if sortedStocks.count > 0 {
                shiftToId = sortedStocks[0].id
            }
        }
        if shiftToId != simId {
            let _ = setSimId(newId: shiftToId)
            return true
        } else {
            return false
        }
    }


    let dispatchGroupSimTesting:DispatchGroup = DispatchGroup()
    func runSimTesting(fromYears:Int,forYears:Int=2,loop:Bool=true) {
        self.needModeALL = true
        if fromYears % 3 == 1 {
            masterUI?.systemSound(1113)
        }
        dispatchGroupSimTesting.enter()
        masterUI?.globalQueue().addOperation {
            for (id,_) in self.sortedStocks {
                self.simPrices[id]!.resetToDefault(fromYears:fromYears, forYears:forYears)
            }
            let testMode:String = (forYears >= 10 ? "maALL" : "all") //10年只有為了重算Ma
            self.setupPriceTimer(mode:testMode)
        }
        dispatchGroupSimTesting.notify(queue: DispatchQueue.main , execute: {
            let loopYears = fromYears - 1
            if loopYears >= 2 && loop {    //模擬到2年前時停止
                self.runSimTesting(fromYears: loopYears,forYears: forYears)
            } else {
                self.resetSimTesting()
            }
        })
    }


    func resetSimTesting() {
        if simTesting {
            masterUI?.systemSound(1114)

            defaults.set(self.defaultYears, forKey: "defaultYears")
            for (id,_) in self.sortedStocks {
                self.simPrices[id]!.resetToDefault()
            }
            defaults.set(NSKeyedArchiver.archivedData(withRootObject: simPrices) , forKey: "simPrices")

            defaults.removeObject(forKey: "timePriceDownloaded")
            simTesting = false
            masterUI?.masterLog("== simTesting reseted ==\n")
        }
    }


    //
    //
    //
    //
    //
    //
    //  更新股價的Timer
    //
    //
    //
    //
    //
    //

    var priceTimer:Timer = Timer()
    var todayIsNotWorkingDay:Bool = false   //今天是休市日
    var timePriceDownloaded:Date = Date.distantPast //上次下載股價的時間
    var mainSource:String  = "cnyes"  //cnyes, twse
    var realtimeSource:String = "twse"
    let wasRealtimeSource:[String] = ["Google","Yahoo","yahoo","twse"]

    func isTodayOffDay(_ value:Bool?=nil) -> Bool { //true=休市日
        if let _ = value {
            todayIsNotWorkingDay = value!
        }
        return todayIsNotWorkingDay
    }

    func needPriceTimer() -> Bool {
        var needed:Bool = false
        let y1335 = twDateTime.time1330(twDateTime.yesterday(), delayMinutes: 5)
        let time1335 = twDateTime.time1330(delayMinutes: 5)
        let time0850 = twDateTime.time0900(delayMinutes: -5)
        if (todayIsNotWorkingDay && twDateTime.isDateInToday(timePriceDownloaded)) {
            masterUI?.masterLog("休市日且今天已更新。")
        } else if (timePriceDownloaded.compare(y1335) == .orderedDescending && Date().compare(time0850) == .orderedAscending) {
            masterUI?.masterLog("今天還沒開盤且上次更新是昨收盤後。")
        } else if timePriceDownloaded.compare(time1335) == .orderedDescending {
            masterUI?.masterLog("上次更新是今天收盤之後。")
        } else if self.simTesting {
            masterUI?.masterLog("執行模擬測試。")
        } else {
            needed = true
        }
        return needed
    }



    //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
    let modePriority:[String:Int] = ["":1,"realtime":2,"simOnly":3,"all":4,"maALL":5,"retry":6,"reset":7]

    func setupPriceTimer(_ id:String="",mode:String="all",delay:TimeInterval=0) {
        
        var timerDelay:TimeInterval = delay
        var timerMode:String = mode
        var timerId:String = id
        
        OperationQueue.main.addOperation {
            if self.priceTimer.isValid {
                if let u = self.priceTimer.userInfo {
                    let uInfo = u as! (id:String,mode:String,delay:TimeInterval)
                    if self.modePriority[uInfo.mode]! >= self.modePriority[mode]! {    //mode以先前uInfo為主
                        if (uInfo.id == "" || uInfo.id == id) && uInfo.delay <= timerDelay { //id也不變
                            return
                        } else {
                            timerMode   = uInfo.mode
                            if uInfo.mode == "reset" || uInfo.id == id {  //reset必須指定id，才不會造成全部清除
                                timerId = uInfo.id
                            } else {
                                timerId = ""
                            }
                            if uInfo.delay < timerDelay {            //delay取較小者
                                timerDelay  = uInfo.delay
                            }
                        }
                    } else {    //以新mode,delay為主，除非先前的uInfo.id,uInfo.delay範圍較小
                        timerMode = mode
                        if mode == "reset" || uInfo.id == id {
                            timerId  = id
                        } else {
                            timerId  = ""
                        }
                        if timerDelay > uInfo.delay {
                            timerDelay = uInfo.delay
                        }
                    }   //if self.modePriority[uInfo.mode]!
                    let uInfoIdTitle = (uInfo.id == "" ? "" : " for:\(uInfo.id)")
                    self.masterUI?.masterLog("priceTimer: \t\(uInfo.mode)\(uInfoIdTitle) in \(uInfo.delay)s will be invalidated.")
                }   //if let u = self.priceTimer.userInfo
                
                self.priceTimer.invalidate()
            }   //if self.priceTimer.isValid
            
            if self.needPriceTimer() || self.modePriority[timerMode]! > 2 {
                let userInfo:(id:String,mode:String,delay:TimeInterval) = (timerId,timerMode,timerDelay)
                self.priceTimer = Timer.scheduledTimer(timeInterval: timerDelay, target: self, selector: #selector(simStock.updatePriceByTimer(_:)), userInfo: userInfo, repeats: false)
                var forId = ""
                if timerId != "" {
                    forId = " for: \(timerId) \(self.simPrices[timerId]!.name)"
                }
                self.masterUI?.masterLog("priceTimer\t:\(mode)\(forId) in \(timerDelay)s.")
                self.masterUI?.setIdleTimer(timeInterval: -1)    //有插電的話停止休眠排程
            } else {
                self.priceTimer.invalidate()
                self.masterUI?.masterLog("priceTimer stop, idleTimer in 1min.\n")
                self.masterUI?.setIdleTimer(timeInterval: 60)    //不需要更新股價，就60秒恢復休眠眠排程
            }
        }   //OperationQueue

    }
    



    var timerFailedCount:Int = 0
    @objc func updatePriceByTimer(_ timer:Timer) {
        let uInfo:(id:String,mode:String,delay:TimeInterval) = timer.userInfo as! (id:String,mode:String,delay:TimeInterval)
        priceTimer.invalidate()
        let yesterday1335 = twDateTime.time1330(twDateTime.yesterday(),delayMinutes: 5)
        let overNightRealtime:Bool = self.modePriority[uInfo.mode]! <= 2 && timePriceDownloaded.compare(yesterday1335) == .orderedAscending
        let noNetwork:Bool = !NetConnection.isConnectedToNetwork()
        if noNetwork {
            masterUI?.messageWithTimer("沒有網路",seconds: 10)
        }
        if overNightRealtime {    //因為休眠而持續前日的realtime排程的話，應改為all
            setupPriceTimer(uInfo.id, mode:"all", delay:5)
        } else if updatedPrices != 0 || self.isUpdatingPrice || (noNetwork && uInfo.mode != "simOnly") {
            timerFailedCount += 1
            var delay:TimeInterval = 5  //第1次重試等5秒
            if timerFailedCount >= 2 {
                if timerFailedCount == 2 {
                    delay = 15
                } else {
                    delay = 40
                    timerFailedCount = 0
                }
            }
            setupPriceTimer(uInfo.id, mode:uInfo.mode, delay:delay) //已經更新中就把下一個排程要求延後
            self.masterUI?.masterLog("updatePriceByTimer: \(uInfo.mode) failed [\(timerFailedCount)], reset in \(delay)s.")
        } else {
            var forId = ""
            if uInfo.id != "" {
                updatedPrices = -1
                forId = "for: \(uInfo.id) \(self.simPrices[uInfo.id]!.name)"
            }
            self.masterUI?.masterLog("updatePriceByTimer: \(uInfo.mode) \(forId)")
            downloadAndUpdate(uInfo.id, mode:uInfo.mode)    //都沒問題就去下載更新
        }

    }

    //
    //
    //
    //
    //
    //
    //  下載及更新股價
    //
    //
    //
    //
    //
    //

    var updatedPrices:Int = 0   //已完成更新股價的股票數目，-1代表這次只更新1支股價，而且正在更新中
    var isUpdatingPrice:Bool = false
    var twseTask:[String:String] = [:]
//    let twseGroup:DispatchGroup = DispatchGroup()

    func downloadAndUpdate(_ id:String="", mode:String="all") {
        //mode: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
        var forId = ""
        if id != "" {
            forId = "for: \(id) \(self.simPrices[id]!.name)"
        }
        self.masterUI?.masterLog("downloadAndUpdate \t:\(mode) \(forId)")
        var modeText:String = ""
        switch mode {
        case "realtime":
            modeText = "查詢成交價"
        case "retry":
            modeText = "重試未完下載"
        case "all","maALL":
            if simTesting {
                modeText = "模擬測試"
            } else {
                modeText = "查詢收盤價"
            }
        case "reset":
            modeText = "重新下載"
        default:
            modeText = "統計更新"
        }

        self.isUpdatingPrice = true
        self.masterUI?.lockUI(modeText)
        if updatedPrices == -1 {    //單一股查詢
            self.simPrices[id]!.downloadPrice(mode, source:(self.modePriority[mode]! <= 2 ? self.realtimeSource : self.mainSource))
        } else {
            //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
            if mainSource == "twse" && modePriority[mode]! >= 4 {
                for (sId,_) in sortedStocks {
                    twseTask[sId] = mode
                }
                if let sId = twseTask.keys.first {  //從第1個開始丟出查詢，完畢時才逐次接續
                    self.simPrices[sId]!.downloadPrice(mode, source:self.mainSource)
                }
            } else {
                var t00Exists:Bool = false
                var t00:simPrice?
                if let xtai = self.simPrices["t00"] {
                    if !xtai.paused {
                        t00Exists = true
                        t00 = xtai
                    }
                }
                //有xtai時，要先完成xtai更新，才不會造成其他股參考加權指時當出來
                if t00Exists {
                    for (sId,_) in sortedStocks {
                        twseTask[sId] = mode    //稍後setProgress會把這些股於TAIEX完成後丟出查詢
                    }
                    t00!.downloadPrice(mode, source:(self.modePriority[mode]! <= 2 ? self.realtimeSource : self.mainSource))
                } else {
                    for (sId,_) in sortedStocks { //沒有xtai故可放心直接丟出查詢
                        self.simPrices[sId]!.downloadPrice(mode, source:(self.modePriority[mode]! <= 2 ? self.realtimeSource : self.mainSource))
                    }
                }
            }

            if self.needModeALL && self.modePriority[mode]! > 2 {
                self.needModeALL = false
            }
        }
        timePriceDownloaded = Date()

    }


    var progressStop:Float = 0
    func setProgress(_ id:String, progress:Float, message:String?="") { //progress == -1 表示沒有執行什麼，跳過
        OperationQueue.main.addOperation() {
            var msg:String?
            let absProgress:Float = abs(progress)
            var allProgress:Float = absProgress
            let idTitle:String = "\(id) \(self.simPrices[id]!.name)"


            //顯示提示訊息
            if absProgress == 1 && self.updatedPrices != -1 {   //全部更新中，有1支已完成
                self.updatedPrices += 1
                self.masterUI?.masterLog("*\(id) \(self.simPrices[id]!.name) \tsetProgress \(progress) updatedPrices = \(self.updatedPrices) / \(self.sortedStocks.count)")
                if progress == 1 {
                    msg = "\(idTitle) (\(self.updatedPrices)/\(self.sortedStocks.count)) 完成"
                } else {    //progress == -1 表示沒有執行什麼，跳過
                    msg = "\(idTitle) (\(self.updatedPrices)/\(self.sortedStocks.count)) 略過"
                }
                if self.twseTask.count > 0 {
                    self.twseTask.removeValue(forKey: id)
                    if self.mainSource == "twse" {  //source是twse必須逐股丟查詢
                        if let sId = self.twseTask.keys.first {
                            if let mode = self.twseTask[sId] {
                                self.simPrices[sId]!.downloadPrice(mode, source:(self.modePriority[mode]! <= 2 ? self.realtimeSource : self.mainSource))
                            }
                        }
                    } else {    //source不是twse就可以全部股一起丟查詢
                        for sId in self.twseTask.keys { //把downloadAndUpdate放在twseTask的非twse股全部向cnyes丟出去
                            if let mode = self.twseTask[sId] {
                                self.simPrices[sId]!.downloadPrice(mode, source:(self.modePriority[mode]! <= 2 ? self.realtimeSource : self.mainSource))
                            }
                            self.twseTask.removeValue(forKey: sId)  //一次丟完隨即清空
                        }
                    }
                }
            } else if (progress < 1 && progress > 0) { //|| self.uiProgress.progress != 0 { //progress不是-1表示還有其他股，則顯示進度訊息
                if self.isUpdatingPrice == false {
                    self.masterUI?.lockUI("更新中")    // <<<<<萬一有漏失，這裡補上lockUI<<<有必要嗎？
                }
                if id == self.simId && self.updatedPrices != -1 { //更新到主畫面的股時，刷新畫面
                    msg = "\(idTitle) (\(self.updatedPrices)/\(self.sortedStocks.count)) 更新中"
                }
            }
            if absProgress == 1 && (self.updatedPrices == self.sortedStocks.count || self.updatedPrices == -1) {
                self.isUpdatingPrice = false
                self.updatedPrices = 0
                if self.updatedPrices != -1 {
                    msg = "完成更新 \(twDateTime.stringFromDate(Date(),format: "HH:mm:ss"))"
                    self.defaults.set(self.timePriceDownloaded, forKey: "timePriceDownloaded")
                }
                if self.priceTimer.isValid {
                    let uInfo = self.priceTimer.userInfo as! (id:String,mode:String,delay:TimeInterval)
                    if uInfo.mode == "retry" {
                        msg = "未完，稍後重試"
                        if let t = self.defaults.object(forKey: "timePriceDownloaded") {
                            self.timePriceDownloaded = t as! Date
                        }
                    }
                }
                self.masterUI?.unlockUI((msg ?? "")) // <<<<<<<<<<< 這裡完成unlockUI，並恢復休眠 <<<<<<<<<<<

                var fromYears:String = ""
                if self.simTesting {
                    let firstId:String = self.sortedStocks[0].id
                    let simFirst:simPrice =  self.simPrices[firstId]!
                    if let y = twDateTime.calendar.dateComponents([.year], from: simFirst.dateStart, to: Date()).year {
                        fromYears = "第 \(String(describing: y)) 年起 "
                    }
                    
                }
                let rois = self.roiSummary()
                let roiAvg:String = String(format:"%g", rois.roi)
                let daysAvg:String = String(format:"(%.f天)", rois.days)
                self.masterUI?.masterLog("== \(fromYears)\(rois.count)支股: \(rois.years) \(roiAvg) \(daysAvg) ==")

                self.progressStop = 0
                if self.simTesting {
                    self.dispatchGroupSimTesting.leave()
                } else {
                    self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.simPrices) , forKey: "simPrices")
                    if self.needPriceTimer() && !self.simTesting {  //09:05之前都不能放心的說是realtimeOnly
                        let realtimeOnly:Bool = !self.needModeALL && self.timePriceDownloaded.compare(twDateTime.time0900(delayMinutes:5)) == .orderedDescending
                        if realtimeOnly {
                            self.setupPriceTimer(mode:"realtime", delay:300)  //有插電則停止休眠...
                        } else {
                            self.setupPriceTimer(mode:"all", delay:300) //因為setupPriceTimer會負責判斷idleTimer
                        }
                    }
                }
            } else {  //else if absProgress == 1 && (self.updatedPrices ==

                //顯示進度
                if self.updatedPrices != -1 {
                    if message!.count > 0 {
                        msg = message
                    }
                    allProgress = (Float(self.updatedPrices) + absProgress) / Float(self.sortedStocks.count)
                    if allProgress > self.progressStop {
                        self.progressStop = allProgress
                        self.masterUI?.setProgress(allProgress,message:msg)
                    }
                }
            }

        }   //mainQueue.addOperation()

    }














    func roiSummary() -> (count:Int, years:String, roi:Double, days:Float) {
        var simCount:Int = 0
        var sumROI:Double = 0
        var simDays:Float = 0
        var minYears:Double = 9999
        var maxYears:Double = 0
        for (id,_) in self.sortedStocks {
            if id != "t00" {
                let roiTuple = self.simPrices[id]!.ROI()
                if roiTuple.days != 0 {
                    simCount += 1
                    sumROI   += roiTuple.roi
                    simDays  += roiTuple.days
                    if roiTuple.years > maxYears {
                        maxYears = roiTuple.years
                    }
                    if roiTuple.years < minYears {
                        minYears = roiTuple.years
                    }
                    //self.masterUI?.masterLog("===== \(index) \(id) \(self.simPrices[id]!.name) years=\(roiTuple.years) roi=\(roiTuple.roi) days=\(roiTuple.days) ==")
                }
            }
        }
        let maxY:String = String(format:"%.f",maxYears)
        let minY:String = String(format:"%.f",minYears)
        let years:String = "\(minY == maxY ? "" : "\(minY)-")\(maxY)年"
        let roi:Double = (simCount > 0 ? round(10 * sumROI / Double(simCount)) / 10 : 0)
        let days:Float = (simCount > 0 ? round(simDays / Float(simCount)) : 0)

        return (simCount,years,roi,days)
    }


    func composeSuggest(isTest:Bool=false) -> String {
        var suggest:String = ""
        var suggestL:String = ""
        var suggestH:String = ""
//        var suggestS:String = ""
        var dateReport:Date = Date.distantPast
        var isClosedReport:Bool = false
        for (id,name) in sortedStocks {
            if let last = self.simPrices[id]!.getPriceLast() {
                if last.dateTime.compare(twDateTime.time0900()) == .orderedDescending || isTest {
                    dateReport = last.dateTime
                    isClosedReport = (dateReport.compare(twDateTime.time1330(dateReport)) != .orderedAscending)
                    let close:String = String(format:"%g",last.priceClose)
                    let time1220:Date = twDateTime.timeAtDate(hour: 12, minute: 20)
                    switch last.simRule {
                    case "L":
                        if (last.dateTime.compare(time1220) == .orderedDescending || isTest) {
                            suggestL += "　　" + name + " (" + close + ")\n"
                        }
                    case "H":
                        if (last.dateTime.compare(time1220) == .orderedDescending || isTest) {
                                suggestH += "　　" + name + " (" + close + ")\n"

                        }
//                    case "S":
//                        suggestS += "　　" + name + " (" + close + ")\n"
                    default:
                        break
                    }
                }
            }
        }
        suggest = (suggestL.count > 0 ? "低買：\n" + suggestL : "") + (suggestH.count > 0 ? (suggestL.count > 0 ? "\n" : "") + "高買：\n" + suggestH + "\n" : "")
//            + (suggestS.count > 0 ? ((suggestL.count + suggestH.count) > 0 ? "\n" : "") + "應賣：\n" + suggestS : "")

        if suggest.count > 0 {
            if isClosedReport || isTest {
                suggest = "小確幸提醒你 \(twDateTime.stringFromDate(dateReport))：\n\n" + suggest
            } else {
                suggest = "小確幸提醒你：\n\n" + suggest
            }
        }
        return suggest
    }

    func composeReport(isTest:Bool=false, withTitle:Bool?=false) -> String {
        var report:String = ""
        var dateReport:Date = Date.distantPast
        var isClosedReport:Bool = false //(dateReport.compare(twDateTime.time1330(dateReport)) != .orderedAscending)
        var sCount:Float = 0
        var sROI:Float = 0
        var sDays:Float = 0

        //        func leftPadding(text:String ,toLength: Int, withPad character: Character) -> String {
        //            let newLength = text.count    //在固定長度的String左邊填空白
        //            if newLength < toLength {
        //                return String(repeatElement(character, count: toLength - newLength)) + text
        //            } else {
        //                return text
        //            }
        //        }


        for (id,name) in sortedStocks {
            if let last = self.simPrices[id]!.getPriceLast() {
                if last.dateTime.compare(twDateTime.time0900()) == .orderedDescending || isTest {
                    dateReport = last.dateTime
                    isClosedReport = (dateReport.compare(twDateTime.time1330(dateReport)) != .orderedAscending)
                    let close:String = String(format:"%g",last.priceClose)
                    let time1220:Date = twDateTime.timeAtDate(hour: 12, minute: 20)
                    var action:String = " "
                    if last.qtyBuy > 0 && (last.dateTime.compare(time1220) == .orderedDescending || isTest) {
                        action = "買"
                    } else if last.qtySell > 0 {
                        action = "賣"
                    } else if last.qtyInventory > 0 {
                        action = "" //為了日報文字不要多出空白，所以有「餘」時為空字串，而空白才是沒有狀況
                    }
                    if action != " " && (action != "" || isClosedReport || isTest) {
                        if report.count > 0 {
                            report += "\n"
                        }
                        let d = (last.simDays == 1 ? " 第" : "") + String(format:"%.f",last.simDays) + "天"
                        report += name + " (" + close + ") " + action + d
                        if action == "賣" {
                            let roi = round(10 * last.simROI) / 10
                            report += String(format:" %g%%",roi)
                            sROI += Float(roi)
                        } else if action == "" {   //餘，只會在isClosedReport時才輸出
                            let roi = round(10 * last.simUnitDiff) / 10
                            report += String(format:" %g%%",roi)
                            sROI += Float(roi)
                        }
                        sCount += 1
                        sDays  += last.simDays
                    }
                }
            }
        }
        if report.count > 0 {
            if isClosedReport || isTest {
                report = (withTitle! ? "小確幸日報 \(twDateTime.stringFromDate(dateReport))：\n\n" : "\n") + report + String(format:"\n\n%.f支股平均 %.f天 %g%%",sCount,round(sDays / sCount),round(10 * sROI  / sCount) / 10)
            } else {
                report = (withTitle! ? "小確幸提醒你：\n\n" : "\n") + report
            }


            if let lrt = self.defaults.object(forKey: "timeReported") {
                let lastReportTime = lrt as! Date
                if  twDateTime.startOfMonth(lastReportTime).compare(twDateTime.startOfMonth(dateReport)) != .orderedSame || isTest {
                    var dateFrom:Date = dateReport
                    var dateTo:Date   = dateReport
                    if let dt = twDateTime.calendar.date(byAdding: .month, value: -3, to: dateReport) {
                        dateFrom = twDateTime.startOfMonth(dt)
                    }
                    if let dt = twDateTime.calendar.date(byAdding: .month, value: -1, to: dateReport) {
                        dateTo = twDateTime.endOfMonth(dt)
                    }
                    report += "\n\n\n" + csvMonthlyRoi(from: dateFrom, to: dateTo)
                }
            }

        }

        return report
    }


    func selfTalk() -> String {
        let todayNow = Date()
        let weekday = twDateTime.calendar.component(.weekday, from: todayNow)
        var talkMessage:String = "小確幸祝福你。"

        let time0830:Date = twDateTime.timeAtDate(todayNow, hour:08, minute:30)
        let time0900:Date = twDateTime.timeAtDate(todayNow, hour:09, minute:0)
        let time0930:Date = twDateTime.timeAtDate(todayNow, hour:09, minute:30)
        let time1100:Date = twDateTime.timeAtDate(todayNow, hour:11, minute:0)
        let time1330:Date = twDateTime.timeAtDate(todayNow, hour:13, minute:30)
        let time1430:Date = twDateTime.timeAtDate(todayNow, hour:14, minute:30)
        let time1900:Date = twDateTime.timeAtDate(todayNow, hour:19, minute:00)
        let time2200:Date = twDateTime.timeAtDate(todayNow, hour:22, minute:00)

        if !self.todayIsNotWorkingDay && todayNow.compare(time0900) == .orderedDescending && todayNow.compare(time0930) == .orderedAscending && weekday > 1 {
            talkMessage = "開盤了!"
        } else if !self.todayIsNotWorkingDay && todayNow.compare(time0830) == .orderedDescending && todayNow.compare(time0900) == .orderedAscending && weekday > 1 && weekday < 7   {
            talkMessage = "快要開盤了？"
        } else if !self.todayIsNotWorkingDay && todayNow.compare(time1330) == .orderedDescending && todayNow.compare(time1430) == .orderedAscending {
            talkMessage = "收盤了。"
        } else if todayNow.compare(time1100) == .orderedAscending {
            talkMessage = "早安。"
            if self.todayIsNotWorkingDay {
                talkMessage += "今天休市了？"
            }
        } else {
            let toNight:Bool = time1900.timeIntervalSinceNow / 3600 < 0.5  && time1900.timeIntervalSinceNow / 3600 > -3
            if toNight {    //晚上七點前0.5hr之後3hr都是晚安
                talkMessage = "晚安。"
            } else if time2200.timeIntervalSinceNow < 0 {
                talkMessage = "該睡了，晚安。"
            }
        }


        return talkMessage
    }





    func csvSummary() -> String {
        var sumROI:Double = 0
        var simDays:Float = 0
        var text = "順序,代號,簡稱,期間(年),平均年報酬率(%),平均週期(天),最高本金倍數,停損次數\n"

        for (offset: index,element: (id: id,name: name)) in self.sortedStocks.enumerated() {
            let multiple = self.simPrices[id]!.maxMoneyMultiple
            let roiTuple = self.simPrices[id]!.ROI()
            sumROI  += roiTuple.roi
            simDays += roiTuple.days
            let roi     = String(format: "%.2f", roiTuple.roi)
            let days    = String(format: "%.f", roiTuple.days)
            let years   = String(format: "%.1f", roiTuple.years)
            let cut     = (roiTuple.cut > 0 ? String(format:"%.f",roiTuple.cut) : "")
            let money   = String(format:"x%.f",multiple)
            text += "\(index+1),'\(id),\(name),\(years),\(roi),\(days),\(money),\(cut)\n"
        }
        let avgROI:Double = sumROI / Double(self.sortedStocks.count)
        let avgDays:Float = simDays / Float(self.sortedStocks.count)
        text += String(format:"%d支股平均年報酬率 %.1f%% (平均週期%.f天)\n",self.sortedStocks.count,avgROI,avgDays)

        return text
    }


    func csvMonthlyRoi(from:Date?=nil,to:Date?=nil) -> String {
        var text:String = ""
        var txtMonthly:String = ""

        func combineMM(_ allHeader:[String], newHeader:[String], newBody:[String]) -> (header:[String],body:[String]) {
            var mm = allHeader
            var bb = newBody
            for n in newHeader {
                var lm:String = ""
                var inserted:Bool = false
                for (idxM,m) in mm.enumerated() {
                    if n < m && n > lm {
                        mm.insert(n, at: idxM)
                        inserted = true
                        break
                    }
                    lm = m
                }
                if let ml = mm.last {
                    if !inserted && n > ml {
                        mm.append(n)
                    }
                } else {
                    mm.append(n)
                }
            }
            for m in mm {   //反過來用補完的header來補body的欄位
                var ln:String = ""
                var inserted:Bool = false
                for (idxN,n) in newHeader.enumerated() {
                    if m < n && m > ln {
                        bb.insert("", at: idxN)
                        inserted = true
                        break
                    }
                    ln = n
                }
                if let nl = newHeader.last {
                    if !inserted && m > nl {
                        bb.append("")
                    }
                } else {
                    bb.append("")
                }
            }
            return (mm,bb)
        }

        var allHeader:[String] = []     //合併後的月別標題：如果各股起迄月別不一致？所以需要合併
        var allHeaderX2:[String] = []   //前兩欄，即簡稱和本金
        for (id, _) in sortedStocks {
            let txt = self.simPrices[id]!.exportMonthlyRoi(from: from, to:to)
            if txt.body.count > 0 { //有損益才有字
                let subHeader = txt.header.split(separator: ",")
                var newHeader:[String] = []   //待合併的新的月別標題
                if subHeader.count >= 3 {
                    for (i,s) in subHeader.enumerated() {
                        if i < 2 {
                            if allHeaderX2.count < 2 {
                                allHeaderX2.append(String(s).replacingOccurrences(of: " ", with: ""))
                            }
                        } else {
                            newHeader.append(String(s).replacingOccurrences(of: " ", with: ""))   //順便去空白
                        }
                    }
                }
                let subBody = txt.body.split(separator: ",")
                var newBody:[String] = []   //待補”,"分隔的數值欄
                var newBodyX2:[String] = [] //前兩欄，即簡稱和本金
                if subBody.count >= 3 {
                    for (i,s) in subBody.enumerated() {
                        if i < 2 {
                            newBodyX2.append(String(s).replacingOccurrences(of: " ", with: "")) //順便去空白
                        } else {
                            newBody.append(String(s).replacingOccurrences(of: " ", with: ""))   //順便去空白
                        }
                    }
                }
                if newBody.count > 0 && newHeader.count > 0 {
                    //每次都把標題和逐月損益，跟之前各股的合併，這樣才能確保全部股的月欄是對齊的
                    let all = combineMM(allHeader, newHeader:newHeader, newBody:newBody)   //<<<<<<<<<< 合併
                    let allBody = newBodyX2 + all.body
                    let txtBody = (allBody.map{String($0)}).joined(separator: ", ")
                    txtMonthly += txtBody + "\n"
                    allHeader   = all.header
                }
            }
        }
        if txtMonthly.count > 0 {
            let title:String = "逐月已實現損益(%)：\n"
            for (idx,h) in allHeader.enumerated() {
                if let d = twDateTime.dateFromString(h + "/01") {
                    if h.suffix(2) == "01" {
                        allHeader[idx] = twDateTime.stringFromDate(d, format: "yyyy/M月")
                    } else {
                        allHeader[idx] = twDateTime.stringFromDate(d, format: "M月")
                    }
                }
            }
            
            //計算逐月合計，只能等全部股都合併完成後才好合計
            var sumAll:Double = 0       //總和
            var sumMonthly:[Double]=[]  //月別合計
            let txtBody:[String] = txtMonthly.components(separatedBy: CharacterSet.newlines) as [String]
            for b in txtBody {
                let txtROI:[String] = b.components(separatedBy: ", ") as [String]
                for (idx,r) in txtROI.enumerated() {
                    var roi:Double = 0
                    if let dROI = Double(r) {
                        roi = dROI
                    }
                    if idx >= 2 {   //前兩欄是簡稱和本金，故跳過
                        let i = idx - 2
                        if i == sumMonthly.count {
                            sumMonthly.append(roi)
                        } else {
                            sumMonthly[i] += roi
                        }
                        sumAll += roi
                    }
                }
            }
            let txtSummary = "合計,," + (sumMonthly.map{String(format:"%.1f",$0)}).joined(separator: ", ") + ", " + String(format:"%.1f",sumAll)
            
            //把文字通通串起來
            let allHeader = allHeaderX2 + allHeader //冠上之前保存的前兩欄標題，即簡稱和本金
            let txtHeader = (allHeader.map{String($0)}).joined(separator: ", ") + "\n"
            text = "\(title)\n\(txtHeader)\(txtMonthly)\(txtSummary)\n" //最後空行可使版面周邊的留白對稱
        }


        return text
    }











//    func taiexQuery(_ date:Date) -> String {
//        if let taiex = self.simPrices["TAIEX"] {
//            let dt = twDateTime.startOfDay(date)
//            if let ruleString = taiex.taiexQuery[dt] {
//                return ruleString
//            }
//        }
//        return ""
//    }


}
