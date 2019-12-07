//
//  stock.swift
//  simStockOsx
//
//  Created by peiyu on 2019/11/6.
//  Copyright © 2019 peiyu. All rights reserved.
//

import Foundation
import CoreData

class stock:NSObject {
    var delegate:simStockDelegate?

    var stockId:String = ""
    var stockName:String = ""
    
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

    
    init(stockId:String, stockName:String, delegate:simStockDelegate) {
        self.stockId    = stockId
        self.stockName  = stockName
        self.delegate   = delegate
    }
    
    func connectDelegate(_ delegate:simStockDelegate) {
        self.delegate = delegate
    }


    
    func fetchPrice (_ dateOP:String?=nil,dtStart:Date?=nil,dtEnd:Date?=nil,fetchLimit:Int?=nil, sId:String?=nil, asc:Bool=true) -> [Price] {
        //都不指定參數時：抓起迄期間並順排
        let context = delegate!.context()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        let entityDescription = NSEntityDescription.entity(forEntityName: "Price", in: context)
        fetchRequest.entity = entityDescription
        var predicates:[NSPredicate] = []
        var dtS:Date = dateEarlier
        var dtE:Date = (self.dateEndSwitch ? self.dateEnd : Date())
        if let pId = sId {
            predicates.append(NSPredicate(format: "id = %@", pId))
        } else {
            predicates.append(NSPredicate(format: "id = %@", stockId))
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
//            let fetchError = error as NSError
//            self.masterUI?.masterLog("\(self.id) \(self.name) \tfetchPrice error:\n\(fetchError)")
        }

        return []

    }
    
    func newPrice(_ source:String, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> Price {

        let context = delegate!.context()
        let price:Price = NSEntityDescription.insertNewObject(forEntityName: "Price", into: context) as! Price
        price.stockId      = stockId
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

        return price

    }


    func updatePrice(_ source:String, dateTime:Date, year:String, close:Double, high:Double, low:Double, open:Double, volume:Double) -> Price {

        let dateS = twDateTime.startOfDay(dateTime)
        let dateE = twDateTime.endOfDay(dateTime)
        let Prices = fetchPrice(dtStart: dateS, dtEnd: dateE)
        if Prices.count > 0 {
            if dateS.compare(twDateTime.startOfDay(Prices.last!.dateTime)) == .orderedSame {

                let price = Prices.last!
                price.stockId      = stockId
                price.updatedBy    = source            //2
                price.dateTime     = dateTime          //3
                price.year         = year              //4
                price.priceClose   = close             //5
                price.priceHigh    = high              //6
                price.priceLow     = low               //7
                price.priceOpen    = open              //8
                price.priceVolume  = volume
                price.simUpdated   = false
                return price
            } else {
                return newPrice(source,dateTime:dateTime,year:year,close:close,high:high,low:low,open:open,volume:volume)
            }
        } else {
            return newPrice(source,dateTime:dateTime,year:year,close:close,high:high,low:low,open:open,volume:volume)
        }
    }

    
}
