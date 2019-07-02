//
//  simPrice.swift
//  masterUI
//
//  Created by peiyu on 2017/12/18.
//  Copyright © 2017年 unlock.com.tw. All rights reserved.
//

import UIKit    //因為用到UIApplication參考CoreData Context，所以不能只用Foundation
import CoreData


//個股模擬參數、價格下載與統計、買賣規則
class simPrice:NSObject, NSCoding {
    var id:String   = ""
    var name:String = ""
    var initMoney:Double = 0                    //起始本金
    var dateStart:Date = Date.distantPast       //模擬起始日
    var dateEnd:Date = Date()                   //模擬截止日
    var dateEndSwitch:Bool = false              //指定截止日
    var dateEarlier:Date = Date.distantFuture   //dateStart往前3個月
    var dateDividends:[Date] = []               //除權息日期列表，由 cnyesDividend() 填入
    var dateDividend:[Date:Double] = [:]        //除權息日期和現金股利
    var willUpdateAllSim:Bool = true //重算全部的模擬數值
    var willUpdateAllMa:Bool  = true //重算全部的統計數值
    var willResetMoney:Bool = true   //清除加減碼
    var willGiveMoney:Bool = true
    var willResetReverse:Bool = true
    var simReversed:Bool = false
    var maxMoneyMultiple:Double = 0
    var priceLast:Price? = nil
    var priceEnd:Price?  = nil
    var twseTask:[Date:Int]=[:]
    var cnyesTask:[String:Int]=[:]
    var endProperty:(ma60Rank:String?,cumulROI:Double?,cumulProfit:Double?,cumulDays:Float?,simRound:Float?,cumulCut:Float?) = (nil,nil,nil,nil,nil,nil)
    var lastProperty:(qtyInventory:Double?,qtyBuy:Double?,qtySell:Double?,priceClose:Double?,source:String?,simDays:Float?,priceUpward:String?,simRule:String?,simROI:Double?) = (nil,nil,nil,nil,nil,nil,nil,nil,nil)
    var dtRange:(first:Date?,last:Date?,earlier:Date?,start:Date?,end:Date?) = (nil,nil,nil,nil,nil)
    var dtRangeCopy:(first:Date,last:Date,earlier:Date,start:Date,end:Date)?
    var paused:Bool = false
    

    var masterUI:masterUIDelegate?

    let earlyMonths:Int = -18   //往前撈1年半價格以得完整統計之ma60z
    let maxDouble:Double = Double.greatestFiniteMagnitude
    let minDouble:Double = Double.leastNormalMagnitude

    init(id:String,name:String,master:masterUIDelegate?=nil) {
        super.init()
        self.id     = id
        self.name   = name
        if let _ = master {
            self.masterUI = master
        }
        resetToDefault()



    }

    required init?(coder aDecoder: NSCoder) {
        id          = aDecoder.decodeObject(forKey: "id") as! String
        name        = aDecoder.decodeObject(forKey: "name") as! String
        initMoney   = aDecoder.decodeDouble(forKey: "initMoney")
        dateStart       = aDecoder.decodeObject(forKey: "dateStart") as! Date
        dateEnd         = aDecoder.decodeObject(forKey: "dateEnd") as! Date
        dateEarlier     = aDecoder.decodeObject(forKey: "dateEarlier") as! Date
        dateEndSwitch   = aDecoder.decodeBool(forKey: "dateEndSwitch")
        willUpdateAllSim = aDecoder.decodeBool(forKey: "willUpdateAllSim")
        willResetMoney   = aDecoder.decodeBool(forKey: "willResetMoney")
        maxMoneyMultiple = aDecoder.decodeDouble(forKey: "maxMoneyMultiple")
        if aDecoder.containsValue(forKey: "simReversed") {
            simReversed  = aDecoder.decodeBool(forKey: "simReversed")
        } else {
            simReversed = false
        }
        if aDecoder.containsValue(forKey: "willGiveMoney") {
            willGiveMoney  = aDecoder.decodeBool(forKey: "willGiveMoney")
        } else {
            willGiveMoney = true
        }
        if aDecoder.containsValue(forKey: "willResetReverse") {
            willResetReverse  = aDecoder.decodeBool(forKey: "willResetReverse")
        } else {
            willResetReverse = true
        }
        if aDecoder.containsValue(forKey: "twseTask") {
            twseTask  = aDecoder.decodeObject(forKey: "twseTask") as! [Date:Int]
        } else {
            twseTask = [:]
        }
        if aDecoder.containsValue(forKey: "cnyesTask") {
            cnyesTask  = aDecoder.decodeObject(forKey: "cnyesTask") as! [String:Int]
        } else {
            cnyesTask = [:]
        }
        if aDecoder.containsValue(forKey: "dateDividend") {
            dateDividend  = aDecoder.decodeObject(forKey: "dateDividend") as! [Date:Double]
        } else {
            dateDividend = [:]
        }
        if aDecoder.containsValue(forKey: "dtRange") {
            let dt = aDecoder.decodeObject(forKey: "dtRange") as! [Date?]
            if dt.count >= 5 {
                dtRange.earlier = dt[0]
                dtRange.end     = dt[1]
                dtRange.first   = dt[2]
                dtRange.last    = dt[3]
                dtRange.start   = dt[4]
            } else {
                dtRange = (nil,nil,nil,nil,nil)
            }
        } else {
            dtRange = (nil,nil,nil,nil,nil)
        }
        if aDecoder.containsValue(forKey: "endProperty") {
            let end = aDecoder.decodeObject(forKey: "endProperty") as! [Any?]
            endProperty.cumulDays   = end[0] as? Float
            endProperty.cumulProfit = end[1] as? Double
            endProperty.cumulROI    = end[2] as? Double
            endProperty.ma60Rank    = end[3] as? String
            endProperty.simRound    = end[4] as? Float
            if end.count >= 6 {
                endProperty.cumulCut = end[5] as? Float      //3.2.3起加入cumulCut，沒有的話nil不要給else初值
            }
        } else {
            endProperty = (nil,nil,nil,nil,nil,nil)
        }
        if aDecoder.containsValue(forKey: "lastProperty") {
            let last = aDecoder.decodeObject(forKey: "lastProperty") as! [Any?]
            lastProperty.priceClose   = last[0] as? Double
            lastProperty.qtyBuy       = last[1] as? Double
            lastProperty.qtySell      = last[2] as? Double
            lastProperty.qtyInventory = last[3] as? Double
            lastProperty.source       = last[4] as? String
            if last.count >= 6 {
                lastProperty.simDays = last[5] as? Float    //3.1.3起加入simDays，沒有的話nil不要給else初值
            }
            if last.count >= 7 {
                lastProperty.priceUpward = last[6] as? String   //3.1.5起加入，沒有的話nil不要給else初值
            }
            if last.count >= 8 {
                lastProperty.simRule = last[7] as? String   //3.1.5起加入，沒有的話nil不要給else初值
            }
            if last.count >= 9 {
                lastProperty.simROI = last[8] as? Double   //3.3.6(3)起加入，沒有的話nil不要給else初值
            }
        } else {
            lastProperty = (nil,nil,nil,nil,nil,nil,nil,nil,nil)
        }
        priceEnd    = nil
        priceLast   = nil
        if aDecoder.containsValue(forKey: "paused") {
            paused = aDecoder.decodeBool(forKey: "paused")
        }
        if aDecoder.containsValue(forKey: "willUpdateAllMa") {
            willUpdateAllMa = aDecoder.decodeBool(forKey: "willUpdateAllMa")
        }


    }



    func encode(with aCoder: NSCoder) {
        aCoder.encode(id,           forKey: "id")
        aCoder.encode(name,         forKey: "name")
        aCoder.encode(initMoney,    forKey: "initMoney")
        aCoder.encode(dateStart,    forKey: "dateStart")
        aCoder.encode(dateEnd,      forKey: "dateEnd")
        aCoder.encode(dateEarlier,  forKey: "dateEarlier")
        aCoder.encode(dateEndSwitch,forKey: "dateEndSwitch")
        aCoder.encode(willUpdateAllSim, forKey: "willUpdateAllSim")
        aCoder.encode(willUpdateAllMa, forKey: "willUpdateAllMa")
        aCoder.encode(willResetMoney,   forKey: "willResetMoney")
        aCoder.encode(maxMoneyMultiple, forKey: "maxMoneyMultiple")
        aCoder.encode(simReversed,      forKey: "simReversed")
        aCoder.encode(willGiveMoney,    forKey: "willGiveMoney")
        aCoder.encode(willResetReverse, forKey: "willResetReverse")
        aCoder.encode(twseTask,     forKey: "twseTask")
        aCoder.encode(cnyesTask,    forKey: "cnyesTask")
        aCoder.encode(dateDividend, forKey: "dateDividend")

        var dt:[Date?] = []
        dt.append(dtRange.earlier)
        dt.append(dtRange.end)
        dt.append(dtRange.first)
        dt.append(dtRange.last)
        dt.append(dtRange.start)
        aCoder.encode(dt,      forKey: "dtRange")

        var end:[Any?] = []
        end.append(endProperty.cumulDays)
        end.append(endProperty.cumulProfit)
        end.append(endProperty.cumulROI)
        end.append(endProperty.ma60Rank)
        end.append(endProperty.simRound)
        end.append(endProperty.cumulCut)
        aCoder.encode(end,      forKey: "endProperty")

        var last:[Any?] = []
        last.append(lastProperty.priceClose)
        last.append(lastProperty.qtyBuy)
        last.append(lastProperty.qtySell)
        last.append(lastProperty.qtyInventory)
        last.append(lastProperty.source)
        last.append(lastProperty.simDays)
        last.append(lastProperty.priceUpward)
        last.append(lastProperty.simRule)
        last.append(lastProperty.simROI)
        aCoder.encode(last,     forKey: "lastProperty")
        aCoder.encode(paused,   forKey: "paused")

    }

    func connectMaster(_ master:masterUIDelegate?) {
        self.masterUI = master
    }

    //預設的初始參數
    func resetToDefault(fromYears:Int?=nil,forYears:Int?=nil) {
        initMoney = defaultInitMoney()
        let dates = defaultDates(fromYears:fromYears,forYears: forYears)
        dateStart = dates.dateStart
        dateEndSwitch = dates.dateEndSwitch
        dateEnd = dates.dateEnd
        dateEarlier = dates.dateEarlier
        resetAllProperty()
        resetSimStatus()
    }

    func resetPriceProperty() {
        priceLast    = nil
        priceEnd     = nil
        dtRange      = (nil,nil,nil,nil,nil)
        endProperty  = (nil,nil,nil,nil,nil,nil)
        lastProperty = (nil,nil,nil,nil,nil,nil,nil,nil,nil)

    }

    func resetAllProperty() {
        resetPriceProperty()
        maxMoneyMultiple = 0
        simReversed = false
        self.willUpdateAllSim   = true
    }
    
    func resetSimStatus() {
        willUpdateAllSim = true
        willResetMoney = true
        willGiveMoney = true
        willResetReverse = true
        simReversed = false
        maxMoneyMultiple = 0
    }

    func defaultInitMoney()->Double {
        let defaults:UserDefaults = UserDefaults.standard
        let defaultMoney = defaults.double(forKey: "defaultMoney")
        return defaultMoney
    }


    func defaultDates(fromYears:Int?=nil,forYears:Int?=nil) -> (dateStart:Date,dateEndSwitch:Bool,dateEnd:Date,dateEarlier:Date) {
        let defaults:UserDefaults = UserDefaults.standard
        var defaultYears:Int
        if let y = fromYears {
            defaultYears = y
        } else {
            defaultYears = defaults.integer(forKey: "defaultYears")
        }
        var start:Date = Date.distantPast
        var earlier:Date = Date.distantFuture

        var today:Date = twDateTime.startOfDay()
        if self.masterUI!.getStock().simTesting {
            if let dtTest = self.masterUI?.getStock().simTestDate {
                today = dtTest
            }
        }
        if let dt1 = twDateTime.calendar.date(byAdding: .year, value: (0 - defaultYears), to: today) {
            start = dt1
        }
        var endSwitch:Bool = false
        var end:Date = today
        if let y = forYears {    //simTesting時會指定期間幾年
            if let dt2 = twDateTime.calendar.date(byAdding: .year, value: y, to: start) {
                end = twDateTime.endOfDay(dt2)
                endSwitch = true
            }
        }
        earlier = dateEarlier(start)

        resetAllProperty()
        return (start,endSwitch,end,earlier)
    }

    func dateStart(_ date:Date) {
        dateStart = twDateTime.startOfDay(date)
        dateEarlier = dateEarlier(dateStart)
    }

    func dateEarlier(_ dtStart:Date) -> Date {
        if let dtE = twDateTime.calendar.date(byAdding: .month, value: earlyMonths, to: dtStart) {
            return dtE
        } else {
            return dtStart
        }
    }





    //截至該筆成交價格為止的平均年報酬率
    func ROI(_ price:Price?=nil) -> (pl:Double,roi:Double,years:Double,days:Float,rank:String,cut:Float) {
        var roi:Double = 0
        var years:Double = 0
        var pl:Double = 0
        var rank:String = ""
        var cumulROI:Double = 0
        var days:Float = 0
        var cut:Float = 0

        var theDate:Date = twDateTime.startOfDay()
        var dt0:Date = Date.distantPast
        var dt1:Date = Date.distantFuture


        if let _ = price {
            theDate     = price!.dateTime
            rank        = price!.ma60Rank
            cumulROI    = price!.cumulROI
            pl          = price!.cumulProfit
            cut         = price!.cumulCut
            if price!.simRound != 0 {
                days = price!.cumulDays / price!.simRound
            }
        } else {
            let end = getPropertyEnd()
            theDate     = end.dtEnd
            rank        = end.ma60Rank
            cumulROI    = end.cumulROI
            pl          = end.cumulProfit
            cut         = end.cumulCut
            if end.simRound != 0 {
                days    = end.cumulDays / end.simRound
            }
        }

        //成交日、今天、截止日，哪一個在前？
        if dateEndSwitch == true {
            if theDate.compare(dateEnd) == .orderedAscending {
                dt1 = theDate
            } else {
                dt1 = dateEnd
            }
        } else {
            dt1 = theDate
        }

        //首成交日、起始日，哪一個在後？
        let dt = dateRange()
        if dt.start.compare(dateStart) == .orderedAscending || dt.start == Date.distantFuture  {
            dt0 = dateStart
        } else {
            dt0 = dt.start
        }


        years = dt1.timeIntervalSince(dt0) / 86400 / 365
        if years < 0 || years > 100 {   //dt1可能是Date.distantPast會造成years異常
            years = 0
        }

        roi = cumulROI / (years < 1 ? 1 : years)

        //        if roi == 0 {
        //            masterUI?.masterLog("\(self.id) \(self.name) roi=零 years=\(years)")
        //        }

        return (pl,roi,years,days,rank,cut)

    }


    func dateRange() -> (first:Date,last:Date,earlier:Date,start:Date,end:Date) {
        if dtRange.end == nil {
            let _ = getPriceEnd()
        }
        if dtRange.last == nil {
            let _ = getPriceLast()
        }
        if dtRange.first == nil {
            let theOne:[Price] = fetchPrice("all", fetchLimit: 1, asc: true)
            if theOne.count > 0 {
                dtRange.first = theOne.first?.dateTime
            } else {
                dtRange.first = Date.distantFuture
            }
        }
        if dtRange.earlier == nil {
            let theOne:[Price] = fetchPrice(fetchLimit: 1, asc: true)
            if theOne.count > 0 {
                dtRange.earlier = theOne.first?.dateTime
            } else {
                dtRange.earlier = Date.distantFuture
            }
        }
        if dtRange.start == nil {
            let theOne:[Price] = fetchPrice(dtStart: dateStart,fetchLimit: 1, asc: true)
            if theOne.count > 0 {
                dtRange.start = theOne.first?.dateTime
            } else {
                dtRange.start = Date.distantFuture
            }
        }
        return (dtRange.first!,dtRange.last!,dtRange.earlier!,dtRange.start!,dtRange.end!)
    }

    func getPropertyEnd() -> (dtEnd:Date,ma60Rank:String,cumulROI:Double,cumulProfit:Double,cumulDays:Float,simRound:Float,cumulCut:Float) {
        if endProperty.cumulCut == nil || endProperty.cumulROI == nil || endProperty.ma60Rank == "" { //新欄必須是nil要列出
            let _ = getPriceEnd()
        }
        return (dtRange.end!,endProperty.ma60Rank!,endProperty.cumulROI!,endProperty.cumulProfit!,endProperty.cumulDays!,endProperty.simRound!,endProperty.cumulCut!)
    }

    func getPriceEnd(_ end:Price?=nil) -> Price? {
        if end != nil {
            priceEnd = end
        }
        if priceEnd == nil {
            let theOne:[Price] = fetchPrice(fetchLimit: 1, asc: false)
            if theOne.count > 0 {
                priceEnd = theOne.first
            }
        }
        if let _ = priceEnd {
            dtRange.end = priceEnd!.dateTime
            endProperty.cumulDays   = priceEnd!.cumulDays
            endProperty.cumulProfit = priceEnd!.cumulProfit
            endProperty.cumulROI    = priceEnd!.cumulROI
            endProperty.ma60Rank    = priceEnd!.ma60Rank
            endProperty.simRound    = priceEnd!.simRound
            endProperty.cumulCut    = priceEnd!.cumulCut
            if (dateEndSwitch == false || dateEnd.compare(dtRange.end!) != .orderedAscending) { //priceLast == nil &&
                priceLast = priceEnd!
                dtRange.last = dtRange.end
                lastProperty.priceClose   = priceLast!.priceClose
                lastProperty.qtyBuy       = priceLast!.qtyBuy
                lastProperty.qtySell      = priceLast!.qtySell
                lastProperty.qtyInventory = priceLast!.qtyInventory
                lastProperty.source       = priceLast!.updatedBy
                lastProperty.simDays      = priceLast!.simDays
                lastProperty.priceUpward  = priceLast!.priceUpward
                lastProperty.simRule      = priceLast!.simRule
                lastProperty.simROI       = (priceLast!.simROI != 0 ? priceLast!.simROI : priceLast!.simUnitDiff)
            }
        } else {
            dtRange.end = Date.distantPast
            endProperty = ("",0,0,0,0,0)
        }

        return priceEnd
    }

    func getPropertyLast() ->  (dtLast:Date,qtyInventory:Double,qtyBuy:Double,qtySell:Double,priceClose:Double,source:String,simDays:Float,priceUpward:String,simRule:String,simROI:Double) {
        if lastProperty.simDays == nil || lastProperty.priceClose == nil || lastProperty.source == "" || lastProperty.priceUpward == nil || lastProperty.simRule == nil  || lastProperty.simROI == nil {   //新欄必定是nil要列出
            let _ = getPriceLast()
        }
        return (dtRange.last!,lastProperty.qtyInventory!,lastProperty.qtyBuy!,lastProperty.qtySell!,lastProperty.priceClose!,lastProperty.source!,lastProperty.simDays!,lastProperty.priceUpward!,lastProperty.simRule!,lastProperty.simROI!)
    }

    func getPriceLast(_ last:Price?=nil) -> Price? {
        if last != nil {
            priceLast = last
        }
        if priceLast == nil {
            let theLast:[Price] = fetchPrice("all", fetchLimit: 1, asc: false)
            if theLast.count > 0 {
                priceLast = theLast.first
            }
        }
        if let _ = priceLast {
            dtRange.last = priceLast!.dateTime
            lastProperty.priceClose   = priceLast!.priceClose
            lastProperty.qtyBuy       = priceLast!.qtyBuy
            lastProperty.qtySell      = priceLast!.qtySell
            lastProperty.qtyInventory = priceLast!.qtyInventory
            lastProperty.source       = priceLast!.updatedBy
            lastProperty.simDays      = priceLast!.simDays
            lastProperty.priceUpward  = priceLast!.priceUpward
            lastProperty.simRule      = priceLast!.simRule
            lastProperty.simROI       = (priceLast!.simROI != 0 ? priceLast!.simROI : priceLast!.simUnitDiff)
            if (dateEndSwitch == false || dateEnd.compare(dtRange.last!) != .orderedAscending) {    //dtRange.end == nil &&
                priceEnd = priceLast
                dtRange.end = priceEnd!.dateTime
                endProperty.cumulDays   = priceEnd!.cumulDays
                endProperty.cumulProfit = priceEnd!.cumulProfit
                endProperty.cumulROI    = priceEnd!.cumulROI
                endProperty.ma60Rank    = priceEnd!.ma60Rank
                endProperty.simRound    = priceEnd!.simRound
                endProperty.cumulCut    = priceEnd!.cumulCut
            }
        } else {
            dtRange.last = Date.distantPast
            lastProperty = (0,0,0,0,"",0,"","",0)
        }

        return priceLast
    }





    //****************
    //*** CoreData ***
    //****************

    var privateContext:NSManagedObjectContext = {
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return privateContext
    }()

    func getContext() -> NSManagedObjectContext{
        if Thread.current == Thread.main {
            let mainContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
            return mainContext
        } else {
            return privateContext
        }
    }





    func fetchPrice (_ dateOP:String?=nil,dtStart:Date?=nil,dtEnd:Date?=nil,fetchLimit:Int?=nil, sId:String?=nil, asc:Bool=true) -> [Price] {
        //都不指定參數時：抓起迄期間並順排
        let context = getContext()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entityDescription = NSEntityDescription.entity(forEntityName: "Price", in: context)
        fetchRequest.entity = entityDescription
        var predicates:[NSPredicate] = []
        var dtS:Date = dateEarlier
        var dtE:Date = (self.dateEndSwitch ? self.dateEnd : Date())
        if let pId = sId {
            predicates.append(NSPredicate(format: "id = %@", pId))
        } else {
            predicates.append(NSPredicate(format: "id = %@", id))
        }
        
        

        if let _ = dtStart {
            dtS = dtStart!
        }
        if let _ = dtEnd {
            dtE = dtEnd!
        }
        dtS = twDateTime.startOfDay(dtS)
        dtE = twDateTime.endOfDay(dtE)
        if let _ = dateOP {
            if dateOP! == "<" {
                predicates.append(NSPredicate(format: "dateTime < %@", dtS as CVarArg))
            } else if dateOP! == ">" {
                predicates.append(NSPredicate(format: "dateTime > %@", dtE as CVarArg))
            } else if dateOP! == "=" {
                predicates.append(NSPredicate(format: "dateTime >= %@", dtS as CVarArg))
                predicates.append(NSPredicate(format: "dateTime <= %@", dtE as CVarArg))
            } //有OP但都不是以上條件，就是all，抓全部日期
        } else {
            //沒有OP就是"="
            predicates.append(NSPredicate(format: "dateTime >= %@", dtS as CVarArg))
            predicates.append(NSPredicate(format: "dateTime <= %@", dtE as CVarArg))
        }


        fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateTime", ascending: asc)]
        if let _ = fetchLimit {
            fetchRequest.fetchLimit = fetchLimit!
        }

        do {
            if let Prices = try context.fetch(fetchRequest) as? [Price] {
                return Prices
            }
        } catch {
            let fetchError = error as NSError
            self.masterUI?.masterLog("\(self.id) \(self.name) \tfetchPrice error:\n\(fetchError)")
        }

        return []

    }

