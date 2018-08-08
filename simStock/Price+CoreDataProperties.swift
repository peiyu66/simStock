//
//  Price+CoreDataProperties.swift
//  simStock
//
//  Created by peiyu on 2016/9/8.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Price {
    @NSManaged var cumulCost: Double
    @NSManaged var cumulCut: Float
    @NSManaged var cumulDays: Float
    @NSManaged var cumulProfit: Double
    @NSManaged var cumulROI: Double
    @NSManaged var dateTime: Date
    @NSManaged var dividend: Float
    @NSManaged var id: String
    @NSManaged var k20Base: Double
    @NSManaged var k80Base: Double
    @NSManaged var kdD: Double
    @NSManaged var kdJ: Double
    @NSManaged var kdK: Double
    @NSManaged var kdRSV: Double
    @NSManaged var kGrow: Double
    @NSManaged var kGrowRate: Double
    @NSManaged var kMaxIn5d: Double
    @NSManaged var kMinIn5d: Double
    @NSManaged var ma20: Double
    @NSManaged var ma20Days: Float
    @NSManaged var ma20Diff: Double
    @NSManaged var ma20H: Double
    @NSManaged var ma20L: Double
    @NSManaged var ma20Max9d: Double
    @NSManaged var ma20Min9d: Double
    @NSManaged var ma60: Double
    @NSManaged var ma60Avg: Double
    @NSManaged var ma60Days: Float
    @NSManaged var ma60Diff: Double
    @NSManaged var ma60H: Double
    @NSManaged var ma60L: Double
    @NSManaged var ma60Max9d: Double
    @NSManaged var ma60Min9d: Double
    @NSManaged var ma60Rank: String
    @NSManaged var ma60Sum: Double
    @NSManaged var macd9: Double
    @NSManaged var macdEma12: Double
    @NSManaged var macdEma26: Double
    @NSManaged var macdMax9d: Double
    @NSManaged var macdMin9d: Double
    @NSManaged var macdOsc: Double
    @NSManaged var macdOscH: Double
    @NSManaged var macdOscL: Double
    @NSManaged var maDiff: Double
    @NSManaged var maDiffDays: Float
    @NSManaged var maMax9d: Double
    @NSManaged var maMin9d: Double
    @NSManaged var moneyChange: Double
    @NSManaged var moneyMultiple: Double
    @NSManaged var moneyRemark: String
    @NSManaged var price60High: Double
    @NSManaged var price60HighDiff: Double
    @NSManaged var price60Low: Double
    @NSManaged var price60LowDiff: Double
    @NSManaged var priceClose: Double
    @NSManaged var priceHigh: Double
    @NSManaged var priceLow: Double
    @NSManaged var priceLowDiff: Double
    @NSManaged var priceOpen: Double
    @NSManaged var priceUpward: String
    @NSManaged var priceVolume: Double
    @NSManaged var qtyBuy: Double
    @NSManaged var qtyInventory: Double
    @NSManaged var qtySell: Double
    @NSManaged var simBalance: Double
    @NSManaged var simCost: Double
    @NSManaged var simDays: Float
    @NSManaged var simIncome: Double
    @NSManaged var simReverse: String
    @NSManaged var simROI: Double
    @NSManaged var simRound: Float
    @NSManaged var simRule: String
    @NSManaged var simRuleBuy: String
    @NSManaged var simRuleLevel: Float
    @NSManaged var simUnitCost: Double
    @NSManaged var simUnitDiff: Double
    @NSManaged var simUpdated: Bool
    @NSManaged var updatedBy: String
    @NSManaged var year: String

}