    func fetchPriceUpdatedBy (by:[String],byOthers:Bool?=false) -> [Price] {
        let context = getContext()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entityDescription = NSEntityDescription.entity(forEntityName: "Price", in: context)
        fetchRequest.entity = entityDescription
        let predicate1 = NSPredicate(format: "id = %@", id)
        let op = (byOthers! ? "NOT IN" : "IN")
        let predicate2 = NSPredicate(format: "updatedBy "+op+" %@", by)
        fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: [predicate1, predicate2])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateTime", ascending: true)]
        do {
            if let Prices = try context.fetch(fetchRequest) as? [Price] {
                return Prices
            }
        } catch {
            let fetchError = error as NSError
            self.masterUI?.masterLog("\(self.id) \(self.name) \tfetchPriceUpdatedBy error:\n\(fetchError)")
        }

        return []

    }



    func deletePrice(_ mode:String?="") {
        //不管是移除股群或刪除股價都是在main執行，丟背景反而造成要下股價背景卻還沒刪完所以沒下的問題
        let context = self.getContext()
        let Prices = self.fetchPrice("all")
        for price in Prices {
            context.delete(price)
        }
        self.saveContext()
        self.masterUI?.masterLog("*\(self.id) \(self.name) \tdeletePrice:\(Prices.count)筆")

        self.resetAllProperty()
        self.resetSimStatus()
        self.twseTask  = [:]
        self.cnyesTask = [:]

    }

    func deleteLastMonth(allStocks:Bool?=false) {
        let dt = dateRange()
        let dtS = twDateTime.startOfMonth(dt.last)
        let dtE = twDateTime.endOfMonth(dt.last)

        let context = self.getContext()
        let Prices = self.fetchPrice(dtStart: dtS, dtEnd: dtE)
        for (index,price) in Prices.enumerated() {
            context.delete(price)
            if allStocks! {  //全部股票都刪一個月，故需有進度
                masterUI?.getStock().setProgress(id, progress: Float((index+1)/Prices.count))
            }
        }
        self.saveContext()
        if allStocks! {
            self.masterUI?.getStock().setProgress(self.id, progress: 1)
        }
        //不知道為啥saveContext()會變動priceLast的內容，所以必須save之後才nil
        self.resetAllProperty()
        self.masterUI?.masterLog("*\(self.id) \(self.name) \tdeleteLastMonth:\(Prices.count)筆")
    }

    func deleteFrom(date:Date) {
        let dtS = twDateTime.startOfDay(date)

        let context = self.getContext()
        let Prices = self.fetchPrice(dtStart: dtS)
        for (index,price) in Prices.enumerated() {
            context.delete(price)
            masterUI?.getStock().setProgress(id, progress: Float((index+1)/Prices.count))
        }
        self.saveContext()
        self.masterUI?.getStock().setProgress(self.id, progress: 1)
        //不知道為啥saveContext()會變動priceLast的內容，所以必須save之後才nil
        self.resetAllProperty()
        self.masterUI?.masterLog("*\(self.id) \(self.name) \tdeleteFrom \(twDateTime.stringFromDate(dtS)):\(Prices.count)筆")

    }


    func saveContext() {
        let context = getContext()
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                self.masterUI?.masterLog("\(self.id) \(self.name) \tsaveContext error:\n\(nserror)\n\n")
            }
        }
        if Thread.current == Thread.main {
            privateContext.reset()
        }
    }

    //逐月已實現損益
    func exportMonthlyRoi(from:Date?=nil,to:Date?=nil) -> (header:String,body:String) {
/*
        func padding(_ text:String ,toLength: Int=7, character: Character=" ", toRight:Bool=false) -> String {
            var txt:String = ""
            var len:Int = 0
            if text.count > 0 {
                for c in text {
                    let C = Character(String(c).uppercased())
                    if c >= "0" && c < "9" || C >= "A" && C <= "Z" || c == "­" || c == "%" || c == "." || c == " " {
                        len += 1
                    } else {
                        len += 2    //可能是中文字，要算2個space的位置
                        if len - toLength == 1 {    //超過截斷，但是只超過1位要補1位的space
                            txt += " "
                        }
                    }
                    if len <= toLength {
                        txt += String(c)
                    }

                }
                let newLength = len //text.count    //在固定長度的String左邊填空白
                if newLength < toLength {
                    if toRight {
                        txt = txt + String(repeatElement(character, count: toLength - newLength))
                    } else {
                        txt = String(repeatElement(character, count: toLength - newLength)) + txt
                    }
                }
            } else {
                txt = String(repeatElement(character, count: toLength))
            }
            return txt
        }
 */

        var dtFrom:Date? = from
        var dtTo:Date?   = to
        let dtRange = dateRange()
        if dtFrom == nil {
            if let dt = twDateTime.calendar.date(byAdding: .month, value: -12, to: dtRange.end) {
                dtFrom = twDateTime.startOfMonth(dt)
            } else {
                dtFrom = twDateTime.startOfMonth(dtRange.end)
            }
        } else {
            if dtFrom!.compare(dtRange.start) == .orderedAscending {
                dtFrom = dtRange.start
            }
            if dtFrom!.compare(dtRange.end) == .orderedDescending {
                dtFrom = dtRange.end
            }
        }
        if dtTo == nil {
            dtTo = twDateTime.endOfDay(dateRange().end)
        } else {
            if dtTo!.compare(dtRange.start) == .orderedAscending {
                dtTo = dtRange.start
            }
            if dtTo!.compare(dtRange.end) == .orderedDescending {
                dtTo = dtRange.end
            }
        }



        var txtHeader:String = ""
        var txtBody:String = ""
        var mm:Date = twDateTime.startOfMonth(dtFrom!)
        var roi:Double = 0
        var maxMoney:Double = 0
        let Prices = self.fetchPrice(dtStart:dtFrom, dtEnd:dtTo, asc:true)
        if Prices.count > 0 {
            for price in Prices {
                let mmPrice = twDateTime.startOfMonth(price.dateTime)
                if mmPrice.compare(mm) == .orderedDescending {  //跨月了
                    let txtRoi = (roi == 0 ? "" : String(format:"%.1f%",roi))
                    txtHeader += ", \(twDateTime.stringFromDate(mm, format: "yyyy/MM"))"
                    txtBody   += ", \(txtRoi)"
                    mm  = mmPrice
                    roi = 0
                }
                if price.qtySell > 0 {
                    roi += price.simROI
                    if price.moneyMultiple > maxMoney {
                        maxMoney = price.moneyMultiple
                    }
                }
            }
            if maxMoney > 0 {
                let txtRoi = (roi == 0 ? "" : String(format:"%.1f%",roi))
                txtHeader = "簡稱" + ", 本金" + txtHeader + ", \(twDateTime.stringFromDate(mm, format: "yyyy/MM"))"
                txtBody   = self.name + ", \(String(format:"x%.f",maxMoney))" + txtBody + ", \(txtRoi)"
            } else {
                txtHeader = ""
                txtBody   = ""
            }

        }
        return (txtHeader,txtBody)
    }



    func exportString(_ ext:Bool?=false) -> String {
        var exportString: String = "沒有資料"
        let Prices = self.fetchPrice(asc:false)

        if Prices.count > 0 {
            exportString = "年, 日期, 時間, 簡稱, 收盤價, 開盤價, 最高價, 最低價, 成交量, 量差分"
            if ext! {
                exportString += ", 最低差, 60高差, 60低差, 250高差, 250低差"
            }
            exportString += ", ma20"
            if ext! {
                exportString += ", ma20差, ma20Min, ma20Max, ma20日, ma20低, ma20高"
            }
            exportString += ", ma60"
            if ext! {
                exportString += ", 差分, ma60差, ma60Min, ma60Max, ma60日, ma60低, ma60高, 60日差"
                exportString += ", ma差, ma差Min, ma差Max, ma差日"
            }
            exportString += ", j, d, k"
            if ext! {
                exportString += ",k差分, k20, k80, k升率, kd差, ema12, ema26, macd9, oscL, oscH, min9d, max9d,osc差分"   //, 5日k
            }
            exportString += ", osc, 本金餘, 本金倍數, 累計年數"
            if ext! {
                exportString += ", 除權息"
            }
            exportString += ", 累計損益, 累計成本, 年報酬率"
            if ext! {
                exportString += ",累計天 , 輪, 規則"
            }
            exportString += ", 買, 賣, 餘, 天數, 成本價, 成本價差"
            exportString += ", 當時損益, 加減碼"

            exportString += "\n"

            for price in Prices {

                let year    = twDateTime.stringFromDate(price.dateTime, format: "yyyy")
                let date    = twDateTime.stringFromDate(price.dateTime, format: "yyyy/MM/dd")
                let time    = twDateTime.stringFromDate(price.dateTime, format: "HH:mm:ss")
                let close   = String(format: "%.2f",price.priceClose)
                let open    = String(format: "%.2f",price.priceOpen)
                let high    = String(format: "%.2f",price.priceHigh)
                let low     = String(format: "%.2f",price.priceLow)
                let volume  = String(format: "%.2f",price.priceVolume)
                let volZ    = String(format: "%.2f",price.priceVolumeZ)
                let ma20d   = String(format: "%.2f",price.ma20)
                let ma60d   = String(format: "%.2f",price.ma60)
                let k       = String(format: "%.2f",price.kdK)
                let d       = String(format: "%.2f",price.kdD)
                let j       = String(format: "%.2f",price.kdJ)
                let days    = String(format: price.simDays == 0 ? "" : "%.f",price.simDays)
                let unitCostDiff = (price.simUnitDiff == 0 ? "" : String(format: "%.2f",price.simUnitDiff))
                let unitCost = (price.simUnitCost == 0 ? "" : String(format: "%.2f",price.simUnitCost))
                let kdKZ    = String(format: "%.1f",price.kdKZ)


                //以下擴充欄位
//                let price60High = String(format: "%.2f",price.price60High)
//                let price60Low = String(format: "%.2f",price.price60Low)
                let kdDiff = String(format: "%.2f",(price.kdK - price.kdD))
                let lowDiff = String(format: "%.2f",price.priceLowDiff)
                let ma20Max9d = String(format: "%.2f",price.ma20Max9d)
                let ma20Min9d = String(format: "%.2f",price.ma20Min9d)
                let ma60Max9d = String(format: "%.2f",price.ma60Max9d)
                let ma60Min9d = String(format: "%.2f",price.ma60Min9d)
                let maMax9d   = String(format: "%.2f",price.maMax9d)
                let maMin9d   = String(format: "%.2f",price.maMin9d)
                let ma60Diff  = String(format: "%.2f",price.ma60Diff)
                let ma20Diff  = String(format: "%.2f",price.ma20Diff)
                let ma60Days = String(format: "%.f",price.ma60Days)
                let ma60Avg = String(format: "%.1f",price.ma60Avg)
                let ma60Z   = String(format: "%.1f",price.ma60Z)
                let ma20Days = String(format: "%.f",price.ma20Days)
                let maDiff    = String(format: "%.2f",price.maDiff)
                let maDiffDays = String(format: "%.f",price.maDiffDays)
                let kGrow = String(format: "%.2f",price.kGrowRate)
                let price60HighDiff = String(format: "%.2f",price.price60HighDiff)
                let price60LowDiff = String(format: "%.2f",price.price60LowDiff)
                let price250HighDiff = String(format: "%.2f",price.price250HighDiff)
                let price250LowDiff = String(format: "%.2f",price.price250LowDiff)
                let k20       = String(format: "%.f",price.k20Base)
                let k80       = String(format: "%.f",price.k80Base)
                let dividend  = (price.dividend == -999 ? "" : String(format:"%.f",price.dividend))

                let ruleS1:String = (price.simRuleBuy.count > 0 && price.simRule.count > 0 ? "/" : "")
                let ruleLevel:String = ((price.simRule == "L" || price.simRule == "H") ? String(format:"%.f",price.simRuleLevel) : "")
                let simRule:String = price.simRuleBuy + ruleS1 + price.simRule + ruleLevel
//                let ruleS2:String = (buyRule.count > 0 ? "," : "")
//                let simRule = buyRule + ruleS2 + String(format:"%.2f",price.ma60Avg)


                let macdEma12  = String(format: "%.2f",price.macdEma12)
                let macdEma26  = String(format: "%.2f",price.macdEma26)
                let macd9      = String(format: "%.2f",price.macd9)
                let macdOsc    = String(format: "%.2f",price.macdOsc)
                let macdOscZ   = String(format: "%.1f",price.macdOscZ)
                let macdOscL   = String(format: "%.2f",price.macdOscL)
                let macdOscH   = String(format: "%.2f",price.macdOscH)
                let macdMin9d  = String(format: "%.2f",price.macdMin9d)
                let macdMax9d  = String(format: "%.2f",price.macdMax9d)

                let ma20L  = String(format: "%.f",price.ma20L)
                let ma20H  = String(format: "%.f",price.ma20H)
                let ma60L  = String(format: "%.f",price.ma60L)
                let ma60H  = String(format: "%.f",price.ma60H)

                //以上擴充欄位


                let qtyBuy  = String(format: price.qtyBuy == 0 ? "" : "%.0f",price.qtyBuy)
                let qtySell = String(format: price.qtySell == 0 ? "" : "%.0f",price.qtySell)
                let qtyInventory    = String(format: price.qtyInventory == 0 ? "" : "%.0f",price.qtyInventory)
                let simIncome       = String(format: price.simIncome == 0 ? "" : "%.0f",price.simIncome)
                let simBalance      = String(format: price.simBalance == -1 ? "" : "%.0f",price.simBalance)
                let moneyMultiple = String(format: price.moneyMultiple == 0 ? "" : "%.0f",price.moneyMultiple)

                let MoneyChange:Double = price.moneyChange

                var changeRemark:String = price.moneyRemark

                if MoneyChange > 0 {
                    changeRemark = String(format: "+%.0f",MoneyChange)
                } else if MoneyChange < 0 {
                    changeRemark = String(format: "%.0f",MoneyChange)
                }


                let roiTuple = self.ROI(price)

                let pl = String(format: roiTuple.pl == 0 ? "" : "%.0f",roiTuple.pl)
                let yy = String(format: roiTuple.years == 0 ? "" : "%.2f",roiTuple.years)
                let r  = String(format: roiTuple.roi == 0 ? "" : "%.2f",roiTuple.roi)
                let cumulDays = String(format: price.cumulDays == 0 ? "" : "%.0f",price.cumulDays)
                let simRound  = String(format: price.simRound == 0 ? "" : "%.0f",price.simRound)
                let cumulCost = (price.cumulCost == 0 ? "" : String(format: "%.0f",price.cumulCost))



                exportString += year + "," + date + "," + time + "," + self.name + "," + close + "," + open + "," + high + "," + low + "," + volume + "," + volZ
                if ext! {
                    exportString += "," + lowDiff +
                        "," + price60HighDiff +
                        "," + price60LowDiff +
                        "," + price250HighDiff +
                        "," + price250LowDiff
                }
                exportString += "," + ma20d
                if ext! {
                    exportString +=
                        "," + ma20Diff  +
                        "," + ma20Min9d +
                        "," + ma20Max9d +
                        "," + ma20Days +
                        "," + ma20L +
                        "," + ma20H
                }
                exportString += "," + ma60d
                if ext! {
                    exportString +=
                        "," + ma60Z     +
                        "," + ma60Diff  +
                        "," + ma60Min9d +
                        "," + ma60Max9d +
                        "," + ma60Days  +
                        "," + ma60L +
                        "," + ma60H +
                        "," + ma60Avg  +
                        "," + maDiff  +
                        "," + maMin9d +
                        "," + maMax9d +
                        "," + maDiffDays
                }

                exportString += "," + j + "," + d + "," + k
                if ext! {
                    exportString +=
                        "," + kdKZ +
                        "," + k20 +
                        "," + k80 +
                        "," + kGrow +
                        "," + kdDiff +
                        //                                "," + kGrowing +
                        "," + macdEma12 +
                        "," + macdEma26 +
                        "," + macd9 +
                        "," + macdOscL +
                        "," + macdOscH +
                        "," + macdMin9d +
                        "," + macdMax9d +
                        "," + macdOscZ
                }
                exportString += "," + macdOsc + "," + simBalance + "," + moneyMultiple + "," + yy
                if ext! {
                    exportString += "," + dividend
                }
                exportString += "," + pl + "," + cumulCost + "," + r
                if ext! {
                    exportString += "," + cumulDays + "," + simRound + "," + simRule
                }
                exportString += "," + qtyBuy + "," + qtySell + "," + qtyInventory + "," + days + "," + unitCost + "," + unitCostDiff

                exportString += "," + simIncome  +  "," + changeRemark

                exportString += "\n"

            }

        }
        return exportString
    }



    //=====================================================
    //=====================================================
    //******************* downloadPrice *******************
    //=====================================================
    //=====================================================

    func findDividendInThisYear(_ date:Date?=Date()) -> Date? {
        var thisDate:Date=Date()
        var dividendDate:Date?
        if let _ = date {
            thisDate = date!
        }
        let thisYear:Int = twDateTime.calendar.component(.year, from: thisDate)
        for dt in dateDividend.keys {
            let dtYear:Int = twDateTime.calendar.component(.year, from: dt)
            if dtYear == thisYear {
                dividendDate = dt
                break
            }
        }
        return dividendDate
    }










    func downloadPrice(_ mode:String="", source:String) {
        let downloadGroup:DispatchGroup = DispatchGroup()
        var noPriceDownloaded:Bool      = true
        var copyDividends:[Date]?


        func getDividends() {
            //除權息日期
            func cnyesDividend() {
                var urlString:String = ""
                var leading:String = ""
                var trailing:String = ""
                var textString:String = ""

                urlString = "http://www.cnyes.com/twstock/dividend/" + id + ".htm"
                let url = URL(string: urlString );
                let request = URLRequest(url: url!,timeoutInterval: 30)
                downloadGroup.enter()
                let session = URLSession.shared
                let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
                    if error == nil {
                        if self.masterUI?.getStock().isUpdatingPrice == false {
                            self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesDividend canceled.")
                            return
                        }
                        if let downloadedData = String(data: data!, encoding: String.Encoding.utf8) {

                            /* 抓除權息日期    事先要處理  換行\r\n 跳格  括弧\" \'   這幾個特殊碼，還要先把()去掉，因為這是regularExpression的符號
                             <th>盈餘股/千股</th>\r\n                            </tr><tr><td class=\'lt\'>20151026</td><td class=\'rt\'>2</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20141024</td><td class=\'rt\'>1.55</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20131024</td><td class=\'rt\'>1.35</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20121024</td><td class=\'rt\'>1.85</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20111026</td><td class=\'rt\'>1.95</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20101025</td><td class=\'rt\'>2.2</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20091023</td><td class=\'rt\'>1</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20081024</td><td class=\'rt\'>2</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr><tr><td class=\'lt\'>20071024</td><td class=\'rt\'>2.5</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>0</td><td class=\'rt\'>-</td></tr></table>
                             */

                            var tempString:String
                            tempString = downloadedData.replacingOccurrences(of: "(", with: "") //把()去掉，因為這是regularExpression的符號
                            tempString = tempString.replacingOccurrences(of: ")", with: "")
                            leading = "<th>盈餘股/千股</th>\r\n                            </tr>"
                            trailing   = "</tr></table>"    //最後一個</tr>會被換成\n造成多一列空白列，所以不要包含進去textString之內

                            if let findRange = tempString.range(of: leading+"(.*)"+trailing, options: .regularExpression) {
                                let startIndex = tempString.index(findRange.lowerBound, offsetBy: leading.count)
                                let endIndex = tempString.index(findRange.upperBound, offsetBy: 0-trailing.count)
                                textString = String(tempString[startIndex..<endIndex])
                                textString = textString.replacingOccurrences(of: "</tr>", with: "\n")
                                textString = textString.replacingOccurrences(of: ",", with: "")  //去掉千位分號
                                textString = textString.replacingOccurrences(of: "<tr><td class=\'lt\'>", with: "")  //去掉頭冠 <tr><td class='cr'>
                                textString = textString.replacingOccurrences(of: "</td><td class=\'rt\'>", with: ",")    //取代欄分隔
                                textString = textString.replacingOccurrences(of: "</td>", with: "") //去尾 </td>
                                textString = textString.replacingOccurrences(of: "\n\n", with: "\n") //去尾 </td>

                                /* 變成這樣的textString: 交易日、現金股利、股票股利[公積(股/千股)、盈餘(股/千股)]    、現增配股(股/千股)、認購價(元/股)、員工紅利、停止過戶日
                                 20150903,3.8,0,50,0,0,105211021,20150906-20150910
                                 20140828,1.8,0,120,0,0,89255202,20140830-20140903
                                 20130909,1.5,0,100,0,0,109253660,20130911-20130915
                                 20120810,1.5,0,100,0,0,77860198,20120814-20120818
                                 20110729,1,0,100,0,0,61723640,20110802-20110806
                                 20100825,2,0,120,0,0,52844526,20100827-20100831
                                 20090602,1.1,0,150,0,0,52114856,20090604-20090608
                                 20080916,3,0,150,0,0,180242000,20080918-20080922
                                 20070827,3,0,200,0,0,89000000,20070829-20070902
                                 20060817,3,0,200,0,0,70000000,20060820-20060824
                                 20050902,2.4471,0,195.7714,0,0,70000000,20050906-20050910
                                 20040823,1.9999,0,149.9987,0,0,60221299,20040825-20040829
                                 20030807,1.5,0,200,0,0,41298000,20030809-20030813
                                 20020723,1.5,0,150,0,0,30800000,20020725-20020729
                                 20010702,1.5,0,200,0,0,25300000,20010704-20010708
                                 */

                                let lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]

                                for line in lines {
                                    if line != "" {
                                        let col1 = line.components(separatedBy: ",")[0]
                                        if let dt1 = twDateTime.dateFromString(col1, format: "yyyyMMdd") {
                                            if dt1.compare(self.dateStart) != ComparisonResult.orderedAscending {
                                                var amt:Double = 0  //現金股利
                                                let col2 = line.components(separatedBy: ",")[1]
                                                if let amt1 = Double(col2) {
                                                    amt = amt1
                                                }
                                                if let da = self.dateDividend[dt1] {
                                                    if da != amt {
                                                        self.dateDividend[dt1] = amt
                                                        self.masterUI?.masterLog("*\(self.id) \(self.name) \tupdated dividend: \(col1) \(amt)")
                                                    }
                                                } else {
                                                    self.dateDividend[dt1] = amt
                                                    self.masterUI?.masterLog("*\(self.id) \(self.name) \tnew cnyesDividend: \(col1) \(amt)")
                                                }
                                                
                                                
//                                                if !self.dateDividends.contains(dt1) {
//                                                    self.dateDividends.append(dt1)   //只需要起始日之後的除權息日
//                                                    self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesDividend: \(col1)")
//
//                                                }
                                            } else {
                                                break
                                            }
                                        }
                                    }   //if line != ""
                                }   //for line in lines
                            } else {  //if let findRange =
                                self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesDividend no findRange ata.")
                            }
                        } else {  //if let downloadedData
                            self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesDividend no downloadedData.")
                        }
                    } else {
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesDividend error:\n\(String(describing: error))")
                    }//if error == nil
                    downloadGroup.leave()
                })
                task.resume()
            }









            // ===== cnyes.com 除權息日期 =====
            if self.id != "t00" && findDividendInThisYear() == nil {
                copyDividends = dateDividend.keys.map {(($0 as NSDate).copy() as! Date)}
                //如果沒有今年的日期
                cnyesDividend()    //多久之前?
                //抓TWSE的今年除權息日
            }

        }















        //TWSE歷史行情

        func twsePrices() {
//            let twseCsvGroup:DispatchGroup = DispatchGroup()
            let dt = dateRange() //資料庫的起迄日範圍
            dtRangeCopy = dt
            let dtFirst10:Date = twDateTime.back10Days(dt.first)
            let dtfirst90 = twDateTime.startOfMonth(dtFirst10)
            let dtFirst00  = twDateTime.startOfDay(dt.first)
            let dtLast2359 = twDateTime.endOfDay(dt.last)


            func addTwseTasks (dtStart:Date,dtEnd:Date) {
                var dtRun:Date = dtStart
                repeat  {   //列入模擬期間內的待下載年月
                    if dtRun.compare(dtStart) != .orderedAscending && dtRun.compare(dtEnd) != .orderedDescending && dtEnd.compare(twDateTime.endOfDay()) != .orderedDescending {
                        if  dtRun.compare(dtfirst90) == .orderedAscending || (dtRun.compare(dtfirst90) == .orderedSame && self.dateEarlier.compare(dtFirst10) == .orderedAscending) || dtRun.compare(dt.last) == .orderedDescending { //排除已經在資料庫的年月範圍
                            if twseTask[dtRun] == nil {
                                twseTask[dtRun] = 0
                            }
                        }
                    }
                    if let dtNext = twDateTime.calendar.date(byAdding: .month, value: 1, to: dtRun) {
                        dtRun = dtNext
                    } else {
                        dtRun = Date.distantFuture
                    }
                } while dtRun < dtEnd
            }



            var dtStart:Date = twDateTime.startOfMonth(self.dateEarlier)
            var dtEnd:Date = (self.dateEndSwitch ? self.dateEnd : twDateTime.endOfDay())
            if dt.first.compare(dt.last) == .orderedDescending {  //資料庫是空的
                addTwseTasks (dtStart:dtStart,dtEnd:dtEnd)
            } else {
                if self.dateEarlier.compare(dt.last) == .orderedDescending {  //模擬新期間在資料庫期間之後
                    dtStart = twDateTime.startOfMonth(dt.last)
                    addTwseTasks (dtStart:dtStart,dtEnd:dtEnd)
                } else {    //模擬新期間在資料庫的迄之前
                    if self.dateEarlier.compare(dtFirst10) == .orderedAscending {  //甚至在資料庫起之前
                        let first = twDateTime.calendar.date(byAdding: .day, value: -1, to: dt.first)!
                        dtStart = twDateTime.startOfMonth(self.dateEarlier)
                        dtEnd = first
                        addTwseTasks (dtStart:dtStart,dtEnd:dtEnd)
                    }
                    if dtEnd.compare(dt.last) == .orderedDescending {
                        if !twDateTime.isDateInToday(dt.last) {
                            let last = twDateTime.calendar.date(byAdding: .day, value: 1, to: dt.last)!
                            dtStart = twDateTime.startOfMonth(last)
                            addTwseTasks (dtStart:dtStart,dtEnd:dtEnd)
                        }
                    }
                }
            }

            var failCount:Int = 0
            var failDate:Date = Date.distantPast
            var taskDate:[Date:Int] = [:]   //這一輪要處理的年月，剔除已達3次no data或失敗3次不用再嘗試的
            for dt in self.twseTask.keys {
                if (twseTask[dt]! >= 3 || twseTask[dt]! <= -3) && dt.compare(failDate) == .orderedDescending {
                    failDate = dt   //先搜尋最接近現在的失敗日期，此日之前都可放棄不必再試
                }
            }
            if failDate != Date.distantPast {
                self.masterUI?.masterLog("\(self.id) \(self.name) \ttwsePrices failDate=\(failDate)")
            }
            for dt in twseTask.keys {
                if twseTask[dt]! < 3 && twseTask[dt]! > -3 {
                    if dt.compare(failDate) == .orderedAscending && twseTask[dt]! != 0 {
                        if twseTask[dt]! > 0 { //之前有試過而且日期在前，就無須再試
                            twseTask[dt] = 3
                        } else if twseTask[dt]! < 0 {
                            twseTask[dt] = -3
                        }
                    } else {
                        taskDate[dt] = 0
                    }
                }
            }
            let taskCount:Int = taskDate.count

            func twseCsv(_ id:String, date:Date) {
                let start = twDateTime.startOfMonth(date)
                let yyyyMMdd = twDateTime.stringFromDate(start, format: "yyyyMMdd")
                var url:URL?
                var request:URLRequest
                if self.id == "t00" {
                    url = URL(string: "http://www.twse.com.tw/indicesReport/MI_5MINS_HIST?response=csv&date="+yyyyMMdd)
                } else {
                    url = URL(string: "http://www.twse.com.tw/exchangeReport/STOCK_DAY?response=csv&date="+yyyyMMdd+"&stockNo="+id)
                }
                if let _ = url {
                    request = URLRequest(url: url!,timeoutInterval: 30)
                } else {
                    self.masterUI?.masterLog("\(self.id) \(self.name) \ttwsePrices 無效的url")
                    return
                }

                let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                    if error == nil {
                        if self.masterUI?.getStock().isUpdatingPrice == false {
                            self.masterUI?.masterLog("*\(self.id) \(self.name) \ttwseCsv canceled.")
                            return
                        }
                        let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                        if let downloadedData = String(data:data!, encoding:String.Encoding(rawValue: big5)) {

                            /* csv檔案的內容：
                             "104年03月 0050 元大台灣50       各日成交資訊(元,股)"
                             日期,成交股數,成交金額,開盤價,最高價,最低價,收盤價,漲跌價差,成交筆數
                             104/03/02,"6,589,376","461,349,421",70.30,70.55,69.75,70.00,-0.30,"1,449"
                             104/03/03,"5,067,933","353,130,410",70.05,70.10,69.50,69.90,-0.10,"1,071"
                             104/03/04,"6,414,710","448,582,000",69.55,70.05,69.50,69.95,+0.05,"1,053"

                             201608之後變成股票代號和名稱中間沒有空格

                             105年08月 0050元大台灣50      各日成交資訊(元，股)
                             "日期","成交股數","成交金額","開盤價","最高價","最低價","收盤價","漲跌價差","成交筆數"
                             "105/08/01","10,407,371","720,963,537","68.80","69.45","68.80","69.30","+0.75","1,682",

                             */

                            //去掉千分位逗號和雙引號
                            var textString:String = ""
                            var quoteCount:Int=0
                            for e in downloadedData {
                                if e == "\r\n" {
                                    quoteCount = 0
                                } else if e == "\"" {
                                    quoteCount = quoteCount + 1
                                }
                                if e != "," || quoteCount % 2 == 0 {
                                    textString.append(e)
                                }
                            }
                            textString = textString.replacingOccurrences(of: " ", with: "")   //去空白
                            textString = textString.replacingOccurrences(of: "\"", with: "")
                            textString = textString.replacingOccurrences(of: "\r\n", with: "\n")  //去換行

                            let lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]

                            if lines.count > 2 {
                                var uCount:Int = 0
                                var dtTrailing:Date = Date.distantPast
                                for (index, line) in lines.enumerated() {
                                    if line != "" && line.contains(",") && line.first != "日" && index >= 2 {
                                        if let dt1 = twDateTime.dateFromString(line.components(separatedBy: ",")[0]) {
                                            if let dt0 = twDateTime.calendar.date(byAdding: .year, value: 1911, to: dt1) {
                                                let dt1330 = twDateTime.timeAtDate(dt0, hour: 13, minute: 30)

                                                if dt1330.compare(self.dateEarlier) != .orderedAscending && dt1330.compare(dtEnd) != .orderedDescending && start.compare(twDateTime.startOfMonth(dt1330)) == .orderedSame {    //同月才算，因TWSE會回錯資料

                                                    let exDATE = dt1330
                                                    let sub:Int = (id == "t00" ? 2 : 0)

                                                    if let exCLOSE = Double(line.components(separatedBy: ",")[6 - sub]) {
                                                        if exCLOSE > 0 {
                                                            var exOPEN:Double = 0
                                                            var exHIGH:Double = 0
                                                            var exLOW:Double  = 0
                                                            var exVOL:Double  = 0
                                                            if let open = Double(line.components(separatedBy: ",")[3 - sub]) {
                                                                exOPEN = open
                                                            }
                                                            if let high = Double(line.components(separatedBy: ",")[4 - sub]) {
                                                                exHIGH = high
                                                            }
                                                            if let low  = Double(line.components(separatedBy: ",")[5 - sub]) {
                                                                exLOW = low
                                                            }
                                                            if let volume = Double(line.components(separatedBy: ",")[1]) {
                                                                exVOL = (id == "t00" ? 0 : volume)
                                                            }
                                                            let exYEAR = twDateTime.stringFromDate(exDATE,format: "yyyy")
                                                            if exDATE.compare(dtFirst00) == .orderedAscending || exDATE.compare(dtLast2359) == .orderedDescending {
                                                                _ = self.newPrice("TWSE", dateTime: exDATE, year: exYEAR, close: exCLOSE, high: exHIGH, low: exLOW, open: exOPEN, volume: exVOL)
                                                            } else {
                                                                _ = self.updatePrice("TWSE", dateTime: exDATE, year: exYEAR, close: exCLOSE, high: exHIGH, low: exLOW, open: exOPEN, volume: exVOL)
                                                            }
                                                            noPriceDownloaded = false
                                                            uCount += 1
                                                            dtTrailing = exDATE
                                                        }

                                                    }   //if let exCLOSE
                                                }   //if let dt1330.compare
                                            }   //if let dt0
                                        }
                                    }   //if line != ""

                                }   //for
                                if uCount > 0 {
                                    self.twseTask.removeValue(forKey: date)  //成功了就移除待下載
                                    self.masterUI?.masterLog("*\(self.id) \(self.name) \ttwsePrices \(twDateTime.stringFromDate(date)) \(uCount)筆 \(twDateTime.stringFromDate(dtTrailing))")
                                    let taskDone = taskCount - taskDate.count
                                    let progress:Float = 0.5 * Float(taskDone) / Float(taskCount)
                                    let msg:String = "\(self.name) \(twDateTime.stringFromDate(date,format:"yyyy/M")) \(uCount)筆"
                                    self.masterUI?.getStock().setProgress(self.id, progress:progress,message:msg)


                                    for dt in Array(self.twseTask.keys) {    //檢查其後月份，需下載就清零，否則移除
                                        if self.twseTask[dt]! >= 3 && dt.compare(date) == .orderedDescending {
                                            if dt.compare(dtStart) != .orderedAscending && dt.compare(dtEnd) != .orderedDescending {
                                                self.twseTask[dt] = 0
                                            } else {
                                                self.masterUI?.masterLog("\(self.id) \(self.name) \ttwseTask \(twDateTime.stringFromDate(date)) 第\(self.twseTask[dt]!)次 removed!\n")
                                                self.twseTask.removeValue(forKey: dt)
                                            }
                                        }
                                    }
                                } else {
                                    if let fc = self.twseTask[date] {
                                        self.twseTask[date] = fc + 1
                                    }
                                }
                            } else {  //if lines.count > 2
                                if let fc = self.twseTask[date] {
                                    if fc != 0 {    //至少要試一次，之後累計失敗5次就暫時放棄重來
                                        failCount -= 1
                                    }
                                    self.twseTask[date] = fc + 1
                                    self.masterUI?.masterLog("=\(self.id) \(self.name) \ttwsePrices \(twDateTime.stringFromDate(date)) 第\(self.twseTask[date]!)次 no data?")
                                    let taskDone = taskCount - taskDate.count
                                    let progress:Float = 0.5 * Float(taskDone) / Float(taskCount)
                                    let msg:String = "\(self.name) \(twDateTime.stringFromDate(date,format:"yyyy/M")) 0筆"
                                    self.masterUI?.getStock().setProgress(self.id, progress:progress,message:msg)

                                    if self.twseTask[date]! >= 1 {
                                        for dt in Array(self.twseTask.keys) {
                                            if self.twseTask[dt]! >= 3 && dt.compare(date) == .orderedDescending {
                                                self.twseTask[date] = 3
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }   //if let downloadedData
                    } else {  //if error == nil
                        failCount -= 1
                        if let fc = self.twseTask[date] {
                            if self.twseTask[date]! < 0 {
                                self.twseTask[date] = fc - 1
                            } else {
                                self.twseTask[date] = -1
                            }
                        } else {
                             self.twseTask[date] = -1
                        }
                        self.masterUI?.masterLog("=\(self.id) \(self.name) \ttwsePrices \(twDateTime.stringFromDate(date)) 第\(self.twseTask[date]!)次  \nerror:\(String(describing: error))")
                        OperationQueue.main.addOperation {
                            self.masterUI?.messageWithTimer("無法連接TWSE\(failCount)", seconds: 0)
                        }
                    }
                    if failCount <= -5 { //即使年月不同，累計失敗5次就放棄，等下一輪timer
                        taskDate = [:]
                        OperationQueue.main.addOperation {
                            self.masterUI?.messageWithTimer("放棄連接TWSE", seconds: 0)
                        }
                        self.deletePrice()  //月份可能不連續只好砍掉重下
                   } else {
                        taskDate.removeValue(forKey: date)
                    }
//                    let taskDone = taskCount - taskDate.count
//                    let progress:Float = 0.5 * Float(taskDone) / Float(taskCount)
//                    self.masterUI?.getStock().setProgress(self.id, progress:progress)
                    let delayS:Int = (self.twseTask.count % 5 == 0 ? 10 : 0) + 3
                    DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(delayS) , execute: {
                        if let dt = taskDate.keys.first {
                            if self.twseTask[dt]! <= -3 {
                                downloadGroup.leave()       //逾時就放棄，等下一輪timer
                            } else {
                                twseCsv(self.id, date: dt)  //如果還有就接著丟
                            }
                        } else {
                            downloadGroup.leave()           //沒有就回去downloadGroiup.Notify
                        }

                    })

                })
                task.resume()

            }





            //開始逐月下載
            //
            //
            //

            downloadGroup.enter()
            if let dt = taskDate.keys.first {
                twseCsv(self.id, date: dt)    //第1次丟出去跑
            } else {
                downloadGroup.leave()
            }





        }



















        func touchCnyesTask(ymdS:String, ymdE:String) -> Int {
            var cCount:Int = 0
            let dt = self.dateRange()
            if ymdE != twDateTime.stringFromDate(Date()) || ymdS < twDateTime.stringFromDate(dt.last) || dt.last == Date.distantPast {
                if let cTask = self.cnyesTask[ymdE] {
                    cCount = cTask + 1
                } else {
                    cCount = 1
                }
                self.cnyesTask[ymdE] = cCount
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesHtml \(ymdS)~\(ymdE) touched:\(self.cnyesTask[ymdE]!)")
            } else {    //截止日到今天，且起始日於末筆之後，有抓成功過不是空的 -> 那就不累計失敗次數一定要重試
                for k in cnyesTask.keys {
                    if k > twDateTime.stringFromDate(dt.first) {   //k在首筆之後，其後應仍有資料，不要說放棄
                        let c = self.cnyesTask[k]!
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesHtml remove touched:\(k):[\(c)]\n")
                        self.cnyesTask.removeValue(forKey: k)
                        
                    }
                }

            }
            return cCount
        }




        func cnyesPrice() {
            let dt = dateRange() //資料庫的起迄日範圍
            dtRangeCopy = dt
            let dtFirst10:Date = twDateTime.back10Days(dt.first)
            let dtEnd:Date = twDateTime.endOfDay((self.dateEndSwitch ? self.dateEnd : Date()))  //((self.dateEndSwitch ? self.dateEnd : Date()), hour: 23, minute: 59)
            //模擬所需的期間



            var segment:Int = 0
            func cnyesHtml(ymdStart:String,ymdEnd:String) -> Bool {
                if let c = cnyesTask[ymdEnd] {
                    if c >= 3 {
                        self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesTask[\(ymdEnd)] = \(c), cnyesHtml \(ymdStart)~\(ymdEnd) skipped.")
                        return false
                    }
                }
                segment += 1
                let url = URL(string: "http://www.cnyes.com/twstock/ps_historyprice.aspx?code=\(self.id)&ctl00$ContentPlaceHolder1$startText=\(ymdStart)&ctl00$ContentPlaceHolder1$endText=\(ymdEnd)")
                let request = URLRequest(url: url!,timeoutInterval: 30)

                downloadGroup.enter()
                let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                    if error == nil {
                        if self.masterUI?.getStock().isUpdatingPrice == false {
                            self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesPrice canceled.")
                            return
                        }
                        if let downloadedData = String(data:data!, encoding:.utf8) {

                            let leading     = "<tr class=\'thbtm2\'>\r\n    <th>日期</th>\r\n    <th>開盤</th>\r\n    <th>最高</th>\r\n    <th>最低</th>\r\n    <th>收盤</th>\r\n    <th>漲跌</th>\r\n    <th>漲%</th>\r\n    <th>成交量</th>\r\n    <th>成交金額</th>\r\n    <th>本益比</th>\r\n    </tr>\r\n    "
                            let trailing    = "\r\n</table>\r\n</div>\r\n  <!-- tab:end -->\r\n</div>\r\n<!-- bd3:end -->"
                            if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                                let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                                let endIndex = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                                let textString = downloadedData[startIndex..<endIndex].replacingOccurrences(of: "</td></tr>", with: "\n").replacingOccurrences(of: "<tr><td class=\'cr\'>", with: "").replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "</td><td class=\'rt\'>", with: ",").replacingOccurrences(of: "</td><td class=\'rt r\'>", with: ",").replacingOccurrences(of: "</td><td class=\'rt g\'>", with: ",")
                                //日期,開盤,最高,最低,收盤,漲跌,漲%,成交量,交金額,本益比
                                //2017/06/22,217.00,218.00,216.50,218.00,2.50,1.16%,24228,5268473,15.83
                                //2017/06/21,216.00,217.00,214.50,215.50,-1.00,-0.46%,44826,9673307,15.65
                                //2017/06/20,215.00,218.00,214.50,216.50,3.50,1.64%,28684,6208332,15.72
                                var lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]
                                if lines.last == "" {
                                    lines.removeLast()
                                }
                                var exDATE:Date?
                                for (index, line) in lines.enumerated() {
                                    if let dt0 = twDateTime.dateFromString(line.components(separatedBy: ",")[0]) {
                                        let dt1330 = twDateTime.timeAtDate(dt0, hour: 13, minute: 30)

                                        if dt1330.compare(self.dateEarlier) != .orderedAscending && dt1330.compare(dtEnd) != .orderedDescending { //&& (dt1330.compare(last0) != .orderedAscending || dt1330.compare(dt.last) != .orderedDescending) {

                                            exDATE = dt1330

                                            if let exCLOSE = Double(line.components(separatedBy: ",")[4]) {
                                                if exCLOSE > 0 {
                                                    var exOPEN:Double = 0
                                                    var exHIGH:Double = 0
                                                    var exLOW:Double  = 0
                                                    var exVOL:Double  = 0
                                                    if let open = Double(line.components(separatedBy: ",")[1]) {
                                                        exOPEN = open
                                                    }
                                                    if let high = Double(line.components(separatedBy: ",")[2]) {
                                                        exHIGH = high
                                                    }
                                                    if let low  = Double(line.components(separatedBy: ",")[3]) {
                                                        exLOW = low
                                                    }
                                                    if let volume  = Double(line.components(separatedBy: ",")[7]) {
                                                        exVOL = volume
                                                    }
                                                    let exYEAR = twDateTime.stringFromDate(exDATE!,format: "yyyy")
                                                    if exDATE!.compare(twDateTime.startOfDay(dt.first)) == .orderedAscending || exDATE!.compare(twDateTime.endOfDay(dt.last)) == .orderedDescending {
                                                        _ = self.newPrice("CNYES", dateTime: exDATE!, year: exYEAR, close: exCLOSE, high: exHIGH, low: exLOW, open: exOPEN, volume: exVOL)
                                                    } else {
                                                        _ = self.updatePrice("CNYES", dateTime: exDATE!, year: exYEAR, close: exCLOSE, high: exHIGH, low: exLOW, open: exOPEN, volume: exVOL)
                                                    }
                                                    let progress:Float = (segment > 1 ? 0.5 : (Float((index + 1)) / Float(lines.count)) * 0.5)
                                                    self.masterUI?.getStock().setProgress(self.id, progress:progress)
                                                    noPriceDownloaded = false

                                                }
                                            }   //if let exCLOSE
                                        }   //if let dt1330.compare
                                    }   //if let dt0

                                }   //for
                                var needTouch:Bool = false
                                var cnyesTaskStatus = ""
                                if let _ = exDATE {
                                    let f10 = twDateTime.back10Days(exDATE!)
                                    if self.dateEarlier.compare(f10) == .orderedAscending {
                                        needTouch = true
                                    }
                                }
                                if needTouch {
                                    let cCount = touchCnyesTask(ymdS:ymdStart, ymdE:ymdEnd)
                                    if cCount > 0 {
                                        self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesHtml[\(cCount)] \(ymdStart)~\(ymdEnd) but from \(twDateTime.startOfDay(exDATE!)) only.")
                                    }
                                } else if let cCount = self.cnyesTask[ymdEnd] {
                                    if cCount < 3 {
                                        self.cnyesTask.removeValue(forKey: ymdEnd)
                                        cnyesTaskStatus = "cnyesTask[\(cCount)] removed."
                                    }
                                }
                                self.masterUI?.masterLog("*\(self.id) \(self.name) \tcnyesHtml \(ymdStart)~\(ymdEnd): \(lines.count)筆 \(cnyesTaskStatus)")


                            } else {  //if let findRange
                                let cCount = touchCnyesTask(ymdS:ymdStart, ymdE:ymdEnd)
                                if cCount > 0 {
                                    self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesHtml[\(cCount)] \(ymdStart)~\(ymdEnd) findRange no data.")
                                }
                            }
                        } else {  //if let downloadedData
                            let cCount = touchCnyesTask(ymdS:ymdStart, ymdE:ymdEnd)
                            self.masterUI?.masterLog("\(self.id) \(self.name) \tcnyesHtml[\(cCount)] \(ymdStart)~\(ymdEnd) no downloadedData.")
                        }
                    } else {  //if error == nil
//                        let cCount = touchCnyesTask(ymdS:ymdStart, ymdE:ymdEnd)
                        if let cCount = self.cnyesTask[ymdEnd] {
                            self.masterUI?.masterLog("=\(self.id) \(self.name) \tcnyesHtml[\(cCount)] \(ymdStart)~\(ymdEnd)\nerror:\(String(describing: error))")
                        } else {
                            self.masterUI?.masterLog("\(self.id) \(self.name) \(ymdStart)~\(ymdEnd)\nerror:\(String(describing: error))")
                        }
                    }
                    downloadGroup.leave()
                })
                task.resume()

                return true

            }

            func noCnyesYet(ymdE:String) -> Bool {
                var yet:Bool = true
                for k in cnyesTask.keys {
                    if k >= ymdE && cnyesTask[k]! >= 3 {
                        yet = false
                        break
                    }
                }
                return yet
            }
            
            var cnyesHtmlFired:Bool = false
            var ymdS:String = ""
            var ymdE:String = ""
            if dt.first.compare(dt.last) == .orderedDescending {  //資料庫是空的
                ymdS = twDateTime.stringFromDate(self.dateEarlier)
                ymdE = twDateTime.stringFromDate(dtEnd)
                if noCnyesYet(ymdE: ymdE) {
                    cnyesHtmlFired = cnyesHtml(ymdStart: ymdS, ymdEnd: ymdE)
                }
            } else {
                if self.dateEarlier.compare(dt.last) == .orderedDescending {  //模擬新期間在資料庫的起之後
                    ymdS = twDateTime.stringFromDate(twDateTime.startOfDay(dt.last))
                    ymdE = twDateTime.stringFromDate(dtEnd)
                    if noCnyesYet(ymdE: ymdE) {
                        cnyesHtmlFired = cnyesHtml(ymdStart: ymdS, ymdEnd: ymdE)
                    }
                } else {    //模擬新期間在資料庫的迄之前
                    if self.dateEarlier.compare(dtFirst10) == .orderedAscending {  //甚至在資料庫起之前
                        let first = twDateTime.calendar.date(byAdding: .day, value: -1, to: dt.first)
                        ymdS = twDateTime.stringFromDate(self.dateEarlier)
                        ymdE = twDateTime.stringFromDate(first!)
                        if noCnyesYet(ymdE: ymdE) {
                            cnyesHtmlFired = cnyesHtml(ymdStart: ymdS, ymdEnd: ymdE)
                        }
                    }
                    if dtEnd.compare(twDateTime.endOfDay(dt.last)) == .orderedDescending {
                        //未指定截止日時dtEnd就是到今天
                        if dt.last.compare(twDateTime.yesterday()) == .orderedAscending { //前天之前可從昨天起抓
                            let last = twDateTime.calendar.date(byAdding: .day, value: 1, to: dt.last)
                            ymdS = twDateTime.stringFromDate(last!)
                            ymdE = twDateTime.stringFromDate(dtEnd)
                            if noCnyesYet(ymdE: ymdE) {
                                cnyesHtmlFired = cnyesHtml(ymdStart: ymdS, ymdEnd: ymdE)
                            }
                        } else {    //末筆就是昨天，則今天必無免data，為免loop須移除cnyesTask今天重試日（如果有的話）
                            let today = twDateTime.stringFromDate()
                            if let _ = self.cnyesTask[today] {
                                self.cnyesTask.removeValue(forKey: today)
                            }
                        }

                    }
                }
            }
            if !cnyesHtmlFired {
                let dtS = twDateTime.stringFromDate(dt.earlier)
                let dtE = twDateTime.stringFromDate(dt.last)
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tno cnyesHtml:\(dtS)~\(dtE)")
            }


        }























/*
        func googleRealtime() {

            let currentThread = Thread.current
            let mainThread = Thread.main
            if currentThread == mainThread {
                self.masterUI?.masterLog("\(self.id) \(self.name) \t!!!!! googleRealtime in mainThread ??????\n\n\n")
            }

            //假設今天是交易日，則擬得交易起迄時間
            let dt  = dateRange()
            let todayNow = Date()
            let time0900 = twDateTime.time0900(todayNow)
            let time1330 = twDateTime.time1330(todayNow)
            var isNotWorkingDay:Bool = false //true=休市日
            if let notWorking = self.masterUI?.getStock().isTodayOffDay(nil) {
                isNotWorkingDay = notWorking
            }
            if isNotWorkingDay || dt.last.compare(time1330) != .orderedAscending || todayNow.compare(time0900) == .orderedAscending { //休市日,已抓到今天收盤價,未開盤
                if mode == "realtime" {
                    self.masterUI?.getStock().setProgress(self.id,progress: -1)  //只有google不是all，那就不做事跳過
                } else {
                    self.masterUI?.getStock().setProgress(self.id,progress: 1)  //是all，則裝作完成跳過
                }
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tgoogle skipped.")

                return
            }


            var date:Date = Date.distantPast
            var open:Double = 0.0
            var close:Double = 0.0
            var high:Double = 0.0
            var low:Double = 0.0
            var year:String = ""
            var leading:String = ""
            var trailing:String = ""


            let url = URL(string: "http://finance.google.com/finance?&q=TPE%3A"+id)
            let request = URLRequest(url: url!,timeoutInterval: 30)
            let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                if error == nil {
                    if self.masterUI?.getStock().isUpdatingPrice == false {
                        self.masterUI?.masterLog("*\(self.id) \(self.name) \tgoogleRealtime canceled.")
                        return
                    }
                    if let downloadedData = String(data: data!, encoding: String.Encoding.utf8) {

                        /* sample data
                         \n<div id="sharebox-data"\n     itemscope="itemscope"\n     itemtype="http://schema.org/Intangible/FinancialQuote">\n<meta itemprop="name"\n        content="Polaris Taiwan Top 50 Tracker Fund" />\n<meta itemprop="url"\n        content="https://www.google.com/finance?cid=14707346" />\n<meta itemprop="imageUrl"\n        content="https://www.google.com/finance/chart?cht=g&q=TPE:0050&tkr=1&p=1d&enddatetime=2016-04-01T13:30:02Z" />\n<meta itemprop="tickerSymbol"\n        content="0050" />\n<meta itemprop="exchange"\n        content="TPE" />\n<meta itemprop="exchangeTimezone"\n        content="Asia/Taipei" />\n<meta itemprop="price"\n        content="63.90" />\n<meta itemprop="priceChange"\n        content="-0.75" />\n<meta itemprop="priceChangePercent"\n        content="-1.16" />\n<meta itemprop="quoteTime"\n        content="2016-04-01T13:30:02Z" />\n<meta itemprop="dataSource"\n        content="TPE real-time data" />\n<meta itemprop="dataSourceDisclaimerUrl"\n        content="//www.google.com/help/stock_disclaimer.html#realtime" />\n<meta itemprop="priceCurrency"\n        content="TWD" />\n</div>
                         */

                        //取quoteTime -> date\
                        leading = "<meta itemprop=\"quoteTime\"\n        content=\""
                        trailing   = "\" />\n<meta itemprop=\"dataSource\"\n"
                        if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                            let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                            let endIndex = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                            let dt1 = downloadedData[startIndex..<endIndex].replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: "")
                            if let dt0 = twDateTime.dateFromString(dt1, format: "yyyy-MM-dd HH:mm:ss") {
                                //5分鐘給Google準備即時資料上線
                                let time0905 = twDateTime.timeAtDate(todayNow, hour: 9, minute: 5)
                                if (!twDateTime.isDateInToday(dt0)) && todayNow.compare(time0905) == ComparisonResult.orderedDescending {
                                    _ = self.masterUI?.getStock().isTodayOffDay(true)    //不是今天價格，現在又已過今天的開盤時間，那今天就是休市日
                                } else {
                                    _ = self.masterUI?.getStock().isTodayOffDay(false)
                                }

                                date = dt0

                                year = twDateTime.stringFromDate(date,format: "yyyy")


                                //取price -> close
                                leading = "<meta itemprop=\"price\"\n        content=\""
                                trailing   = "\" />\n<meta itemprop=\"priceChange\""
                                if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {

                                    func gNumber(_ gString:String) -> Double {
                                        let gS = gString.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: "")  //去掉千位分號
                                        if let gN = Double(gS) {
                                            return gN
                                        }
                                        return 0
                                    }

                                    let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                                    let endIndex = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                                    close = gNumber(String(downloadedData[startIndex..<endIndex]))

                                    //取Open
                                    /* sample data
                                     <td class="key"\n          data-snapfield="priceOpen">Open\n</td>\n<td class="val">61.80\n</td>\n</tr>\n<tr>\n<td class="key"\n          data-snapfield="vol_and_avg">Vol.\n</td>
                                     */
                                    leading = "<td class=\"key\"\n          data-snapfield=\"open\">Open\n</td>\n<td class=\"val\">"
                                    trailing   = "\n</td>\n</tr>\n<tr>\n<td class=\"key\"\n          data-snapfield=\"vol_and_avg\">Vol.\n</td>"
                                    if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                                        let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                                        let endIndex = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                                        open = gNumber(String(downloadedData[startIndex..<endIndex]))
                                    }

                                    //取range -> low - high

                                    /* sample data
                                     <tr>\n<td class="key"\n          data-snapfield="range">Range\n</td>\n<td class="val">63.60 - 64.35\n</td>\n</tr>\n<tr>\n<td class="key"\n          data-snapfield="range_52week">52 week
                                     */

                                    leading = "<tr>\n<td class=\"key\"\n          data-snapfield=\"range\">Range\n</td>\n<td class=\"val\">"
                                    trailing   = "\n</td>\n</tr>\n<tr>\n<td class=\"key\"\n          data-snapfield=\"range_52week\">"
                                    if let findRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                                        let startIndex = downloadedData.index(findRange.lowerBound, offsetBy: leading.count)
                                        let endIndex   = downloadedData.index(findRange.upperBound, offsetBy: 0-trailing.count)
                                        let priceRange = downloadedData[startIndex..<endIndex]
                                        low  = gNumber(priceRange.components(separatedBy: "-")[0])
                                        high = gNumber(priceRange.components(separatedBy: "-")[1])
                                    }


                                    //各即時數值取得成功，就新增或更新最新股價

                                    if open != Double.nan && open != 0 {
                                        var isNotWorkingDay:Bool = false    //true=休市日
                                        if let notWorking = self.masterUI?.getStock().isTodayOffDay(nil) {
                                            isNotWorkingDay = notWorking
                                        }
                                        if (dt.last.compare(twDateTime.time1330(dt.last)) != .orderedAscending) && twDateTime.startOfDay(dt.last).compare(twDateTime.startOfDay(date)) != .orderedAscending {
                                            self.masterUI?.masterLog("*\(self.id) \(self.name) \tgoogle = \(close),  \t\(twDateTime.stringFromDate(date, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay), no update.")


                                        } else {
                                            self.masterUI?.masterLog("*\(self.id) \(self.name) \tgoogle = \(close),  \t\(twDateTime.stringFromDate(date, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay)")
                                           let last = self.updatePrice("Google", dateTime: date, year: year, close: close, high: high, low: low, open: open)
                                            self.updateMA(price: last)
                                            let _ = self.getPriceLast(last) //等simUnitDiff算好才重設末筆數值
                                            self.saveContext()

                                        }
                                    } else {
                                        self.masterUI?.masterLog("\(self.id) \(self.name) \tgoogle there is no open price:\(open).")

                                    }
                                }   //if let findRange = downloadedData 取close

                            }  //if let dt =
                        } else {  //取quoteTime: if let findRange
                            //google沒有這支股票的資料
                            self.masterUI?.masterLog("\(self.id) \(self.name) \tgoogle no data.")
                        }
                    }  else { //if let downloadedData =
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tgoogle invalid data.")
                    }
                } else {
                    self.masterUI?.masterLog("\(self.id) \(self.name) \ttwse error?\n\(String(describing: error))\n")
                }   //if error == nil
                self.masterUI?.getStock().setProgress(self.id,progress: 1)
            })  //let task =
            task.resume()
        }
*/

        func twseRealtime() {

            //假設今天是交易日，則擬得交易起迄時間
            let dt  = dateRange()
            let todayNow = Date()
            let time0900 = twDateTime.time0900(todayNow)
            let time1330 = twDateTime.time1330(todayNow)
            var isNotWorkingDay:Bool = false //true=休市日
            if let notWorking = self.masterUI?.getStock().isTodayOffDay(nil) {
                isNotWorkingDay = notWorking
            }
            let endDateEarlier:Bool = dateEndSwitch == true && dateEnd.compare(twDateTime.startOfDay()) == .orderedAscending
            if isNotWorkingDay || dt.last.compare(time1330) != .orderedAscending || todayNow.compare(time0900) == .orderedAscending || endDateEarlier { //休市日,已抓到今天收盤價,未開盤
                if mode == "realtime" {
                    self.masterUI?.getStock().setProgress(self.id,progress: -1)  //沒有執行什麼，跳過
                } else {
                    self.masterUI?.getStock().setProgress(self.id,progress: 1)    //裝作all完成
                }
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tmisTwse skipped.")

                return
            }

            enum misTwseError: Error {
                case error(msg:String)
                case warn(msg:String)
            }
            
            var retryFiBest:Int = 0

            func getCookie() {

                //1.先取得cookie
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tmisTwse getting cookie...\(retryFiBest)")
                guard let url = URL(string: "http://mis.twse.com.tw/stock/fibest.jsp?lang=zh_tw") else {return}
                let request = URLRequest(url: url,timeoutInterval: 30)
                URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                    guard error == nil else {
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tmisTwse 1 error?\n\(String(describing: error))\n")
                        self.masterUI?.getStock().setProgress(self.id,progress: 1)
                        return
                    }
                    if self.masterUI?.getStock().isUpdatingPrice == false {
                        self.masterUI?.masterLog("*\(self.id) \(self.name) \ttwseGetCookie 1 canceled.")
                        return
                    }
                    //2.再抓指數過場
                    let now = String(format:"%.f",Date().timeIntervalSince1970 * 1000)
                    let uString = "http://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_t00.tw%7cotc_o00.tw%7ctse_FRMSA.tw&json=1&delay=0&_=\(now)"
                    guard let url = URL(string: uString) else {return}
                    let request = URLRequest(url: url,timeoutInterval: 30)
                    URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                        guard error == nil else {
                            self.masterUI?.masterLog("\(self.id) \(self.name) \tmisTwse 2 error?\n\(String(describing: error))\n")
                            self.masterUI?.getStock().setProgress(self.id,progress: 1)
                            return
                        }
                        if self.masterUI?.getStock().isUpdatingPrice == false {
                            self.masterUI?.masterLog("*\(self.id) \(self.name) \ttwseGetCookie 2 canceled.")
                            return
                        }
                        getFiBest() //3.最後才能抓即時成交價
                    }).resume()
                }).resume()
            }

            func getFiBest() {  //抓即時成交價
                let now = String(format:"%.f",Date().timeIntervalSince1970 * 1000)
                guard let url = URL(string: "http://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=tse_\(self.id).tw&json=1&delay=0&_=\(now)") else {return}
                let request = URLRequest(url: url,timeoutInterval: 30)
                URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                    do {
                        guard let jdata = data else { throw misTwseError.error(msg:"no data") }
                        guard let jroot = try JSONSerialization.jsonObject(with: jdata, options: .allowFragments) as? [String:Any] else {throw misTwseError.error(msg: "invalid jroot") }
//                        print(jroot)

                        guard let rtmessage = jroot["rtmessage"] as? String else {throw misTwseError.error(msg:"no rtmessage") }
                        if self.masterUI?.getStock().isUpdatingPrice == false {
                            self.masterUI?.masterLog("*\(self.id) \(self.name) \ttwseGetFiBest canceled.")
                            return
                        }
                        if rtmessage == "OK" {

                            /*
                             {
                             "msgArray":[
                             {
                             "ts":"0",
                             "tk0":"2330.tw_tse_20170116_B_9999925914",
                             "tk1":"2330.tw_tse_20170116_B_9999925580",
                             "tlong":"1484528728000",                     //目前時間
                             "f":"217_1784_1144_1788_1190_",            //五檔賣量
                             "ex":"tse",
                             "g":"2165_1133_3126_1611_1962_",           //五檔買量
                             "d":"20170116",                            //日期 <<
                             "it":"12",
                             "b":"179.00_178.50_178.00_177.50_177.00_", //五檔賣價
                             "c":"2330",
                             "mt":"549353",
                             "a":"179.50_180.00_180.50_181.00_181.50_", //五檔賣價
                             "n":"台積電",
                             "o":"180.00",  //開盤價    <<
                             "l":"179.00",  //最低成交價 <<
                             "h":"180.50",  //最高成交價 <<
                             "ip":"0",      //1:趨跌,2:趨漲,4:暫緩收盤,5:暫緩開盤
                             "i":"24",
                             "w":"163.50",  //跌停價
                             "v":"6359",    //累積成交量，未含盤後交易
                             "u":"199.50",  //漲停價
                             "t":"09:05:28",//揭示時間 <<
                             "s":"34",      //當盤成交量
                             "pz":"180.00",
                             "tv":"34",
                             "p":"0",
                             "nf":"台灣積體電路製造股份有限公司",
                             "ch":"2330.tw",
                             "z":"179.50",  //最近成交價 <<
                             "y":"181.50",  //昨日成交價 <<
                             "ps":"2459"    //試算參考成交量
                             }
                             ],
                             "userDelay":...
                             ...
                             },
                             "rtcode":"0000"
                             }
                             */

                            guard let msgArray = jroot["msgArray"] as? [[String:Any]] else {throw misTwseError.error(msg:"no msgArray")}
                            guard let stockInfo = msgArray.first else {throw misTwseError.error(msg:"no msgArray.first")}
                            let o = Double(stockInfo["o"] as? String ?? "0") ?? 0   //開盤價
                            guard o != Double.nan && o != 0 else {throw  misTwseError.error(msg:"invalid open price")}
                            let d = stockInfo["d"] as? String ?? ""   //日期 "20170116"
                            let t = stockInfo["t"] as? String ?? ""   //時間 "09:05:28"
                            guard let dateTime = twDateTime.dateFromString(d+t, format: "yyyyMMddHH:mm:ss") else {throw misTwseError.error(msg:"invalid dateTime")}
                            let h = Double(stockInfo["h"] as? String ?? "0") ?? 0    //最高
                            let l = Double(stockInfo["l"] as? String ?? "0") ?? 0    //最低
                            let z = Double(stockInfo["z"] as? String ?? "0") ?? 0    //最新
                            let year = twDateTime.stringFromDate(dateTime, format: "yyyy")
                            let y = Double(stockInfo["y"] as? String ?? "0") ?? 0    //昨日
                            let v = Double(stockInfo["v"] as? String ?? "0") ?? 0    //總量，未含盤後交易

                            var isNotWorkingDay:Bool = false
                            let time0905 = twDateTime.timeAtDate( todayNow, hour: 9, minute: 5)
                            if (!twDateTime.isDateInToday(dateTime)) && todayNow.compare(time0905) == ComparisonResult.orderedDescending {
                                isNotWorkingDay = self.masterUI!.getStock().isTodayOffDay(true)    //不是今天價格，現在又已過今天的開盤時間，那今天就是休市日
                            } else {
                                isNotWorkingDay = self.masterUI!.getStock().isTodayOffDay(false)
                            }
                            let last = self.getPropertyLast()
                            let lastDays:Double = twDateTime.startOfDay(dateTime).timeIntervalSince(twDateTime.startOfDay(dt.last)) / 86400 //下載新價離前筆差幾天？差超過1天就不要管昨日價不符的檢查，例如增減資造成的價格變動
                            let thisDividend = (self.findDividendInThisYear() ?? Date.distantPast)
                            if (dt.last.compare(twDateTime.time1330(dt.last)) != .orderedAscending && twDateTime.startOfDay(dt.last).compare(twDateTime.startOfDay(dateTime)) != .orderedAscending) || (!twDateTime.isDateInToday(dt.last) && last.priceClose != y && !twDateTime.isDateInToday(thisDividend) && lastDays < 2) { //末筆是收盤價且即時價同日期或之後，或昨日價不符
                                self.masterUI?.masterLog("*\(self.id) \(self.name) \tmisTwse = \(z), \(twDateTime.stringFromDate(dateTime, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay), no update.")
                            } else {
                                self.masterUI?.masterLog("*\(self.id) \(self.name) \tmisTwse = \(z), \(twDateTime.stringFromDate(dateTime, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay)")
                                let last = self.updatePrice("twse", dateTime: dateTime, year: year, close: z, high: h, low: l, open: o, volume:v)
                                self.updateMA(price: last)
                                let _  = self.getPriceLast(last)    //等simUnitDiff算好才重設末筆數值
                                self.saveContext()
                            }
                        } else {
                            throw misTwseError.warn(msg:"invalid rtmessage")
                        }
                    } catch misTwseError.error(let msg) {   //error就放棄結束
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tmisTwse: \(msg)")
                    } catch misTwseError.warn(let msg) {    //warn可能只是cookie失敗，重試
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tmisTwse: \(msg)")
                        getCookie()
                        return
                    } catch {
                        retryFiBest += 1
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tmisTwse[\(retryFiBest)]:\n\(error) ")
                        if retryFiBest <= 1 {
                            getCookie()
                            return
                        }
                    }
                    self.masterUI?.getStock().setProgress(self.id,progress: 1)  //最後一定要回報完畢，才會unlockUI
                }).resume()

            }

            guard let url = URL(string: "http://mis.twse.com.tw/stock/fibest.jsp?lang=zh_tw") else {return}
            let storage = HTTPCookieStorage.shared
            if let cookies = storage.cookies(for: url) {
                if let dlTime = self.masterUI?.getStock().timePriceDownloaded {
                    let dlMinutes = dlTime.timeIntervalSinceNow / 60
                    if cookies.count > 0 {
                        if dlMinutes > -7 {
                            getFiBest() //抓即時成交價
                            return
                        } else {
                            for cookie in cookies {
                                storage.deleteCookie(cookie)
                            }
                        }
                    }
                }
            }
            
            getCookie()
            return
                
            


        }


        func yahooRealtime() {

            let currentThread = Thread.current
            let mainThread = Thread.main
            if currentThread == mainThread {
                self.masterUI?.masterLog("!!!!! yahooRealtime in mainThread ??????\n\n\n")
            }

            //假設今天是交易日，則擬得交易起迄時間
            let dt  = dateRange()
            let todayNow = Date()
            let time0900 = twDateTime.time0900(todayNow)
            let time1330 = twDateTime.time1330(todayNow)
            var isNotWorkingDay:Bool = false    //true=休市日
            if let notWorking = self.masterUI?.getStock().isTodayOffDay(nil) {
                isNotWorkingDay = notWorking
            }
            let endDateEarlier:Bool = dateEndSwitch == true && dateEnd.compare(twDateTime.startOfDay()) == .orderedAscending

            if isNotWorkingDay || dt.last.compare(time1330) != .orderedAscending || todayNow.compare(time0900) == .orderedAscending || endDateEarlier { //休市日,已抓到今天收盤價,未開盤
                if mode == "realtime" {
                    self.masterUI?.getStock().setProgress(self.id,progress: -1)  //只有yahoo不是all，那就是什麼也沒有就跳過
                } else {
                    self.masterUI?.getStock().setProgress(self.id,progress: 1)
                }
                self.masterUI?.masterLog("*\(self.id) \(self.name) \tyahoo skipped.")

                return
            }


            var date:Date = Date.distantPast
            var open:Double     = 0.0
            var close:Double    = 0.0
            var high:Double     = 0.0
            var low:Double      = 0.0
            var volume:Double   = 0.0
            var year:String     = ""
            var leading:String  = ""
            var trailing:String = ""

            let url = URL(string: "https://tw.stock.yahoo.com/q/q?s="+id)
            let request = URLRequest(url: url!,timeoutInterval: 30)
            let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
                if error == nil {
                    if self.masterUI?.getStock().isUpdatingPrice == false {
                        self.masterUI?.masterLog("*\(self.id) \(self.name) \tyahooRealtime canceled.")
                        return
                    }
                    let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                    if let downloadedData = String(data:data!, encoding:String.Encoding(rawValue: big5)) {

                        /* sample data
                         <td width=160 align=right><font color=#3333FF class=tt>　資料日期: 106/04/25</font></td>\n\t</tr>\n    </table>\n<table border=0 cellSpacing=0 cellpadding=\"0\" width=\"750\">\n  <tr>\n    <td>\n      <table border=2 width=\"750\">\n        <tr bgcolor=#fff0c1>\n          <th align=center >股票<br>代號</th>\n          <th align=center width=\"55\">時間</th>\n          <th align=center width=\"55\">成交</th>\n\n          <th align=center width=\"55\">買進</th>\n          <th align=center width=\"55\">賣出</th>\n          <th align=center width=\"55\">漲跌</th>\n          <th align=center width=\"55\">張數</th>\n          <th align=center width=\"55\">昨收</th>\n          <th align=center width=\"55\">開盤</th>\n\n          <th align=center width=\"55\">最高</th>\n          <th align=center width=\"55\">最低</th>\n          <th align=center>個股資料</th>\n        </tr>\n        <tr>\n          <td align=center width=105><a\n\t  href=\"/q/bc?s=2330\">2330台積電</a><br><a href=\"/pf/pfsel?stocklist=2330;\"><font size=-1>加到投資組合</font><br></a></td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>13:11</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap><b>191.0</b></td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.5</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>191.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap><font color=#ff0000>△1.0\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>23,282</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>190.5</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>191.0</td>\n                <td align=\"center\" bgcolor=\"#FFFfff\" nowrap>189.5</td>\n          <td align=center width=137 class=\"tt\">
                         */

                        //取日期 -> yDate
                        leading = "<td width=160 align=right><font color=#3333FF class=tt>　資料日期: "
                        trailing = "</font></td>\n\t</tr>\n    </table>\n<table border=0 cellSpacing=0 cellpadding=\"0\" width=\"750\">\n  <tr>\n    <td>\n      <table border=2 width=\"750\">\n        <tr bgcolor=#fff0c1>\n          <th align=center >股票<br>代號</th>"
                        if let yDateRange = downloadedData.range(of: leading+"(.+)"+trailing, options: .regularExpression) {
                            let startIndex = downloadedData.index(yDateRange.lowerBound, offsetBy: leading.count)
                            let endIndex = downloadedData.index(yDateRange.upperBound, offsetBy: 0-trailing.count)
                            let yDate = downloadedData[startIndex..<endIndex]

                            leading = "<td align=\"center\" bgcolor=\"#FFFfff\" nowrap>"
                            trailing = "</td>"
                            let yColumn = matches(for: leading, with: trailing, in: downloadedData)
                            if yColumn.count >= 9 {
                                let yTime = yColumn[0]
                                if let dt1 =  twDateTime.dateFromString(yDate+" "+yTime, format: "yyyy/MM/dd HH:mm") {
                                    if let dt0 = twDateTime.calendar.date(byAdding: .year, value: 1911, to: dt1) {
                                        //5分鐘給Google準備即時資料上線
                                        let time0905 = twDateTime.timeAtDate( todayNow, hour: 9, minute: 5)
                                        if (!twDateTime.isDateInToday(dt0)) && todayNow.compare(time0905) == ComparisonResult.orderedDescending {
                                            _ = self.masterUI?.getStock().isTodayOffDay(true)    //不是今天價格，現在又已過今天的開盤時間，那今天就是休市日
                                        } else {
                                            _ = self.masterUI?.getStock().isTodayOffDay(false)
                                        }

                                        date    = dt0
                                        year = twDateTime.stringFromDate(date, format: "yyyy")

                                        func  yNumber(_ yColumn:String) -> Double {
                                            let yString = yColumn.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "").replacingOccurrences(of: ",", with: "")
                                            if let dNumber = Double(yString) {
                                                return dNumber
                                            }
                                            return 0
                                        }
                                        close = yNumber(yColumn[1])
                                        open  = yNumber(yColumn[6])
                                        high  = yNumber(yColumn[7])
                                        low   = yNumber(yColumn[8])
                                        volume = yNumber(yColumn[5])

                                        if open != Double.nan && open != 0 {

                                            var isNotWorkingDay:Bool = false    //true=休市日
                                            if let notWorking = self.masterUI?.getStock().isTodayOffDay(nil) {
                                                isNotWorkingDay = notWorking
                                            }
                                            if (dt.last.compare(twDateTime.time1330(dt.last)) != .orderedAscending) && twDateTime.startOfDay(dt.last).compare(twDateTime.startOfDay(date)) != .orderedAscending {
                                                self.masterUI?.masterLog("*\(self.id) \(self.name) \tyahoo = \(close),  \t\(twDateTime.stringFromDate(date, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay), no update.")
                                            } else {
                                                self.masterUI?.masterLog("*\(self.id) \(self.name) \tyahoo = \(close),  \t\(twDateTime.stringFromDate(date, format: "yyyy/MM/dd HH:mm:ss")) workingDay=\(!isNotWorkingDay)")
                                                let last = self.updatePrice("yahoo", dateTime: date, year: year, close: close, high: high, low: low, open: open, volume: volume)
                                                self.updateMA(price: last)
                                                let _  = self.getPriceLast(last)    //等simUnitDiff算好才重設末筆數值
                                                self.saveContext()
                                            }
                                        } else {
                                            self.masterUI?.masterLog("\(self.id) \(self.name) \tyahoo there is no open price:\(open).")

                                        }
                                    }
                                }
                            }

                        } else {  //取quoteTime: if let findRange
                            //google沒有這支股票的資料
                            self.masterUI?.masterLog("\(self.id) \(self.name) \tyahoo no data.")
                        }
                    }  else { //if let downloadedData =
                        self.masterUI?.masterLog("\(self.id) \(self.name) \tyahoo invalid data.")
                    }
                } else {
                    self.masterUI?.masterLog("\(self.id) \(self.name) \tyahoo error?\n\(String(describing: error))\n")
                }   //if error == nil
                self.masterUI?.getStock().setProgress(self.id,progress: 1)
            })  //let task =
            task.resume()
        }




        func matches(for leading: String, with trailing: String, in text: String) -> [String] {

            do {
                let regex = try NSRegularExpression(pattern: leading+"(.*)"+trailing)
                let nsString = text as NSString
                let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
                return results.map {nsString.substring(with: $0.range).replacingOccurrences(of: leading, with: "").replacingOccurrences(of: trailing, with: "")}
            } catch let error {
                self.masterUI?.masterLog("\(self.id) \(self.name) \tinvalid regex: \(error.localizedDescription)")

                return []
            }
        }


        func removeLastRealTime() {
            let last = getPropertyLast()
            let realtimeSource:String = self.masterUI!.getStock().realtimeSource
            let wasRealtimeSource:[String] = self.masterUI!.getStock().wasRealtimeSource
            if wasRealtimeSource.contains(last.source) {
                if (!twDateTime.isDateInToday(last.dtLast) && last.dtLast.compare(twDateTime.time1330(last.dtLast)) == .orderedAscending) || last.source != realtimeSource {    //不是今天且1330以前，或不是指定source
                    let dt0 = twDateTime.startOfDay(last.dtLast)
                    let p0 = fetchPrice(dtStart: dt0)
                    for price in p0 {
                        self.getContext().delete(price)
                    }
//                    self.saveContext()
                    resetPriceProperty()
                    self.masterUI?.masterLog("*\(self.id) \(self.name) \tremove realtime since \(twDateTime.stringFromDate(dt0))")
                }
            }

//            //修補可能漏更新的未收盤價格：移除所有的google或yahoo
//            let google:[Price] = fetchPriceUpdatedBy(by: ["Google","Yahoo"], byOthers: false)  //即Google,Yahoo更新的
//
//            if google.count > 0 {
//                let price1 = google.first!
//                let weekday = twDateTime.calendar.component(.weekday, from: price1.dateTime)
//                if !twDateTime.isDateInToday(price1.dateTime) {
//                    let dt0 = twDateTime.startOfDay(price1.dateTime)
//                    let p0 = fetchPrice(dtStart: dt0)
//                    for price in p0 {
//                        self.getContext().delete(price)
//                    }
//                    self.saveContext()
//                    resetPriceProperty()
//                    self.masterUI?.masterLog("*\(self.id) \(self.name) \tremove google since \(twDateTime.stringFromDate(dt0))")
//                }
//            }

        }





        //==================== getPrice 主程式從這兒開始 ====================
        self.masterUI?.getStock().setProgress(self.id,progress: 0)
        self.masterUI?.masterLog("*\(id) \(name) \tmode=\(mode) source=\(source) ...")
        
        var downloadMode:String = mode
        var modePriority:Int = (self.masterUI?.getStock().modePriority[downloadMode] ?? 1)
        let dt = self.dateRange()
        if !twDateTime.isDateInToday(dt.last) && dt.last.compare(twDateTime.time1330(dt.last)) == .orderedAscending && modePriority < 4 {  //小於all時應升級為all
            downloadMode = "all"
            modePriority = (self.masterUI!.getStock().modePriority[downloadMode] ?? 3)
        }
        
        switch downloadMode {  //mode: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
        case "reset":
            getDividends()  //除權息日期
            deletePrice("reset")
            willGiveMoney = true
            willUpdateAllSim = true
        case "realtime":
            if !willUpdateAllSim {
                masterUI?.globalQueue().addOperation() {
                    if self.id == "t00" {
                        twseRealtime()
                    } else {
                        let realtimeSource = self.masterUI!.getStock().realtimeSource
                        if realtimeSource == "twse" {
                            twseRealtime()
                        } else if realtimeSource == "yahoo" {
                            yahooRealtime()
                        }
                    }
                }
                return
            }
        case "simOnly","retry":
            if needToRetry(source) {
                //起迄期間變動需要下載股價，所以應該重設自動加碼等
                willResetMoney = true
                willGiveMoney  = true
                willUpdateAllSim = true
                maxMoneyMultiple = 0
            } else {
                if !willUpdateAllSim {  //是simOnly但是這個simPrice不用處理，跳過。
                    masterUI?.getStock().setProgress(id, progress: -1)
                    return
                }
            }
        default:    //mode == "all" or "maALL"
            getDividends()  //除權息日期

        }

        downloadGroup.enter()
        DispatchQueue.global().async {
            //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
            if modePriority > 3 {
                removeLastRealTime()  //移除日前最後一筆收盤前的Google或Yahoo
                if source == "twse" || self.id == "t00" {
                    twsePrices()    //開始從TWSE下載
                } else {
                    cnyesPrice()
                }
            } else if downloadMode == "simOnly" {
                //只是要updateAllSim就不用抓價格，但是要執行notify那一段
                if self.willUpdateAllSim {
                    self.masterUI?.masterLog("\(self.id) \(self.name) \tsimOnly...(不用下載)")
                }
            }
            downloadGroup.leave()

        }   // NSOperationQueue().addOperationWithBlock() {
        
        downloadGroup.notify(queue: DispatchQueue.global() , execute: {
            self.masterUI?.globalQueue().addOperation() {
                let Prices:[Price] = self.fetchPrice()  //只抓模擬期間，不是all
                if Prices.count > 0 {

                    if source == "cnyes" {
                        //雖然網頁有筆數但是不足所需時，應補所需

                        let first10 = twDateTime.back10Days(Prices.first!.dateTime)
                        if self.dateEarlier.compare(first10) == .orderedAscending {
                            if let first1 = twDateTime.calendar.date(byAdding: .day, value: -1, to: Prices.first!.dateTime) {
                                let dtE = twDateTime.stringFromDate(first1)
                                if self.cnyesTask[dtE] == nil {
                                    let dtS = twDateTime.stringFromDate(self.dateEarlier)
                                    let _ = touchCnyesTask(ymdS: dtS, ymdE: dtE)
                                    self.masterUI?.masterLog ("\(self.id) \(self.name) \tcnyesTask補touch:\(dtS)-\(dtE)\n")
                                }
                            }
                        }

                        if self.dateStart.compare(Prices.first!.dateTime) == .orderedDescending && Prices.first!.simBalance != -1  && self.willUpdateAllSim == false {
                            self.willResetMoney = true
                            self.willGiveMoney  = true
                            self.willUpdateAllSim = true
                            self.maxMoneyMultiple = 0
                            let dtS = twDateTime.stringFromDate(self.dateStart)
                            let dtF = twDateTime.stringFromDate(Prices.first!.dateTime)
                            self.masterUI?.masterLog ("\(self.id) \(self.name) \twillUpdateAllSim, S:\(dtS) F:\(dtF)\n")
                        }
                    }
                }


                //檢查除息日是否有變動？
                if let cDs = copyDividends {
                    var eq:Bool = true
                    for dt in self.dateDividend.keys {
                        if dt.compare(self.dateStart) != ComparisonResult.orderedAscending && (self.dateEndSwitch == false || dt.compare(self.dateEnd) != ComparisonResult.orderedDescending) {
                            if !cDs.contains(where: {$0.compare(dt) == ComparisonResult.orderedSame}) {
                                eq = false
                                break
                            }
                        }
                    }
                    if eq == false {
                        self.willUpdateAllSim = true    //除息日有變動時，需要重算模擬
                    }
                }

                let priceCompleted = !self.needToRetry(source)
                if noPriceDownloaded && !self.willUpdateAllSim {
                    self.masterUI?.masterLog("*\(self.id) \(self.name) \tno update for MA.")
                } else {
                    self.resetPriceProperty()
                    if priceCompleted || source == "cnyes" {    //cnyes只能重試，不能知道單次下載之中有沒有不足筆數
                        self.updateAllSim(downloadMode, fetchedPrices: Prices)
                    } else {
                        self.willUpdateAllSim = true
                        self.saveContext()  //未完重試前，先儲存並保存twseTasks未完月份
                        let defaults:UserDefaults = UserDefaults.standard
                        defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.masterUI!.getStock().simPrices) , forKey: "simPrices")
                    }
                }

                if priceCompleted  {

                    if self.id == "t00" {
                        twseRealtime()
                    } else {
                        let realtimeSource = self.masterUI!.getStock().realtimeSource
                        if realtimeSource == "twse" {
                            twseRealtime()
                        } else if realtimeSource == "yahoo" {
                            yahooRealtime()
                        }
                    }

                } else {
                    var waitingList:Any
                    if source == "twse" {   //只有非realtime才能執行到這裡，所以是指mainSource
                        waitingList = String(describing: self.twseTask).replacingOccurrences(of: ",", with: ",\n ")
                    } else {
                        waitingList = String(describing: self.cnyesTask).replacingOccurrences(of: ")", with: ")\n ")
                    }
                    self.masterUI?.masterLog ("\(self.id) \(self.name) \tneed retry, \(source):\n \(waitingList)\n")
                    self.masterUI?.getStock().setupPriceTimer("", mode:"retry", delay: 30)   //先排Timer....
                    self.masterUI?.getStock().setProgress(self.id, progress: -1)             //才能在progress完成時知道未完
                }

            }   //addOperation()
        })      //downloadGroup.notify
    }           //downloadPrice()

    func needToRetry(_ source:String) -> Bool {
        if self.masterUI!.getStock().simTesting {
            return false
        }
        var retry:Bool = false
        if source == "cnyes" {
            for ymdE in Array(self.cnyesTask.keys) {
                if self.cnyesTask[ymdE]! < 3 {
                    let dt = self.dateRange()
                    var ymdE10:Date = Date.distantPast
                    if let d1 = twDateTime.dateFromString(ymdE) {
                        ymdE10 = twDateTime.back10Days(d1)
                    } else if let d2 = twDateTime.dateFromString(ymdE, format: "yyyymmdd") {
                        ymdE10 = twDateTime.back10Days(d2)
                    }
                    if ymdE10.compare(dateEarlier) != .orderedDescending || (ymdE > twDateTime.stringFromDate(dt.earlier) && ymdE <= twDateTime.stringFromDate(dt.last)) {
                        //移除無效不必重試的截止日：比預起日還早或已在資料庫起迄日之間
                        self.cnyesTask.removeValue(forKey: ymdE)
                        self.masterUI?.masterLog ("\(self.id) \(self.name) \tremove cnyesTask:\n \(ymdE)\n")
                    } else if ymdE >= twDateTime.stringFromDate(dateEarlier) || (dateEndSwitch == true && ymdE <= twDateTime.stringFromDate(dateEnd)) || (dateEndSwitch == false && ymdE > twDateTime.stringFromDate(dt.last)) {
                        retry = true
                        break
                    }
                }
            }
        } else if source == "twse" {
            if self.twseTask.count > 0 {
                let dt = dateRange()
                for date in Array(self.twseTask.keys) {
                    if  self.twseTask[date]! > 0 && dt.first.compare(date) == .orderedAscending && dt.last.compare(date) == .orderedDescending {
                        self.twseTask[date] = 0     //前後有資料，表示中間一定有，堅持要下到
                    }
                    if self.twseTask[date]! < 3 && self.twseTask[date]! > -3 {
                        retry = true
                        break
                    }
                }
            }
        }
        return retry
    }




    var dateReversed:Date?
    func setReverse(date:Date, action:String?="") -> String {
        let Prices = fetchPrice(dtStart: date)
        if Prices.count > 0 {
            let price:Price = Prices.first!
            if price.simReverse != "" && price.simReverse != action {
                let oldAction = price.simReverse
                if action == "無" || price.simReverse != "無" {  //強制復原
                    price.simReverse = "無"
                    if dateEndSwitch == false || dateEnd.compare(price.dateTime) != ComparisonResult.orderedAscending {
                        price.simReverse = "無"
                    } else {
                        price.simReverse = ""
                    }
                } else { //正常的反轉
                    if price.qtyBuy > 0 && price.simDays == 1 && (action == "" || action == "不買") {
                        price.simReverse = "不買"
                    } else if price.qtySell > 0 && (action == "" || action == "不賣") {
                        price.simReverse = "不賣"
                    } else if price.qtyInventory > 0 && (action == "" || action == "賣") {
                        price.simReverse = "賣"
                    } else if price.qtyInventory == 0 && (action == "" || action == "買") {
                        price.simReverse = "買"
                    } else {
                        price.simReverse = "無"
                    }
                }
                let newAction = price.simReverse
                for p in Prices[1...] {   //該日期之後若有反轉者清除復原之
                    if p.simReverse != "無" && p.simReverse != "" {
                        if dateEndSwitch == false || dateEnd.compare(p.dateTime) != ComparisonResult.orderedAscending {
                            p.simReverse = "無"
                        } else {
                            p.simReverse = ""
                        }
                    }
                }
                saveContext()
                willUpdateAllSim = true
                self.dateReversed = date    //稍候simUpdate於這個日期之後才重設兩次加碼
                self.masterUI?.masterLog("\(id) \(name) \treversed: \(oldAction) --> \(newAction)")

                return newAction
            } else {
                return price.simReverse
            }
        }
        return ""
    }









































    func newPrice(_ source:String, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> Price {

        let context = getContext()
        let price:Price = NSEntityDescription.insertNewObject(forEntityName: "Price", into: context) as! Price
        price.id           = id
        price.updatedBy    = source            //2
        price.dateTime     = dateTime          //3
        price.year         = year              //4
        price.priceClose   = close             //5
        price.priceHigh    = high              //6
        price.priceLow     = low               //7
        price.priceOpen    = open              //8
        price.priceVolume  = volume
        price.simUpdated   = false
        price.simRule      = ""
        price.simRuleBuy   = ""
        price.ma60Rank     = ""
        price.moneyRemark  = ""
        price.priceUpward  = ""     //String不可沒有初始值
        price.simReverse   = ""
//        saveContext()

        return price

    }


    func updatePrice(_ source:String, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> Price {

        let dateS = twDateTime.startOfDay(dateTime)
        let dateE = twDateTime.endOfDay(dateTime)
        let Prices = fetchPrice(dtStart: dateS, dtEnd: dateE)
        if Prices.count > 0 {
            if dateS.compare(twDateTime.startOfDay(Prices.last!.dateTime)) == .orderedSame {

                let price = Prices.last!
                price.id           = id
                price.updatedBy    = source            //2
                price.dateTime     = dateTime          //3
                price.year         = year              //4
                price.priceClose   = close             //5
                price.priceHigh    = high              //6
                price.priceLow     = low               //7
                price.priceOpen    = open              //8
                price.priceVolume  = volume
                price.simUpdated   = false
//                saveContext()
                return price
            } else {
                return newPrice(source,dateTime:dateTime,year:year,close:close,high:high,low:low,open:open,volume:volume)
            }
        } else {
            return newPrice(source,dateTime:dateTime,year:year,close:close,high:high,low:low,open:open,volume:volume)
        }
    }









































    func updateAllSim(_ mode:String="all", fetchedPrices:[Price]?=nil) {
        let dt = dateRange()
        var dtS:Date = dt.earlier
        var dtE:Date = dt.last
        if let _ = dtRangeCopy {
            if dt.first.compare(dtRangeCopy!.first) == .orderedAscending {
                dtS = dt.first
            }
            if dt.last.compare(dtRangeCopy!.last) == .orderedDescending {
                dtE = dt.last
            }
        }




        var Prices:[Price] = []
        if let _ = fetchedPrices {
            Prices = fetchedPrices!
        } else {
            Prices = fetchPrice(dtStart: dtS, dtEnd: dtE)
        }

        // update all MA && Sim
        //modePriority: 1.none, 2.realtime, 3.simOnly, 4.all, 5.maALL, 6.retry, 7.reset
        let modePriority:[String:Int] = self.masterUI!.getStock().modePriority
        if Prices.count > 0 {
            if willUpdateAllSim {   //在updateSim時會根據實際資料更新加碼次數和是否有反轉
                maxMoneyMultiple = 0
                simReversed = false
            }
            for (index, price) in Prices.enumerated() { //mode=retry時，可能中間有斷層要重算ma
                if modePriority[mode]! >= 5 || price.simUpdated == false || willUpdateAllMa {
                    updateMA(index:index, price:price, Prices:Prices)
                    updateSim(index:index, price:price, Prices:Prices)
                } else if willUpdateAllSim {
                    updateSim(index:index, price:price, Prices:Prices)
                }
                if index % 20 == 0 {
                    let downloadProgress = (1+(Float(index)/Float(Prices.count))) / 2.03
                    masterUI?.getStock().setProgress(id, progress:downloadProgress)
                }
            }
            saveContext()
            self.masterUI?.masterLog("*\(self.id) \(self.name) \trunAllMA rTotal=\(Prices.count)  ALL=\(willUpdateAllSim) \(twDateTime.stringFromDate(Prices.first!.dateTime))~\(twDateTime.stringFromDate(Prices.last!.dateTime))")
            if let _ = Prices.last {
                let _ = getPriceLast(Prices.last)
            }
        } else {
            self.masterUI?.masterLog("\(self.id) \(self.name) \trunAllMA fetched no count.")

        }
        willUpdateAllSim = false
        willUpdateAllMa  = false
        willResetMoney   = false
        willResetReverse = false
        willGiveMoney    = true //此前或有執行變更加碼按鈕，更新模擬完畢即應恢復自動2次加碼
        dateReversed     = nil

    }


























    func resetSimUpdated() {
        //重算統計數值
//        let Prices = fetchPrice("all")
//        for price in Prices {
//            price.simUpdated = false
//        }
//        saveContext()
        self.willUpdateAllMa = true
        self.resetSimStatus()
        self.masterUI?.masterLog("*\(self.id) \(self.name) \tresetSimUpdated.")
//        self.masterUI?.masterLog("*\(self.id) \(self.name) \tresetSimUpdated:\(Prices.count)筆")
    }



    //*****************************
    //========== 統計數值 ==========
    //*****************************

    func priceIndex(_ count:Double, currentIndex:Int) ->  (lastIndex:Int,lastCount:Double,thisIndex:Int,thisCount:Double) {
        let cnt:Double = (count < 1 ? 1 : round(count)) //count最小是1
        var lastIndex:Int = 0       //前第幾筆的Index不包含自己
        var lastCount:Double = 0    //前第幾筆的總筆數不包含自己
        var thisIndex:Int = 0       //前第幾筆的Index有包含自己
        var thisCount:Double = 0    //前第幾筆的總筆數有包含自己
        if currentIndex >= Int(cnt) {
            lastCount = cnt //前1天那筆開始算往前有幾筆用來平均ma60，含前1天自己
            lastIndex = currentIndex - Int(cnt)   //是自第幾筆起算
            thisCount = cnt
            thisIndex = lastIndex + 1
        } else {
            lastCount = Double(currentIndex)
            thisCount = lastCount + 1
            thisIndex = 0
            lastIndex = 0
        }
        return (lastIndex,lastCount,thisIndex,thisCount)
    }
    

    func updateMA(price:Price) {    //此型專用於盤中即時股價更新時的重算，故必然是只更新最後一筆
        
        let Prices:[Price] = fetchPrice(dtEnd: price.dateTime, fetchLimit: (376), asc:false).reversed()
        //往前抓375筆再加自己共376筆是為1年半，price是Prices的最後一筆。。。先asc:false往前抓，reversed再順排序
        if Prices.count > 0 {
            if price.dateTime.compare(Prices.last!.dateTime) == .orderedSame {
                self.willGiveMoney = true   //盤中即時模擬應繼續執行自動2次加碼
                let index = Prices.count - 1
                updateMA(index:index, price:price, Prices:Prices)
                updateSim(index:index, price:price, Prices:Prices)
            }
        }
    }


    func updateMA(index:Int, price:Price, Prices:[Price]) {
        var lastIndex:Int = 0
        //往前9天、20天、60天的有效index和筆數
        let d9  = priceIndex(9, currentIndex:index)
        let d20 = priceIndex(20, currentIndex:index)
        let d60 = priceIndex(60, currentIndex:index)
        //k,d,j和macd的20/80分布之統計期間，250天約是1年，375是1年半
        let d125 = priceIndex(125, currentIndex: index)
        let d250 = priceIndex(250, currentIndex: index)
        let d375 = priceIndex(375, currentIndex: index)
        
        
        if price.year.count > 4 {
            price.year = twDateTime.stringFromDate(price.dateTime, format: "yyyy")
            if price.year.count > 4 {
                masterUI?.masterLog("=\(self.id) \(self.name) \t\(price.dateTime) 年度錯誤 \(price.year)")
            }
        }
        
        let demandIndex:Double = (price.priceHigh + price.priceLow + (price.priceClose * 2)) / 4    //算macd用的

        if index > 0 {   //除了自己還有之前1天的
            lastIndex = index - 1
            let lastPrice = Prices[lastIndex]
            //ma60, ma20
            var sum60:Double = 0
            var sum20:Double = 0
            //9天最高價最低價  <-- 要先提供9天高低價計算RSV，然後才能算K,D,J
            var max9High:Double = minDouble
            var min9Low:Double = maxDouble
            //ma60Rank
            //                price.ma60Diff = 0
            price.ma60Sum  = 0
            for (i,p) in Prices[d60.thisIndex...index].enumerated() {
                sum60 += p.priceClose
                if i + d60.thisIndex >= d20.thisIndex {
                    sum20 += p.priceClose
                }
                if i + d60.thisIndex >= d9.thisIndex {
                    if max9High < p.priceHigh {
                        max9High = p.priceHigh
                    }
                    if min9Low > p.priceLow {
                        min9Low = p.priceLow
                    }
                }
                price.ma60Sum = price.ma60Sum + p.ma60Diff  //但是自己的ma60Diff還是0
            }
            //ma60,ma20
            price.ma60 = sum60 / d60.thisCount
            //((lastPrice.ma60 * lastCount60) - (lastIndex60 >= 0 ? Prices[lastIndex60].priceClose : 0) + price.priceClose) / thisCount60
            price.ma20 = sum20 / d20.thisCount
            //((lastPrice.ma20 * lastCount20) - (lastIndex20 >= 0 ? Prices[lastIndex20].priceClose : 0) + price.priceClose) / thisCount20

            price.ma60Diff    = round(10000 * (price.priceClose - price.ma60) / price.priceClose) / 100
            price.ma20Diff    = round(10000 * (price.priceClose - price.ma20) / price.priceClose) / 100
            price.maDiff      = round(10000 * (price.ma20 - price.ma60) / price.priceClose) / 100

            //ma60Rank是看近60天內（這季）一直漲還是一直跌
            price.ma60Sum = price.ma60Sum + price.ma60Diff  //補上剛才還沒有的自己的ma60Diff
            //lastPrice.ma60Sum - (lastIndex60 >= 0 ? Prices[lastIndex60].ma60Diff : 0) + price.ma60Diff
            price.ma60Avg = price.ma60Sum / d60.thisCount
            if price.ma60Avg > 7 {          //A: 7 ~
                price.ma60Rank = "A"
            } else if price.ma60Avg > 5 {   //B: 5 ~ 7
                price.ma60Rank = "B"
            } else if price.ma60Avg > 2 {   //C+: 2 ~ 5
                price.ma60Rank = "C+"
            } else if price.ma60Avg > -2 {  //C: -2 ~ 2
                price.ma60Rank = "C"
            } else if price.ma60Avg > -5 {  //C-: -5 ~ -2
                price.ma60Rank = "C-"
            } else if price.ma60Avg > -7 {  //D:  -7 ~ -5
                price.ma60Rank = "D"
            } else {                        //E: ~ -7
                price.ma60Rank = "E"
            }
            

            //MACD
            let doubleDI:Double = 2 * demandIndex
            price.macdEma12 = ((11 * lastPrice.macdEma12) + doubleDI) / 13
            price.macdEma26 = ((25 * lastPrice.macdEma26) + doubleDI) / 27
            let dif:Double = price.macdEma12 - price.macdEma26
            let doubleDif:Double = 2 * dif
            price.macd9 = ((8 * lastPrice.macd9) + doubleDif) / 10
            price.macdOsc = dif - price.macd9

            //9天最高價最低價  <-- 要先提供9天高低價計算RSV，然後才能算K,D,J
            if max9High == min9Low {
                price.kdRSV = 50
            } else {
                price.kdRSV = 100 * (price.priceClose - min9Low) / (max9High - min9Low)
            }

            //k, d, j, kGrow, kGrowRate, priceUp, lowDiff
            price.kdK = ((2 * lastPrice.kdK / 3) + (price.kdRSV / 3))   //round(100 * ((2 * k0 / 3) + (rsv / 3))) / 100
            price.kdD = ((2 * lastPrice.kdD / 3) + (price.kdK / 3))     //round(100 * ((2 * d0 / 3) + (k / 3))) / 100
            price.kdJ = ((3 * price.kdK) - (2 * price.kdD))             //round(100 * ((3 * k) - (2 * d))) / 100
            
            var dividendAmt:Double = 0
            if let dtD = self.findDividendInThisYear(price.dateTime as Date) {
                price.dividend = round(Float(twDateTime.startOfDay(price.dateTime).timeIntervalSince(twDateTime.startOfDay(dtD))) / 86400)
                if price.dividend == 0 {
                    dividendAmt = self.dateDividend[dtD]!
                }
            } else {
                price.dividend = -999
            }


            if (price.priceClose + dividendAmt) > lastPrice.priceClose {
                if (price.priceHigh + dividendAmt) == max9High {
                    price.priceUpward = "▲"
                } else {
                    price.priceUpward = "▵"
                }
            } else if (price.priceClose + dividendAmt) < lastPrice.priceClose {
                if (price.priceLow + dividendAmt) == min9Low {
                    price.priceUpward = "▼"
                } else {
                    price.priceUpward = "▿"
                }
            } else {
                price.priceUpward = ""
            }
            price.kGrow = price.kdK - lastPrice.kdK
            if lastPrice.kGrow != 0 {
                price.kGrowRate = round(10000 * price.kGrow / lastPrice.kGrow) / 100
            } else {
                price.kGrowRate = 0
            }
            price.priceLowDiff = 100 * (lastPrice.priceClose - price.priceLow) / lastPrice.priceClose

            //9天最高K最低K、最大ma差最小ma差、最大macd最小macd
            price.kMaxIn5d = minDouble
            price.kMinIn5d = maxDouble
            price.maMax9d   = -9999
            price.ma20Max9d = -9999
            price.ma60Max9d = -9999
            price.macdMax9d = -9999
            price.maMin9d   = maxDouble
            price.ma20Min9d = maxDouble
            price.ma60Min9d = maxDouble
            price.macdMin9d = maxDouble
            //60天最高價最低價
            price.price60High = minDouble
            price.price60Low  = maxDouble
            //250天K分布
            var kRank:[Int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] //index=0~20共21格
            var kRankSum: Int = 0
            //250天osc分布 index=0~38共39格, i0=-9, i8=-1, i9=-0.5, i18=-0.05, i19=0, i20=0.05, i29=0.5, i30=1, i38=9
            var oscRank:[Int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            var oscRankSumH: Int = 0
            var oscRankSumL: Int = 0
            //i0=-50, i1=-40, i2=-30, i3=-25, i6=-10, i7=-9, ..., i16=0, i17=1, ..., i32=50
            var ma60DiffRank:[Int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            var ma20DiffRank:[Int] = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            var ma60DiffRankSum:Int = 0
            var ma20DiffRankSum:Int = 0
            //250天osc分布 MACD Rank Index
            func oscIndex(macdOsc:Double) -> Int {
                var index:Int = 19 //就是0的位置
                let osc:Double = abs(macdOsc)
                if osc > 0.5 {
                    index = Int(floor(osc) <= 9 ? (9 - floor(osc)) : 0)
                } else if osc > 0 {
                    index = Int(19 - floor(osc * 20))
                }
                if macdOsc > 0 {
                    index = 38 - index
                }
                return index
            }
            //250天osc分布 MACD Rank Value
            func oscValue(index:Int) -> Double {
                var value:Double = 0
                if index >= 30 {
                    value = Double(index - 29)
                } else if index >= 20 {
                    value = Double(index - 19) / 20
                } else if index == 19 {
                    value = 0
                } else if index >= 9 {
                    value = Double(index - 19) / 20
                } else if index < 9 {
                    value = Double(index - 9)
                }
                return value
            }
            //250天ma20Diff,ma60Diff分布index,value
            func maDiffIndex(diff:Double) -> Int {
                var index:Int = 16
                var ma60Diff:Double = round(diff)
                if abs(ma60Diff) > 10 {
                    var r:Double = 1
                    var c:Int = 0
                    ma60Diff = round(ma60Diff / 10)
                    if ma60Diff < -30 {
                        r = 10
                        c = 5
                    } else if ma60Diff < -10 {
                        r = 5
                        c = 8
                    } else if ma60Diff > 10 {
                        r = 5
                        c = 24
                    } else if ma60Diff > 30 {
                        r = 10
                        c = 27
                    }
                    index = c + Int(round(ma60Diff / r))
                } else {
                    index = 16 + Int(round(ma60Diff))
                }
                if index < 0 {  //diff超過─50,50的時候
                    index = 0
                } else if index > 32 {
                    index = 32
                }
                return index
            }

            func maDiffValue(index:Int) -> Double {
                var value:Double = 0
                if index <= 1 {
                    value = Double(10 * (index - 5))
                } else if index <= 5 {
                    value = Double(5 * (index - 8))
                } else if index >= 30 {
                    value = Double(10 * (index - 27))
                } else if index >= 27 {
                    value = Double(5 * (index - 24))
                } else {
                    value = Double(index - 16)
                }
                return value
            }




            var price60High:Double  = minDouble
            var price60Low:Double   = maxDouble
            var price250High:Double = minDouble
            var price250Low:Double  = maxDouble
            for (i,p) in Prices[d250.thisIndex...index].enumerated() {   //250天的範圍內
                //250天最高價最低價
                    if p.priceHigh > price250High {
                        price250High = p.priceHigh
                    }
                    if p.priceLow < price250Low {
                        price250Low = p.priceLow
                    }
                //60天最高價最低價
                if i + d250.thisIndex >= d60.thisIndex {
                    if p.priceHigh > price60High {
                        price60High = p.priceHigh
                    }
                    if p.priceLow < price60Low {
                        price60Low = p.priceLow
                    }
                }
                //9天最大ma差最小ma差、最大macd最小macd
                if i + d250.thisIndex >= d9.thisIndex {
                    if price.kMinIn5d > p.kdK {
                        price.kMinIn5d = p.kdK
                    }
                    if price.kMaxIn5d < p.kdK {
                        price.kMaxIn5d = p.kdK
                    }
                    if price.ma20Max9d < p.ma20Diff {
                        price.ma20Max9d = p.ma20Diff
                    }
                    if price.ma60Max9d < p.ma60Diff {
                        price.ma60Max9d = p.ma60Diff
                    }
                    if price.maMax9d < p.maDiff {
                        price.maMax9d = p.maDiff
                    }
                    if price.macdMax9d < p.macdOsc {
                        price.macdMax9d = p.macdOsc
                    }
                    if price.maMin9d > p.maDiff {
                        price.maMin9d = p.maDiff
                    }
                    if price.ma20Min9d > p.ma20Diff {
                        price.ma20Min9d = p.ma20Diff
                    }
                    if price.ma60Min9d > p.ma60Diff {
                        price.ma60Min9d = p.ma60Diff
                    }
                    if price.macdMin9d > p.macdOsc {
                        price.macdMin9d = p.macdOsc
                    }
                }

                //250天K分布
                let pKIndex:Int = Int(round(p.kdK/5))
                kRank[pKIndex] += 1
                kRankSum += 1

                //250天osc分布
                let pOscIndex:Int = oscIndex(macdOsc: p.macdOsc)
                oscRank[pOscIndex] += 1
                if pOscIndex < 19 {
                    oscRankSumL += 1
                } else if pOscIndex > 19 {
                    oscRankSumH += 1
                }

                //250天ma60Diff,ma20Diff分布
                let i60:Int = maDiffIndex(diff: p.ma60Diff)
                ma60DiffRank[i60] += 1
                ma60DiffRankSum += 1
                let i20:Int = maDiffIndex(diff: p.ma20Diff)
                ma20DiffRank[i20] += 1
                ma20DiffRankSum += 1
            }

            //250天最高價最低價距離現價的比率
            price.price250HighDiff = 100 * (price.priceClose - price250High) / price250High
            price.price250LowDiff  = 100 * (price.priceClose - price250Low)  / price250Low
           //60天最高價最低價距離現價的比率
            price.price60HighDiff = 100 * (price.priceClose - price60High) / price60High
            price.price60LowDiff  = 100 * (price.priceClose - price60Low)  / price60Low

            //250天K分布取常態分配的兩端
            var k20Index: Int = 0
            var k80Index: Int = 0
            var kCumulSum: Int = 0
            for i in 0...20 {
                kCumulSum += kRank[i]
                let kCumuRate:Double = Double(kCumulSum) / Double(kRankSum)
                if kCumuRate <= 0.35 {   // <-- 0.35
                    k20Index = i
                }
                if kCumuRate <= 0.70 {   // <-- 0.70 , i不用+1
                    k80Index = i
                }
            }

            //250天K分布
            price.k20Base = Double(k20Index * 5)
            price.k80Base = Double(k80Index * 5)
            if price.k20Base == 0 || price.k20Base > 35 {   // <-- 35
                price.k20Base = 35
            }
            if price.k80Base == 0 || price.k80Base < 70 {   // <-- 70
                price.k80Base = 70
            }

            //250天osc低分布
            var oscLIndex:Int = 19
            if oscRankSumL > 0 {
                var oscCumulSumL: Int = 0
                for i in 0...18 {
                    oscCumulSumL += oscRank[i]
                    let oscCumuRate:Double = Double(oscCumulSumL) / Double(oscRankSumL)
                    if oscCumuRate > 0.25  {    // <-- 0.25
                        oscLIndex = i
                        break
                    }
                }
                price.macdOscL = oscValue(index: oscLIndex)
            } else {
                price.macdOscL = 0
            }
            //250天osc高分布
            var oscHIndex:Int = 19
            if oscRankSumH > 0 {
                var oscCumulSumH = 0
                for i0 in 0...18 {
                    let i = 38 - i0
                    oscCumulSumH += oscRank[i]
                    let oscCumuRate:Double = Double(oscCumulSumH) / Double(oscRankSumH)
                    if oscCumuRate > 0.2 {     // <-- 0.2
                        oscHIndex = i
                        break
                    }
                }
                price.macdOscH = oscValue(index: oscHIndex)
            } else {
                price.macdOscH = 0
            }

            //250天ma60Diff分布取常態分配的兩端
            var ma60DiffHIndex:Int = 8
            var ma60DiffLIndex:Int = 8
            var ma20DiffHIndex:Int = 8
            var ma20DiffLIndex:Int = 8
            var ma60RankCumuSum:Int = 0
            var ma20RankCumuSum:Int = 0
            let maL:Double = 0.35
            let maH:Double = 0.65
            for i in 0...32 {
                ma60RankCumuSum += ma60DiffRank[i]
                ma20RankCumuSum += ma20DiffRank[i]
                let ma60CumuRate:Double = Double(ma60RankCumuSum) / Double(ma60DiffRankSum)
                let ma20CumuRate:Double = Double(ma20RankCumuSum) / Double(ma20DiffRankSum)
                if ma60CumuRate <= maL  {
                    ma60DiffLIndex = i
                }
                if ma60CumuRate <= maH {
                    ma60DiffHIndex = i
                }
                if ma20CumuRate <= maL  {
                    ma20DiffLIndex = i
                }
                if ma20CumuRate <= maH {
                    ma20DiffHIndex = i
                }

            }

//            let dtString = twDateTime.stringFromDate(price.dateTime)
//            if  (dtString == "2012/05/08" || dtString == "2012/05/09") && id == "1301" {
//                self.masterUI?.masterLog("*** masterUI debug:\(dtString) \(self.id) \(self.name)")
//
//            }



            price.ma60H = maDiffValue(index: ma60DiffHIndex)
            price.ma60L = maDiffValue(index: ma60DiffLIndex)
            price.ma20H = maDiffValue(index: ma20DiffHIndex)
            price.ma20L = maDiffValue(index: ma20DiffLIndex)


            var ma20DaysBefore: Float = 0
            if lastPrice.ma20Days < 0 && lastPrice.ma20Days > -5 && index >= Int(0 - lastPrice.ma20Days + 1) {
                ma20DaysBefore = Prices[index - Int(0 - lastPrice.ma20Days + 1)].ma20Days
            } else if lastPrice.ma20Days > 0 && lastPrice.ma20Days < 5 && index > Int(lastPrice.ma20Days + 1) {
                ma20DaysBefore = Prices[index - Int(lastPrice.ma20Days + 1)].ma20Days
            }


            if price.ma20 > lastPrice.ma20 {
                if lastPrice.ma20Days < 0  {
                    if lastPrice.ma20Days > -5 && ma20DaysBefore > 0 {
                        price.ma20Days = ma20DaysBefore + 1
                    } else {
                        price.ma20Days = 1
                    }
                } else {
                    price.ma20Days = lastPrice.ma20Days + 1
                }
            } else if price.ma20 < lastPrice.ma20 {
                if lastPrice.ma20Days > 0  {
                    if lastPrice.ma20Days < 5 && ma20DaysBefore < 0 {
                        price.ma20Days = ma20DaysBefore - 1
                    } else {
                        price.ma20Days = -1
                    }
                } else {
                    price.ma20Days = lastPrice.ma20Days - 1
                }
            } else {
                if lastPrice.ma20Days > 0 {
                    price.ma20Days = lastPrice.ma20Days + 1
                } else if lastPrice.ma20Days < 0 {
                    price.ma20Days = lastPrice.ma20Days - 1
                } else {
                    price.ma20Days = 0
                }

            }


            var ma60DaysBefore: Float = 0
            if lastPrice.ma60Days < 0 && lastPrice.ma60Days > -5 && index >= Int(0 - lastPrice.ma60Days + 1) {
                ma60DaysBefore = Prices[index - Int(0 - lastPrice.ma60Days + 1)].ma60Days
            } else if lastPrice.ma60Days > 0 && lastPrice.ma60Days < 5 && index >= Int(lastPrice.ma60Days + 1) {
                ma60DaysBefore = Prices[index - Int(lastPrice.ma60Days + 1)].ma60Days
            }


            if price.ma60 > lastPrice.ma60 {
                if lastPrice.ma60Days < 0  {
                    if lastPrice.ma60Days > -5 && ma60DaysBefore > 0 {
                        price.ma60Days = ma60DaysBefore + 1
                    } else {
                        price.ma60Days = 1
                    }
                } else {
                    price.ma60Days = lastPrice.ma60Days + 1
                }
            } else if price.ma60 < lastPrice.ma60 {
                if lastPrice.ma60Days > 0  {
                    if lastPrice.ma60Days < 5 && ma60DaysBefore < 0 {
                        price.ma60Days = ma60DaysBefore - 1
                    } else {
                        price.ma60Days = -1
                    }
                } else {
                    price.ma60Days = lastPrice.ma60Days - 1
                }
            } else {
                if lastPrice.ma60Days > 0 {
                    price.ma60Days = lastPrice.ma60Days + 1
                } else if lastPrice.ma60Days < 0 {
                    price.ma60Days = lastPrice.ma60Days - 1
                } else {
                    price.ma60Days = 0
                }

            }

            var maDaysBefore: Float = 0
            if lastPrice.maDiffDays < 0 && lastPrice.maDiffDays > -5 && index >= Int(0 - lastPrice.maDiffDays + 1) {
                maDaysBefore = Prices[index - Int(0 - lastPrice.maDiffDays + 1)].maDiffDays
            } else if lastPrice.maDiffDays > 0 && lastPrice.maDiffDays < 5 && index >= Int(lastPrice.maDiffDays + 1) {
                maDaysBefore = Prices[index - Int(lastPrice.maDiffDays + 1)].maDiffDays
            }

            if price.maDiff > lastPrice.maDiff {
                if lastPrice.maDiffDays < 0  {
                    if lastPrice.maDiffDays > -5 && maDaysBefore > 0 {
                        price.maDiffDays = maDaysBefore + 1
                    } else {
                        price.maDiffDays = 1
                    }
                } else {
                    price.maDiffDays = lastPrice.maDiffDays + 1
                }
            } else if price.maDiff < lastPrice.maDiff {
                if lastPrice.maDiffDays > 0  {
                    if lastPrice.maDiffDays < 5 && maDaysBefore < 0 {
                        price.maDiffDays = maDaysBefore - 1
                    } else {
                        price.maDiffDays = -1
                    }
                } else {
                    price.maDiffDays = lastPrice.maDiffDays - 1
                }
            } else {
                if lastPrice.maDiffDays > 0 {
                    price.maDiffDays = lastPrice.maDiffDays + 1
                } else if lastPrice.maDiffDays < 0 {
                    price.maDiffDays = lastPrice.maDiffDays - 1
                } else {
                    price.maDiffDays = 0
                }

            }


            //ma60在1年半內的標準差分；K在3個月內,Osc在辦年內的標準差分
            var zMa60Sum:Double = 0
            var zKdKSum:Double  = 0
            var zOscSum:Double  = 0
            var zVolSum:Double  = 0
            for p in Prices[d375.thisIndex...index] {
                zMa60Sum += p.ma60
                zVolSum  += (p.priceVolume * p.priceClose)
//                zOscSum  += p.macdOsc
//                zKdKSum  += p.kdK
            }
            for p in Prices[d125.thisIndex...index] {
                zOscSum  += p.macdOsc
            }
            for p in Prices[d60.thisIndex...index] {
                zKdKSum  += p.kdK
            }
            let zMa60Avg = zMa60Sum / d375.thisCount
            let zVolAvg  = zVolSum  / d375.thisCount
            let zOscAvg  = zOscSum  / d125.thisCount
            let zKdKAvg  = zKdKSum  / d60.thisCount
            var zMa60Var:Double = 0
            var zKdKVar:Double  = 0
            var zOscVar:Double  = 0
            var zVolVar:Double  = 0
            for p in Prices[d375.thisIndex...index] {
                let vMa60 = pow((p.ma60 - zMa60Avg),2)
                zMa60Var += vMa60
                let vVol  = pow(((p.priceVolume * p.priceClose) - zVolAvg),2)
                zVolVar  += vVol
//                let vOsc  = pow((p.macdOsc - zOscAvg),2)
//                zOscVar  += vOsc
//                let vKdK  = pow((p.kdK - zKdKAvg),2)
//                zKdKVar  += vKdK
            }
            for p in Prices[d125.thisIndex...index] {
                let vOsc  = pow((p.macdOsc - zOscAvg),2)
                zOscVar  += vOsc
            }
            for p in Prices[d60.thisIndex...index] {
                let vKdK  = pow((p.kdK - zKdKAvg),2)
                zKdKVar  += vKdK
            }
            let zMa60Sd = sqrt(zMa60Var / d375.thisCount) //ma60在1年半內的標準差
            let zOscSd  = sqrt(zOscVar  / d125.thisCount)
            let zKdKSd  = sqrt(zKdKVar  / d60.thisCount)
            let zVolSd  = sqrt(zVolVar  / d375.thisCount)
            price.ma60Z = (price.ma60 - zMa60Avg) / zMa60Sd     //ma60在1年半內的標準差分
            price.kdKZ  = (price.kdK  - zKdKAvg)  / zKdKSd
            price.macdOscZ  = (price.macdOsc  - zOscAvg)  / zOscSd
            price.priceVolumeZ = ((price.priceVolume * price.priceClose) - zVolAvg) / zVolSd
            





        } else { //if index == 0 {    //就是第1筆
            if price.dateTime.compare(dateRange().first) == .orderedSame {
                price.maDiffDays      = 0
                price.ma20Days        = 0
                price.ma60Days        = 0
                price.ma60            = price.priceClose     //1
                price.ma20            = price.priceClose     //2
                price.maDiff          = 0
                price.ma60Diff        = 0     //3
                price.ma20Diff        = 0     //4
                price.kdRSV           = 50    //5
                price.ma20Max9d       = 0     //6
                price.ma60Max9d       = 0     //7
                price.maMax9d         = 0
                price.kdK             = 50    //8
                price.kdD             = 50    //9
                price.kdJ             = 50    //10
                price.kdKZ            = 0
                price.kGrow           = 0     //11
                price.kGrowRate       = 0     //12
                price.priceLowDiff    = 0     //13
                price.priceUpward     = ""    //14
                price.kMinIn5d        = 50    //15
                price.kMaxIn5d        = 50    //16
                price.ma20Min9d       = 0     //17
                price.ma60Min9d       = 0     //18
                price.maMin9d         = 0
                price.simUpdated      = false //19
                price.ma60Avg         = 0
                price.ma60Sum         = 0
                price.ma60Z           = 0
                price.price60High     = price.priceHigh
                price.price60HighDiff = 0
                price.price60Low      = price.priceLow
                price.price60LowDiff  = 0
                price.price250HighDiff = 0
                price.price250LowDiff  = 0
                price.priceVolume   = 0
                price.priceVolumeZ  = 0
                price.ma60Rank      = ""
                //                    price.kRank = ""
                price.k20Base = 50
                price.k80Base = 50
                price.dividend = -999
                price.moneyChange = 0
                price.macd9 = 0
                price.macdOsc = 0
                price.macdEma12 = demandIndex
                price.macdEma26 = demandIndex
                price.macdOscL = 0
                price.macdOscH = 0
                price.macdOscZ = 0
                price.ma60H = 0
                price.ma60L = 0
                price.ma20H = 0
                price.ma20L = 0
                //                    price.macdRank = ""
            }

        }   //if index > 0
        if d375.thisCount >= 375 {
            price.simUpdated = true //這筆之前已經有足夠375天的筆數，則標記為已完成rank統計
        } else {
            price.simUpdated = false
        }


    }



























    //*****************************
    //========== 買賣規則 ==========
    //*****************************




    func updateSim(index:Int, price:Price, Prices:[Price]) {

        let date = twDateTime.startOfDay(price.dateTime)
        var lastIndex:Int = 0
        var lastPrice:Price = price
        var lastCost:Double = 0


        //========== 餘量和本金餘額 ==========
        if index == 0 {   //自己第1筆沒有前1筆
            price.simRuleBuy   = ""
            price.qtyInventory = 0
            price.simDays = 0
            price.simCost = 0
            price.cumulCost = 0
            price.cumulProfit = 0
            price.cumulROI  = 0
            price.cumulDays = 0
            price.cumulCut  = 0
            price.simRound = 0
            if (dateStart.compare(date) != ComparisonResult.orderedDescending) && (dateEndSwitch == false || dateEnd.compare(date) != ComparisonResult.orderedAscending) {
                price.simBalance = initMoney * 10000  //起始日在第一筆之前，就可以給錢開始玩了
                price.moneyMultiple = 1
            } else {
                price.simBalance = -1 //負1代表還沒起始，而不是用光了
                price.moneyMultiple = 0
            }
        } else {   //不是第一筆，就延續前筆數字繼續玩
            lastIndex = index - 1
            lastPrice = Prices[lastIndex]
            price.qtyInventory = lastPrice.qtyInventory
            price.simDays = lastPrice.simDays
            price.simCost = lastPrice.simCost
            price.cumulROI  = lastPrice.cumulROI
            price.cumulDays = lastPrice.cumulDays
            price.cumulCut  = lastPrice.cumulCut
            price.simRound  = lastPrice.simRound
            price.cumulCost = lastPrice.cumulCost   //不管有沒有庫存，先承前筆累計成本
            price.cumulProfit = lastPrice.cumulProfit
            lastCost = lastPrice.cumulCost * Double(lastPrice.cumulDays) //還原前筆累計成本的交易日佔比倍數
            if price.qtyInventory != 0 {  //前筆有庫存，算出模擬結餘
                price.simUnitCost = round(100 * price.simCost / (1000 * price.qtyInventory)) / 100 //今天價格不同，所以要重算
                price.simUnitDiff = round(10000 * (price.priceClose - price.simUnitCost) / price.simUnitCost) / 100
                let intervalDays = round(Float(price.dateTime.timeIntervalSince(lastPrice.dateTime as Date)) / 86400)
                price.simDays = price.simDays + intervalDays
                price.cumulDays = price.cumulDays + intervalDays
                price.simBalance = lastPrice.simBalance
                price.moneyMultiple = lastPrice.moneyMultiple
                price.simRuleBuy = lastPrice.simRuleBuy
                lastCost = lastCost - (Double(lastPrice.simDays) * lastPrice.simCost)
            } else {    //前筆沒有庫存，就沒有成本
                price.simRuleBuy = ""
                price.simDays = 0
                price.simUnitCost = 0
                price.simUnitDiff = 0
                price.simCost = 0
                price.simIncome = 0
                if dateStart.compare(date) != ComparisonResult.orderedDescending  {
                    price.simBalance = lastPrice.simBalance    //先給前日結餘
                    price.moneyMultiple = lastPrice.moneyMultiple
                    if price.simBalance == -1 {   //如果前筆沒庫存沒結餘也還沒開始玩
                        price.simBalance = initMoney * 10000  //從這筆開始時，給錢
                        price.moneyMultiple = 1
                        //如果前筆沒有庫存但開始玩了，沿用前結餘繼續，就算已經截止，結餘也要帶到今天為止
                    } else if lastPrice.qtySell > 0 {
                        price.moneyChange = 1 - price.moneyMultiple //抽出加碼倍數
                    }
                } else {
                    price.simBalance = -1  //前筆沒有這筆也還沒有開始，繼續沒有
                    price.moneyMultiple = 0
                }
            }
        }   //if index == 0 沒有前一筆








        //=========================

        if price.simBalance == -1 {   //還沒開始玩，各項模擬數值給0
            price.simReverse    = ""
            price.simRule       = ""
            price.simRuleBuy    = ""
            price.qtyBuy        = 0
            price.qtySell       = 0
            price.qtyInventory  = 0
            price.simDays       = 0
            price.simCost       = 0
            price.simUnitCost   = 0
            price.simUnitDiff = 0
            price.simROI        = 0
            price.simIncome     = 0
            price.moneyMultiple = 0
            price.moneyChange   = 0
            price.moneyRemark   = ""
            price.cumulDays = 0
            price.cumulCut  = 0
            price.simRound  = 0
        } else {


            if willResetReverse || price.simReverse == "" {
                price.simReverse = "無"
            }

            let d3 = priceIndex(3, currentIndex: index)
            let d5 = priceIndex(5, currentIndex:index)
            let d10 = priceIndex(10, currentIndex:index)
            var prevPrice:Price?


            //simRule是買賣規則分類
            //  L 低買
            //      M 低買前兆等待
            //      N 低買危險應延後
            //  H 高買
            //      I 追高危險應暫停
            //  S 應賣
            //simRuleBuy是買時採用的規則，除了L,H之外，其他為：
            //  R 不買反轉為買

            price.simRule = ""
            price.simRuleLevel = 0
 
            //============================
            //=====   買賣及加碼指標   =====
            //============================
            
            /*
            var oscLow:Bool = false
            if price.macdOsc > price.macdMin9d {
                let delayDays:Int = 3
                var thisIndex:Int = 0
                if index > delayDays {
                    thisIndex = index - delayDays    //是自第幾筆起算
                }
                for thePrice in Prices[thisIndex...lastIndex] { //不含自己
                    if thePrice.macdOsc == price.macdMin9d {
                        oscLow = true
                        break
                    }
                }
            }
            */
            
            var t00Safe:Bool = true
            if let t00 = masterUI?.getStock().simPrices["t00"] {
                if !t00.paused {
                    if self.id == "t00" {
                        masterUI!.getStock().t00P[price.dateTime] = (price.price250HighDiff,price.price250LowDiff)
                    } else {
                        //diff是加權指數現價距離1年內的最高價和最低價的差(%)，來排除跌深了可能持續崩盤的情形
                        var diff:(highDiff:Double,lowDiff:Double) = (maxDouble,maxDouble)
                        if let t00p = masterUI?.getStock().t00P[price.dateTime] {
                            diff = t00p
                        } else {
                            if let p = fetchPrice(dtStart: price.dateTime, dtEnd: price.dateTime, fetchLimit: 1, sId: "t00", asc: false).first {
                                diff = (p.price250HighDiff,p.price250LowDiff)
                                masterUI?.getStock().t00P[p.dateTime] = diff
                            }
                        }
                        if diff.lowDiff < 15 && ((diff.highDiff < -10 && diff.highDiff > -15) || diff.highDiff < -25) {
                            t00Safe = false
                        }
                    }
                }
            }
            

            //*** L Buy rules ***

            let price60Diff:Double = price.price60LowDiff - price.price60HighDiff   //過去60天的波動範圍
            let ma20HL:Double = (price.ma20H - price.ma20L == 0 ? 1 : price.ma20H - price.ma20L)  //稍後作分母不可以是零，所以給0.01
            let ma60HL:Double = (price.ma60H - price.ma60L == 0 ? 1 : price.ma60H - price.ma60L)  //ma60H就是1年內ma60超過65%的值，ma60L是35％以下的值
            let ma20MaxHL:Double = (price.ma20Max9d - price.ma20Min9d) / ma20HL
            let ma60MaxHL:Double = (price.ma60Max9d - price.ma60Min9d) / ma60HL
            //ma20MaxHL代表ma20在9天內波動的幅度超越1年內波動範圍幾倍，幅度太大即可能是波動的尾聲
            //ma60MaxHL同理。

            let macdOscL:Float  = (price.macdOsc < price.macdOscL ? 1 : 0)
            let k20Base:Float = (price.kdK < price.k20Base && price.kdKZ < (t00Safe ? -0.8 : -0.85) ? 1 : 0)
            let d20Base:Float = (price.kdD < price.k20Base ? 1 : 0)
            let j00Base:Float = (price.kdJ < -1 ? 1 : 0)
            let kdjBuy:Float   = k20Base + d20Base + j00Base + macdOscL

            let j9Buy:Float   = (price.kdJ < -9 ? 1 : 0)
            let k9Buy:Float   = (price.kdK <  9 ? 1 : 0)
            let ma20Buy:Float = (ma20MaxHL > 2.5 ? 1 : 0)
            let ma60Buy:Float = (ma60MaxHL > 2.0 ? 1 : 0)
            let maBuy:Float   = (ma20Buy == 1 && ma60Buy == 1 ? 1 : 0)
            let macdMin:Float = (price.macdOsc < (1.1 * price.macdOscL) && price.macdOscZ < -0.6 ? 1 : 0) //macdOscZ<0即可
            let ma20Drop:Float = (price.ma20Days < -30 && price.ma20Days > -60 ? -1 : 0)
            
//            let highDrop:Int = (highIn7 ? -1 : 0)
//            let ma60ZBuy:Int = (price.ma60Z > 5 ? -1 : 0)
//            let macdLow:Int  = (oscLow ? 1 : 0)
//            let price60H:Int = (price.price60HighDiff < -15 ? 1 : 0)
//            let ma60ZBuy:Int = (price.ma60Z < -2 || (price.ma60Z > -0.5 && price.ma60Z < 4.5) ? -1 : 0)

            price.simRuleLevel = kdjBuy + macdMin + j9Buy + k9Buy + ma20Buy + maBuy + ma20Drop

            let dropSafe:Bool = t00Safe || price.price250HighDiff < -55 || price.price250HighDiff > -35 || price.ma60Z > -1       //暴跌勿買，避險但會拉低大盤向上時的報酬率
            let baseBuy:Bool = price.simRuleLevel >= 3 && dropSafe
            


            


            //============================
            //*** simRule (5) *** 追高 ***
            //============================
            
            if d3.thisIndex > 0 {
                prevPrice = Prices[d3.thisIndex - 1]
            }

            var maxCount:Int = 0
            var minCount:Int = 0
            var bothMax:Bool = false
            var bothMin:Bool = false
            var allDrop:Bool = true
            for thePrice in Prices[d3.thisIndex...index] { //包括自己這一筆
                if thePrice.macdOsc == thePrice.macdMin9d {
                    minCount += 1  //k和macd下跌時
                }
                if thePrice.kdK == thePrice.kMinIn5d {
                    minCount += 1
                }
                
                if thePrice.macdOsc == thePrice.macdMax9d {
                    maxCount += 1  //k和macd攀高時
                }
                if thePrice.kdK == thePrice.kMaxIn5d {
                    maxCount += 1
                }
            
                if let prev = prevPrice {   //prevPrice是前1天
                    if prev.macdOsc < thePrice.macdOsc || prev.kdK < thePrice.kdK {
                        allDrop = false     //跟前1天比一直都是跌，就是全跌
                    }
                }
                prevPrice = thePrice
            }
            //bothMin和bothMax只看自己也就是最新這一筆
            bothMin = price.macdOsc == price.macdMin9d && price.kdK == price.kMinIn5d
            bothMax = price.macdOsc == price.macdMax9d && price.kdK == price.kMaxIn5d
//            allDrop = allDrop || maDrop //最後把是否剛掉下ma也要一起算進去

            //*** H Buy Must rules ***
            let hBuyMaH:Bool   = price.ma60Diff > price.ma60H && price.ma20Diff > price.ma20H
            let hBuyK80:Bool   = price.kdK < 82 && price.kdK > price.k20Base
            let hBuyMacdL:Bool = price.macdOsc > (0.3 * price.macdOscL)
            let hBuyAlmost:Bool  = hBuyK80 && hBuyMacdL && hBuyMaH
            
//            let lastDrop:Bool = (lastPrice.kdK > price.kdK || lastPrice.macdOsc > price.macdOsc) && price.ma60Z > 9  //一直漲就要更保守地追高，故一現跌勢就不追
            let xBuyMacdLow:Bool = (minCount >= 5 && bothMin) || allDrop //|| lastDrop //k和macd下跌時不要追高
            let hBuyMust:Bool    = hBuyAlmost && !xBuyMacdLow

            //*** H Buy Want rules ***
            let hMa60Z1:Bool = price.ma60Z < -1 || (price.ma60Z > 0  && price.ma60Z < 5)
            let hMa60Z2:Bool = price.ma60Z < -2 || (price.ma60Z > -1)
            let hBuyMa60Z:Float = ((t00Safe ? hMa60Z1 : hMa60Z2) ? 1 : 0)
                //hBuyMa60Z: ma60距離1.5年內平均值的離散程度，當略低於平均值時，似乎易跌應避免追高
            let hBuyMin:Float = ((price.ma60Diff > price.ma60Min9d && price.ma20Diff > price.ma20Min9d && price.macdOsc > price.macdMin9d) ? 1 : 0)
            let hMa60Rised:Float = (price.price60LowDiff > 30 ? 1 : 0) //高於60天最低價30%了 //price.ma60Z > 6 || //((price.ma60Avg > 8 || price.price60LowDiff > 30) ? 1 : 0)
            let hBuyMa60HL:Float  = (ma60MaxHL < 1 && ma20MaxHL < 2.5 ? 1 : 0)
            let hMaDiff:Bool = price.maDiff > 1 && price.maDiffDays > -4    //加碼還要用到這個條件
            let hBuyMaDiff:Float  = (hMaDiff  ? 1 : 0)

            let dtDate = twDateTime.calendar.dateComponents([.month,.day], from: price.dateTime)
            let monthPlus:[Float] = [0,1,0,0,0,0,-2,0,-2,0,0,0] //謎之月的加減分：7,9月減分、2月加分
            let mPlus:Float = monthPlus[(dtDate.month ?? 1) - 1]
//            var volZh:Float = 0
//            if price.priceVolumeZ > 4 {
//                volZh = 1
//            } else {
//                for thePrice in Prices[d5.thisIndex...index] { //包括自己這一筆
//                    if thePrice.priceVolumeZ > 2 {
//                        volZh = -1
//                    }
//                }
//            }
            



            let hBuyWant:Float = hBuyMa60Z + hBuyMin + hMa60Rised + hBuyMa60HL + hBuyMaDiff + mPlus //+ volZh  //monthPlus[(dtTime.month ?? 1) - 1]

            let hBuyWantLevel:Float = 3 //(t00Safe ? 3 : 5)
            if hBuyAlmost && xBuyMacdLow && hBuyWant >= hBuyWantLevel {
                price.simRule = "I" //若因為k和macd下跌而不符合追高條件，是為I
                price.simRuleLevel = Float(hBuyWant)
            } else if hBuyMust && hBuyWant >= hBuyWantLevel {  //這裡用else if接H判斷，即若是I就不要L判斷？
                price.simRule = "H" //高買是為H
                price.simRuleLevel = hBuyWant
            }
            
            if price.simRule == "" && baseBuy { //不是H才檢查是否逢低

            //============================
            //*** simRule (9) *** 逢低 ***
            //============================

                price.simRule = "L" //低買是為L

                var noFound:Bool = true
                for thePrice in Prices[d10.thisIndex...lastIndex].reversed() {
                    if thePrice.simRule == "M" {
                        let mDrop:Double = 100 * (price.priceClose - thePrice.priceClose) / thePrice.priceClose
                        var mLevel:Double = -5
                        switch price.ma60Rank {
                        case "A":
                            mLevel = -9
                        case "B":
                            mLevel = -7
                        case "C+":
                            mLevel = -5
                        case "C":
                            mLevel = -3
                        case "C-":
                            mLevel = -1
                        case "D":
                            mLevel = 1
                        case "E":
                            mLevel = 3
                        default:
                            break
                        }
                        if (mDrop >= mLevel && price.simRuleLevel <= 5) {
                            price.simRule = "N" //M之後價未跌夠低且低價條件未超過5，則轉為延後N
                        }
                        noFound = false         //M之後不是N（I之後不可能是N），就可以是L
                        break
                    } else if thePrice.simRule == "H" {
                        noFound = true         //H之後要起始為M
                        break
                    }
                }
                if noFound {    //|| price.priceLowDiff > 9 { //急跌
                    price.simRule = "M" //10天內沒有M，這個L轉為起始M
                }
            }

//            let dtString = twDateTime.stringFromDate(price.dateTime)
//            if  dtString == "2019/06/19" && id == "2376" {
//                self.masterUI?.masterLog("*** masterUI debug:%@  \(self.id) \(self.name) \(dtString)")
//            }
            
            
            //========== 賣出 ==========
            price.qtySell = 0

            let kHigh:Bool = price.kdK > (price.k80Base > 75 ? 85 : price.k80Base + 10) && (price.macdOsc > price.macdOscH || price.macdOsc == price.macdMax9d)
            
            //比昨日的波動幅度，漲10%就是漲停板了，故超過6%可緩明日再賣
            let priceHighDiff:Double = 100 * (price.priceHigh - lastPrice.priceClose) / lastPrice.priceClose
            
            if d5.lastIndex > 0 {
                prevPrice = Prices[d5.lastIndex - 1]
            } else {
                prevPrice = nil
            }
            var raisedPrice:Double = 0  //最近1日的起漲收盤價
            var priceHigh:Int = 0       //高價超過??趴的次數
            for thePrice in Prices[d5.lastIndex...lastIndex] { //不包括自己這1筆的前5日
                if thePrice.priceOpen < thePrice.priceClose && raisedPrice < thePrice.priceOpen {
                    raisedPrice = thePrice.priceClose
                }
                if let prev = prevPrice {
                    let thePriceHighDiff:Double = 100 * (thePrice.priceHigh - prev.priceClose) / prev.priceClose
                    if thePriceHighDiff >= 5 && thePrice.ma60Avg < -2 {
                        priceHigh += 1
                    }
                    prevPrice = thePrice
                }
            }
            let stillRaising:Bool = price.priceOpen > raisedPrice && price.priceClose > raisedPrice
            
            //*** kdj Must Rules ***
            //                let k80Must:Bool = price.kdK > price.k80Base * 0.85
            //                let j100Must:Bool = price.kdJ > 85
            //                let kdjMust:Bool = k80Must //&& j100Must
            //                let maxMa20:Int = (price.ma20Max9d == price.ma20Diff  ? 1 : 0)
            //                let maxMa60:Int = (price.ma60Max9d == price.ma60Diff  ? 1 : 0)
            //                let maxMacd:Int = (price.macdOsc   == price.macdMax9d ? 1 : 0)
            //                let maxWhat:Int = (maxMa20 + maxMa60 + maxMacd >= 2 ? 1 : 0)
            //                這堆沒用，放棄
            //                let openDrop:Double = 100 * (price.priceOpen - lastPrice.priceClose) / lastPrice.priceClose
            //                let openDropLevel:Double = (price.ma60Avg > 7 ? 3 : (price.ma60Avg > -7 ?  0 : -1))
            //                let openWasDrop:Int = (openDrop < openDropLevel  ? 0 : -1)
            
            //*** kdj Want rules ***
            let k80Base:Float  = (price.kdK > price.k80Base && price.kdKZ > 0.75 ? 1 :0)
            let d80Base:Float  = (price.kdD > price.k80Base ? 1 :0)
            let j100Base:Float = (price.kdJ > 101 ? 1 : 0)
            let macdOscH:Float = (price.macdOsc > price.macdOscH ? 1 : 0)
            let kdjSell:Float  = k80Base + d80Base + j100Base + macdOscH
            
            //*** other Want rules ***
            let j90:Float     = (price.kdJ > 90 && price.kdK == price.kMaxIn5d ? 1 : 0)
            let macdH6:Float  = (price.macdOsc > (0.6 * price.macdOscH) ? 1 : 0)    //不要max
            let macdMax:Float = (maxCount < 4 || bothMax ? 1 : 0)
            let k80High:Float = (price.simRule != "H" || kHigh ? 1 : 0)
            let ma20Max:Float = (ma20MaxHL > 1.2 ? (ma20MaxHL > 1.6 && price.macdOsc < (1.2 * price.macdOscH) ? 2 : 1) : (ma20MaxHL < 0.6 ? -1 : 0))
            let isRaising:Float = (stillRaising && price.ma60Z < -2 ? (price.simUnitDiff > 6 || price.ma60Avg < -5 ? -2 : -1) : 0)
//            let volZS:Float = (price.priceVolumeZ > 3.5 && price.ma60Z > 0 ? 1 : 0)
            let wantSell:Float = ma20Max + k80High + macdH6 + j90 + macdMax + isRaising //+ volZS
            
            let baseSell:Float = kdjSell + wantSell
            
            //*** all base rules ***
            let baseSell1:Bool = baseSell >= 5 && (priceHighDiff < (price.ma60Avg < -2.5 && price.ma60Z < 0.5 ? 5 : 6) || priceHigh >= 4)
            let baseSell2:Bool = baseSell >= 3 //不要priceHighDiff比較好
            let baseSell3:Bool = baseSell >= 2 && priceHighDiff < 5 //測試時只比<6優某個1年，拿掉也沒有影響了？
            
            if baseSell1 && price.simRule == "" {
                price.simRule = "S"   //應賣是為S
                price.simRuleLevel = baseSell
            }


            if  price.qtyInventory > 0 {

                var sellRule:Bool = false
                
                var fee = round(price.priceClose * price.qtyInventory * 1000 * 0.001425)
                if fee < 20 {
                    fee = 20
                }
                let tax = round(price.priceClose * price.qtyInventory * 1000 * 0.003)
                let valueNow = round(price.priceClose * price.qtyInventory * 1000)
                price.simIncome = valueNow - price.simCost - fee - tax

                //急漲賣：20天內急漲應賣
                let roi7Base:Bool = price.simUnitDiff > 7.5 && price.simDays < 10 && hBuyWant <= hBuyWantLevel
                let roi9Base:Bool = price.simUnitDiff > 9.5 && price.simDays < 20 //<--最近3年不會好？
                let roi7Sell:Bool = baseSell2 && (roi7Base || roi9Base)
                
                //短賣2：1.5個月內roi達4.5也夠了
                let roi4Sell:Bool = price.simUnitDiff > 4.5 && price.simDays > 35 && price.simDays <= 45 && baseSell2
                
                //短賣1：這是正常週期
                let daysRuleH:Float = (price.simRuleBuy == "H" && price.simUnitDiff < 2.5 ? (price.macdOsc > (0.6 * price.macdOscH) ? 2 : 5) : 0)
                let daysWeekend:Float = (twDateTime.calendar.component(.weekday, from: price.dateTime) <= 2 ? 2 : 0)  //跨週末：假日也計入simDays，weekday<=2(週一)即跨週末要加2天
                let sim5Days:Bool = price.simDays > (3 + daysWeekend + daysRuleH)
                let roi0Base:Bool = price.simUnitDiff > 0.45 && price.simDays > 75
                let roi0Sell:Bool = (price.simUnitDiff > 1.5 || roi0Base) && baseSell1 && sim5Days

                //HL起伏小而且拖久就停損
                let HLSell2a:Bool = price60Diff < 13 && price.simDays > 300 && price.simUnitDiff > -18
                let HLSell2b:Bool = price60Diff < 12 && price.simDays > 240 && price.simUnitDiff > -10
                let cutSell1:Bool  = (HLSell2a || HLSell2b || price.simDays > 400) && baseSell3
                
                //跌深停損
                let dropSell1:Bool = price60Diff > 20 && price.simDays > 100 && price.simUnitDiff > -8 && baseSell3 && !t00Safe && price.ma60Avg < -4.5   //大盤暴跌
                let dropSell2:Bool = price.price250LowDiff > 20 && price.price250HighDiff < -30 && price.ma60Z < (price.price250HighDiff < -40 ? -1.7 : -1.2) && price.simUnitDiff > -15 && price.simDays > 45 && price60Diff > 50    //暴漲暴跌 本來是price250HighDiff < -1.7
                let dropSell3:Bool = price.simDays < 10 && price.simUnitDiff < -11 && ((ma20MaxHL > (price.simUnitDiff < -15 ? 3.5 :4) && price.simRuleBuy == "H") || price.simUnitDiff < -18)
                var cutSell:Bool = (cutSell1 || dropSell1 || dropSell2  || dropSell3) //|| (price.priceVolumeZ > 4 && price.simUnitDiff > 0.5)
                
                if cutSell {
                    for thePrice in Prices[d5.lastIndex...lastIndex] {
                        if thePrice.qtyBuy > 0 {    //剛加碼不即停損
                            cutSell = false
                            break
                        }
                    }
                }
                
                if cutSell {
                    price.simRule = "S-"
                }

                sellRule = roi0Sell || roi7Sell || roi4Sell || cutSell
                
                if sellRule && price.simUnitDiff < 2.5 { 
                    for thePrice in Prices[d5.lastIndex...lastIndex] {
                        if thePrice.simReverse == "不賣" {    //剛反轉不即再賣
                            sellRule = false
                            break
                        }
                    }
                }
                
                //測試為無效的規則：
                //  近期不曾追高才停損
                //  300天停損時放寬起伏或報酬率條件
                //  baseSell2限制priceHighDiff < 7
                //  短賣排除急漲
                    
                



                if sellRule == true && price.simReverse == "不賣" {
                    sellRule = false
                    simReversed = true
                } else if sellRule == false && price.simReverse == "賣" {
                    sellRule = true
                    simReversed = true
                } else if price.simReverse != "買" && price.simReverse != "不買" {
                    if (dateEndSwitch == true && dateEnd.compare(price.dateTime as Date) != ComparisonResult.orderedDescending) {
                        price.simReverse = ""
                    } else {
                        price.simReverse = "無"
                    }
                }


                //<<<<<<<<<<<<<<<<<<<
                //***** 賣出條件 *****
                //<<<<<<<<<<<<<<<<<<<

                if  sellRule {
                    price.simBalance = price.simBalance + price.simIncome + price.simCost
                    price.simROI = (round(10000 * price.simIncome / price.simCost) / 100)
                    price.qtySell = price.qtyInventory
                    price.qtyInventory = price.qtyInventory - price.qtySell
                    if price.simIncome < 0 && price.simReverse != "賣" {
                        price.cumulCut += 1 //累計停損次數
                    }
                }
            }   //if  price.qtyInventory > 0
            if price.qtySell == 0 {
                price.simROI = 0
            }









            //========== 加碼 ==========
            //ma差與kdj等
            let gPrice30:Int = (price.simUnitDiff < -30 ? 1 : 0)
            let gBuyL:Int    = (price.simRule == "L" || (price.ma60Z < -1 && price.simRule == "M") ? 1 : 0)
            let gMa20Min:Int = (ma20MaxHL > 4 && price.ma20Diff == price.ma20Min9d ? 1 : 0)
            let gMacd:Int    = (price.macdOsc < (5 * price.macdOscL) ? 1 : 0)
            let gMa60Diff:Int = (price.ma60Diff == price.ma60Min9d && price.ma60Diff < -20 ? 1 : 0)
            let gLowPrice:Int = (price.priceLowDiff > 9 && abs(price.dividend) > 1 ? 1 : 0)
            let g60HDiff:Int  = (price.price60HighDiff < -20 ? 1 : 0)
            let g60LDiff:Int = (price.price60LowDiff < 5 ? 1 : 0)
            let gDays:Int    = (price60Diff < 12 && price.simDays > 180 ? 1 : 0)
            let gLowK:Int    = (price.kdK < 7 || price.kdJ < -10 ? 1 : 0)
//            let gWillCut:Int = (price.simUnitDiff > -40 && price.simDays > 310 ? -1 : 0) //臨近400天停損時避免無謂加碼
            
            let giveLevel:Int = gBuyL + gMa60Diff + gMacd + gLowPrice + g60HDiff + g60LDiff + gPrice30 + gDays + gLowK + gMa20Min

            //依時間與價差作為加碼的基本條件
            let give1a:Bool = price.simUnitDiff < -25 && (price.simUnitDiff < -50 || t00Safe)
            let give1b:Bool = price.simUnitDiff < -20 && price60Diff < 30 && price.simDays > 60
            //  ^^^這數值天數改動即生變：過去60天的波動高低在30%之內則略降低價差門檻
            let give1x2nd:Bool = price.moneyMultiple == 1 || price.simDays > (price.ma60Z < -2 ? 240 : (price.ma60Z < 0 ? 135 : 100)) || price.simUnitDiff < (t00Safe ? -35 : -60)    //第2次加碼的限制門檻   (price.ma60Z < -5 ? 200 : 100)
            let give1:Bool  = (give1a || give1b) && price.price60LowDiff < 10 && price.price60HighDiff < -22 && price.price250HighDiff < -25 && (price.ma60Avg < -15 || price.ma60Avg > -7) && give1x2nd

            //起伏小時，可冒險於-10趴即加碼
            let give2a:Bool = price.simUnitDiff < -12 && price60Diff < 15 && price.simDays > 180
            let give2b:Bool = price.simUnitDiff < -10 && ma20MaxHL > (price.ma60Z < 0 ? 5 : 4) && price.simDays > 5 && price.moneyMultiple == 1
            let give2:Bool  = (give2a || give2b) && (price.price60HighDiff < -15 || price.price60LowDiff < 5) && (price.ma60Avg > -1.5 || price.ma60Avg < -3.5) //t00Safe不要比較好

            //不論H或L後1個月內意外逢低但有追高潛力時的加碼逆襲，這條件不宜放入giveLevel似乎拖久就不靈了
            //或超過1年猶沒啥加碼機會就在逢低時隨便加碼看看
            let give31:Bool = price.simDays > 360 && price.moneyMultiple <= 2 && t00Safe
            let give32:Bool = price.simDays < 30  && price.moneyMultiple == 1 && price.priceClose < lastPrice.priceClose && hMaDiff && price.ma60Max9d > (2 * ma60MaxHL) && price.ma60Avg > 2 && t00Safe && price.price250HighDiff < -15.5 && price.price60HighDiff < -15.5
            let give3:Bool = price.simUnitDiff < -10 && price.simRule == "L" && (give31 || give32)
            

            var giveDiff:Int = 3    //至少3個條件
            if give3 {
                giveDiff = 0    //30天內欲冒險加碼，則不必限制門檻
            } else if price.simUnitDiff > -15 && price.simDays < 180 {
                giveDiff += 2    //不夠深也不夠久須提高門檻
            } else if price.simUnitDiff > -20 && price.simDays < 240 {
                giveDiff += 1
            }
            
            let lowGive:Bool = (give1 || give2 || give3) && giveLevel >= giveDiff
            var shouldGiveMoney:Bool =  (lowGive) && price.qtyInventory > 0


            //5天內不重複加碼
            if shouldGiveMoney {
                for thePrice in Prices[d5.lastIndex...lastIndex] {
                    if thePrice.moneyChange > 0 {
                        shouldGiveMoney = false
                        break
                    }
                }
            }




            price.moneyRemark = ""
            var doMoneyChange:Bool = true
            if let dtReversed = self.dateReversed {
                if price.dateTime.compare(dtReversed) == .orderedAscending {
                    doMoneyChange = false   //本次有反轉而此筆是反轉前的價格
                }
            }
            if doMoneyChange {  //別動反轉前的加碼變更
                if willResetMoney && price.moneyChange > 0 {    //moneyChange < 0是自動減碼時，不可清除為零
                    price.moneyChange = 0
                } else {
                    if price.moneyChange < 0 {
                        if (price.moneyMultiple + price.moneyChange) != 1 || price.qtyInventory > 0 {
                            //已減碼但是減後不是餘1個本金，或仍有庫存，可能前已改變加減碼行為，則強制還原減碼倍數為0
                            if price.qtyInventory > 0 {
                                price.moneyChange = 0
                            } else {
                                price.moneyChange = (0 - price.moneyMultiple + 1)
                            }    //則強制改正減碼倍數，令只還原到剩餘1個本金為止
                        }
                    } else if price.moneyChange > 0 {
                        if (price.qtyInventory == 0 || price.simDays == 1 || !shouldGiveMoney) {   //剛買或未買或不符條件，則強制還原加碼倍數為0
                            price.moneyChange = 0
                        }
                    }
                }

                if willGiveMoney && shouldGiveMoney && price.moneyChange == 0 {
                    if price.moneyMultiple <= 2 {    //小於3就是設定為測試時最多加碼2次
                        price.moneyChange = 1
                    }
                }
            }


            //不管是自動加碼還是按鈕加碼，到這裡price.moneyChange為1就是確定已加碼
            price.moneyMultiple = price.moneyMultiple + price.moneyChange
            price.simBalance = price.simBalance + (price.moneyChange * initMoney * 10000)

            if price.moneyMultiple > maxMoneyMultiple {
                maxMoneyMultiple = price.moneyMultiple
            }


            //不到負20趴就第一次加碼是為P冒險加碼，第二次加碼就應設限避免浮濫
//            if price.moneyChange == 1 && price.moneyMultiple <= 2 && price.simUnitDiff >= -20 {
//                price.simRuleBuy = "P"
//            }







            //========== 買入 ==========
            price.qtyBuy = 0
            var buyRule:Bool = false
            if price.simBalance > 0 && price.qtySell == 0 && (dateStart.compare(date) != ComparisonResult.orderedDescending) && (dateEndSwitch == false || dateEnd.compare(date) != ComparisonResult.orderedAscending) {

                
                //首次買進：符合高買或低買條件、不是除權息日當天
                if price.simRuleBuy == "" && (price.simRule == "H" || price.simRule == "L") && abs(price.dividend) > 0 {
                    price.simRuleBuy = price.simRule
                    buyRule = true
                //加碼時則延續首次買進的simRuleBuy標記
                } else if price.moneyChange > 0 {
                    buyRule = true
                }
                
//                buyRule = price.simRuleBuy == "H" && price.simDays == 0   //測試單獨的H或L條件
                
                if buyRule {

                    let d20 = priceIndex((price.price250HighDiff < -20 ? 15 : 20), currentIndex:index)
                    for thePrice in Prices[d20.lastIndex...lastIndex].reversed() {
                        if thePrice.qtySell > 0 && thePrice.simUnitDiff < 0 {
                            if price.simRuleBuy == "H" || (thePrice.simUnitDiff < -18 && thePrice.simRule == "S-") {
                                buyRule = false //20天內才停損就不要追高或避免急跌停損後買了還跌
                                break
                            }
                        }
                    }

                    if buyRule {    //通常是空隔1天再買下一輪，跌久時就多延後3~4天
                        let delayDays:Double = (price.ma60Avg < -7 ? 3 : (price.ma60Avg > 1 ? 4 : 1)) //delayDays最小是1
                        let dd = priceIndex(delayDays, currentIndex:index)
                        for thePrice in Prices[dd.lastIndex...lastIndex] {
                            if thePrice.qtySell > 0 && thePrice.simReverse == "無" {
                                buyRule = false //1~4天內不接著買
                                break
                            }
                        }
                    }
                    
                    /*
                    if buyRule {
                        let delayDays:Int = 2
                        var thisIndex:Int = 0
                        if index > delayDays {
                            thisIndex = index - delayDays    //是自第幾筆起算
                        }
                        for thePrice in Prices[thisIndex...lastIndex] {
                            if thePrice.qtySell > 0 && thePrice.simReverse == "無"  {
                                buyRule = false //delayDays之內不接著買
                                break
                            }
                        }
                     }
                     */

                    
                }
            }   //if price.simBalance > 0

            let singleFee  = round(price.priceClose * 1.425)    //1張的手續費
            let singleCost = (price.priceClose * 1000) + (singleFee > 20 ? singleFee : 20)  //1張的成本
            if buyRule == true && price.simBalance < singleCost {
                buyRule = false //錢不夠先清除buyRule以簡化後面反轉的判斷規則
            }
            //無=\U7121 買=\U8cb7
            if buyRule == true && price.qtyInventory == 0 && price.simReverse == "不買" {
                buyRule = false
                simReversed = true
            } else if buyRule == false && price.qtyInventory == 0 && price.simReverse == "買" {
                buyRule = true
                simReversed = true
                price.simRuleBuy = "R"
            } else if price.simReverse != "賣" && price.simReverse != "不賣" {
                if (dateEndSwitch == true && dateEnd.compare(price.dateTime as Date) != ComparisonResult.orderedDescending) {
                    price.simReverse = ""
                } else if price.qtyInventory == 0 { //都不是就不要改simReverse因為可能真的反轉「賣」「不賣」
                    price.simReverse = "無"
                }
            }
            

            //<<<<<<<<<<<<<<<<<<<
            //***** 買入條件 *****
            //<<<<<<<<<<<<<<<<<<<
            if  buyRule {
                var buyMoney:Double = (price.moneyMultiple * initMoney * 10000) - price.simCost
                if buyMoney > price.simBalance && (price.simReverse != "買" || price.simBalance > singleCost) {
                    buyMoney = price.simBalance //反轉買錢又不夠時，會維持預設buyMoney即給足1個本金的額度
                }
                let perCost:Double = price.priceClose * 1000 * 1.001425 //每張含手續費的成本
                var estimateQty = floor(buyMoney / perCost)             //則可以買這麼多張
                let feeQty:Double = ceil(20 / (price.priceClose * 1.425))   //20元的手續費可買這麼多張
                //手續費最少20元，買不到feeQty張數則手續費要算20元
                if estimateQty < feeQty {
                    estimateQty = floor((buyMoney - 20) / (price.priceClose * 1000))
                }
                price.qtyBuy = estimateQty

                if price.qtyBuy == 0 {
                    if buyMoney > singleCost {
                        price.qtyBuy = 1    //剩餘資金剛好只夠購買1張，就買咩
                    }
                }
                if price.qtyBuy > 0 {
                    if price.qtyInventory == 0 { //首次買入
                        price.simDays = 1
                        price.simRound = price.simRound + 1
                        price.cumulDays = price.cumulDays + 1
                    }
                    var cost = round(price.priceClose * price.qtyBuy * 1000)
                    var fee = round(price.priceClose * price.qtyBuy * 1000 * 0.001425)
                    if fee < 20 {
                        fee = 20
                    }
                    cost = cost + fee
                    price.simBalance = price.simBalance - cost
                    price.simCost = price.simCost + cost
                    price.qtyInventory = price.qtyInventory + price.qtyBuy
                    price.simUnitCost = round(100 * price.simCost / (1000 * price.qtyInventory)) / 100  //就是除以1000股然後四捨五入到小數2位
                    price.simUnitDiff = round(10000 * (price.priceClose - price.simUnitCost) / price.simUnitCost) / 100 //如果有買就要重算價差率，才與成本價一致
                }
            }

            if price.cumulDays > 0 {
                price.cumulCost = (lastCost + (price.simCost * Double(price.simDays))) / Double(price.cumulDays)
            }
            var valueNow:Double = 0
            if price.cumulCost > 0 {
                if price.qtyInventory > 0 {
                    valueNow = price.simIncome + price.simCost
                }
                price.cumulProfit = valueNow + price.simBalance - (price.moneyMultiple * initMoney * 10000)

                price.cumulROI = 100 * price.cumulProfit / price.cumulCost
            }

            if price.qtyBuy == 0 && price.qtySell == 0 && price.qtyInventory == 0 {
                price.simRuleBuy = ""
            }   //雖然simRuleBuy是可買的條件，但是可能錢不夠無法買，則還是要清除。無庫存即排除加碼失敗。

            let pullMoney:Bool = (price.moneyChange == 0 && price.moneyMultiple > 1 && price.qtyInventory == 0 && price.qtySell == 0 && price.qtyBuy == 0)
            if pullMoney {
                price.moneyRemark = "-"   //建議減碼的標記
            } else if shouldGiveMoney {  //如果符合....
                price.moneyRemark = "+"   //就給上建議加碼的標記
            }

        }   //if price.simBalance == -1


    }   //func updateSim
 

}

