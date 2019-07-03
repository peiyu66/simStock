//
//  ViewController.swift
//  simStock
//
//  Created by peiyu on 2016/3/27.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit
import CoreData
import ZipArchive   //v2.13
import AVFoundation


protocol masterUIDelegate:class {
    func isExtVersion() -> Bool
    func masterLog(_ msg:String)
    func globalQueue() -> OperationQueue
    func setProgress(_ progress:Float, message:String?)
    func systemSound(_ soundId:SystemSoundID)
    func setIdleTimer(timeInterval:TimeInterval)
    func messageWithTimer(_ text:String,seconds:Int)
    func setSegment()
    func lockUI(_ message:String)
    func unlockUI(_ message:String)
    func getStock() -> simStock
    func simRuleColor(_ simRule:String) -> UIColor
    func showPrice(_ Id:String?)
}


class masterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, priceCellDelegate, UIPopoverPresentationControllerDelegate, masterUIDelegate  {

    var extVersion:Bool     = false     //擴充欄位 = false  匯出時及價格cell展開時，是否顯示擴充欄位？
    var lineReport:Bool     = false     //要不要在Line顯示日報訊息
    var lineLog:Bool        = false     //要不要在Line顯示沒有remark的Log
    var debugRun:Bool       = false     //是不是在Xcode之下Run，是的話不管lineLog為何，都會顯示Log
    var isPad:Bool          = false

    let defaults:UserDefaults = UserDefaults.standard
    let stock:simStock = simStock()

    let globalOperation:OperationQueue = OperationQueue()
    let dispatchGroup:DispatchGroup = DispatchGroup()
    var bot:lineBot?


    func globalQueue() -> OperationQueue {
        return globalOperation
    }

    func isExtVersion() -> Bool {
        return extVersion
    }

    func systemSound(_ soundId:SystemSoundID) {
        AudioServicesPlaySystemSound(soundId)
    }

    func getStock() -> simStock {
        return stock
    }


    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var uiProgress: UIProgressView!
    @IBOutlet weak var uiMessage: UILabel!
    @IBOutlet weak var uiSetting: UIButton!
    @IBOutlet weak var uiSegment: UISegmentedControl!


    @IBOutlet weak var uiLeftButton: UIButton!
    @IBOutlet weak var uiRightButton: UIButton!
    @IBOutlet weak var uiStockName: UIButton!
    @IBOutlet weak var uiProfitLoss: UILabel!
    @IBOutlet weak var uiMoneyChanged: UIButton!
    @IBOutlet weak var uiSimReversed: UIButton!

    @IBOutlet weak var uiBarRefresh: UIBarButtonItem!
    @IBOutlet weak var uiBarAction: UIBarButtonItem!
    @IBOutlet weak var uiBarAdd: UIBarButtonItem!
    @IBOutlet weak var uiInformation: UIButton!

    @IBAction func uiShiftLeft(_ sender: UIButton) {
        if stock.shiftLeft() {
            self.showPrice()
        }
    }

    @IBAction func uiShiftRight(_ sender: UIButton) {
        if stock.shiftRight() {
            self.showPrice()
        }
    }


    @IBAction func uiRefresh(_ sender: UIBarButtonItem) {
        let textMessage = "刪除 " + stock.simId + " " + stock.simName + " 的歷史股價\n並重新下載？"
        let alert = UIAlertController(title: "重新下載或重算", message: textMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "刪最後1個月", style: .default, handler: { action in
            self.lockUI("刪最後1個月")
            self.globalQueue().addOperation {
                self.stock.simPrices[self.stock.simId]!.deleteLastMonth()
                OperationQueue.main.addOperation {
                    if !self.stock.simTesting {
                        self.stock.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
                    }
                    self.unlockUI()
                    self.stock.timePriceDownloaded = Date.distantPast
                    self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                    self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "全部刪除重算", style: .default, handler: { action in
            self.stock.setupPriceTimer(self.stock.simId, mode: "reset")
        }))
        alert.addAction(UIAlertAction(title: "不刪除只重算", style: .default, handler: { action in
            self.lockUI("重算模擬")
            self.globalQueue().addOperation {
                self.stock.simPrices[self.stock.simId]!.resetSimUpdated()
                OperationQueue.main.addOperation {
                    if !self.stock.simTesting {
                        self.stock.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
                    }
                    self.unlockUI()
                    self.stock.timePriceDownloaded = Date.distantPast
                    self.stock.defaults.removeObject(forKey: "timePriceDownloaded")
                    self.stock.setupPriceTimer(self.stock.simId, mode: "all")
                }
            }
        }))
       self.present(alert, animated: true, completion: nil)


    }

    @IBAction func uiExportCsv(_ sender: UIBarButtonItem) {
        saveAndExport(stock.simId)
    }

    @IBAction func uiNextMoneyChanged(_ sender: UIButton) {
        goNextMoneyChange()
    }

    @IBAction func uiNextSimReversed(_ sender: UIButton) {
        goNextSimReverse()
    }

    @IBAction func uiInfo(_ sender: UIButton) {
        func openUrl (_ url:String) {
            if let URL = URL(string: url) {
                if UIApplication.shared.canOpenURL(URL) {
                    UIApplication.shared.open(URL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                } else {
                    let alert = UIAlertController(title: "simStock \(stock.versionNow)", message: "不知為何無法開啟頁面。", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "知道了", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        let textMessage = "查看網站說明或設定？" 
        let alert = UIAlertController(title: "simStock \(stock.versionNow)", message: textMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "不用了", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "主畫面", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimStock/zhu-hua-mian")
        }))
        alert.addAction(UIAlertAction(title: "策略概述", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimstock/ce-luee-yu-fang-fa")
        }))
        alert.addAction(UIAlertAction(title: "常見問題", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimStock/chang-jian-wen-ti")
        }))
        alert.addAction(UIAlertAction(title: "版本說明", style: .default, handler: { action in
            openUrl("https://sites.google.com/site/appsimStock/ban-ben-shuo-ming")
        }))
        alert.addAction(UIAlertAction(title: "Yahoo!", style: .default, handler: { action in
            openUrl("https://tw.stock.yahoo.com/q/ta?s="+self.stock.simId)
        }))
        alert.addAction(UIAlertAction(title: "＊設定＊", style: .default, handler: { action in
            openUrl(UIApplication.openSettingsURLString)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(masterViewController.updateRealtimeByPull), for: UIControl.Event.valueChanged)

        return refreshControl
    }()

    @objc func updateRealtimeByPull() {
        if stock.isUpdatingPrice && stock.priceTimer.isValid == false {
            refreshControl.endRefreshing()
        } else {
            self.stock.timePriceDownloaded = Date.distantPast
            self.defaults.removeObject(forKey: "timePriceDownloaded")
            if stock.needPriceTimer() {
                stock.setupPriceTimer(mode: "realtime")
            } else {
                stock.setupPriceTimer(mode: "all")
            }
        }
    }


// *********************************
// ***** ===== Core Data ===== *****
// *********************************

    let entityPrice:String = "Price"

    var privateContext:NSManagedObjectContext = {
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return privateContext
    }()

    func getContext() -> NSManagedObjectContext {
        if Thread.current == Thread.main {
            let mainContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
            return mainContext
        } else {
            return privateContext
        }
    }



    var _fetchedResultsController:NSFetchedResultsController<NSFetchRequestResult>?

    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }


        let context = getContext()
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entityPrice, in: context)
        fetchRequest.fetchBatchSize = 25

        let sortDescriptor1 = NSSortDescriptor(key: "year", ascending: false)
        let sortDescriptor2 = NSSortDescriptor(key: "dateTime", ascending: false)
        fetchRequest.sortDescriptors = ([sortDescriptor1,sortDescriptor2])

        var dtPeriod:String = "none"
        var predicates:[NSPredicate] = []
        predicates.append(NSPredicate(format: "id = %@", stock.simId))
        if let sim = stock.simPrices[stock.simId] {
            let dtS:Date = sim.dateEarlier
            let dtE:Date = twDateTime.endOfDay(sim.dateEndSwitch ? sim.dateEnd : Date())
            predicates.append(NSPredicate(format: "dateTime >= %@", dtS as CVarArg))
            predicates.append(NSPredicate(format: "dateTime <= %@", dtE as CVarArg))
            dtPeriod = "\(twDateTime.stringFromDate(dtS))~\(twDateTime.stringFromDate(dtE))"
        }
        fetchRequest.predicate = NSCompoundPredicate(type: NSCompoundPredicate.LogicalType.and, subpredicates: predicates)

        let sectionKey = "year"

        _fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: sectionKey, cacheName: nil)

        _fetchedResultsController!.delegate = self

        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            self.masterLog("fetchedResultsController error:\n\(error)\n\n")
        }

        if let _ = _fetchedResultsController!.fetchedObjects {
            self.masterLog("*\(stock.simId) \(stock.simName) \tfetchedResults: \(dtPeriod)")
        }

        return _fetchedResultsController!

    }






    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch(type) {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch (type) {
        case .update:
            if let indexPath = indexPath {
                tableView.reloadRows(at: [indexPath], with: .none)
            }
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .move:
            if let indexPath = indexPath {
                if let newIndexPath = newIndexPath {
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    tableView.insertRows(at: [newIndexPath], with: .fade)
                }
            }
        }
    }

    func saveContext() {
        let context = getContext()
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                self.masterLog("saveContext error\n\(error)\n")
            }
        }
    }


    func deleteAllCoreData(_ entity:String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            let context = getContext()
            try context.execute(deleteRequest)
        } catch {
            self.masterLog("Unresolved error in deleteAllCoreData \(entity)\n\(error)\n")
        }
        saveContext()
    }
















// ***********************************
// ***** ===== Master View ===== *****
// ***********************************




    override func viewDidLoad() {
//        self.defaults.removeObject(forKey: "timeReported")
//        defaults.set(twDateTime.timeAtDate(hour: 09, minute: 10), forKey: "timePriceDownloaded")
        super.viewDidLoad()
        debugRun = defaults.bool(forKey: "debugRun")    //在edit scheme run argument 加入 "-debugRun YES"
        if (traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            isPad = true
        }

        stock.connectMasterUI(self) // <----- 起始參數 -----
        if gotDevelopPref == false { //iOSversion < "11" {
            getDevelopPref()    //iOS11和ApplicationDidBecomeActive重複?
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appNotification),
            name: UIApplication.willResignActiveNotification, object: nil)

        tableView.addSubview(self.refreshControl)

        UIDevice.current.isBatteryMonitoringEnabled = true

        uiMessage.adjustsFontSizeToFitWidth = true
        uiProfitLoss.adjustsFontSizeToFitWidth = true
        uiSetting.titleLabel?.adjustsFontSizeToFitWidth = true
        uiStockName.titleLabel?.adjustsFontSizeToFitWidth = true

        showPrice()

        self.masterLog("=== viewDidLoad \(stock.versionNow) ===")
        
    }


























    var gotDevelopPref:Bool = false
    func getDevelopPref() {     //開發測試的選項及下載股價
        gotDevelopPref = true
        
        extVersion = defaults.bool(forKey: "extsionMode")
        lineLog    = defaults.bool(forKey: "lineLog")       //是否輸出除錯訊息
        lineReport = defaults.bool(forKey: "lineReport")    //是否輸出LINE日報
        if bot == nil {
            bot = lineBot()
            bot?.masterUI = self
        }
        if lineReport {
            bot!.verifyToken()
        } else {
            bot!.logout()
            bot = nil
        }
        let twseRealtime = defaults.bool(forKey: "realtimeSource")
        if  twseRealtime {
            stock.realtimeSource = "twse"
        } else {
            stock.realtimeSource = "yahoo"
        }

        let twseMain = defaults.bool(forKey: "mainSource")
        if  twseMain {
            stock.mainSource = "twse"
        } else {
            stock.mainSource = "cnyes"
        }


        let locked = defaults.bool(forKey: "locked")
        if locked && stock.isUpdatingPrice == false {
            self.masterLog("locked? -> continue.")
        }

        uiMessageClear()
        clearSettingCopy()

        if !twDateTime.isDateInToday(stock.timePriceDownloaded) {
            stock.todayIsNotWorkingDay = false
        }

        if stock.simTesting {
            func launchTesting(fromYears:Int, forYears:Int, loop:Bool) {
                let simFirst:simPrice =  self.stock.simPrices[self.stock.sortedStocks[0].id]!
                let dtStart:String =  twDateTime.stringFromDate(simFirst.defaultDates(fromYears:fromYears).dateStart, format: "yyyy/MM/dd")
                self.masterLog("== runSimTesting \(fromYears)年 \(dtStart)起 \(loop ? "每" : "單")輪\(forYears)年 ==\n")
                self.stock.runSimTesting(fromYears: fromYears, forYears: forYears, loop: loop)
            }
            if stock.justTestIt {
                launchTesting(fromYears:13, forYears:3, loop:true)
            } else {
                let textMessage = "執行幾年模擬測試？"
                let alert = UIAlertController(title: "模擬測試", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: {action in
                    self.stocksPref()
                }))
                alert.addAction(UIAlertAction(title: "13年起每輪3年", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:3, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "13年起每輪2年", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:2, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "13年內重算MA", style: .default, handler: {action in
                    launchTesting(fromYears:13, forYears:13, loop:false)
                }))
                alert.addAction(UIAlertAction(title: "10年起每輪2年", style: .default, handler: {action in
                    launchTesting(fromYears:10, forYears:2, loop:true)
                }))
                alert.addAction(UIAlertAction(title: "10年起每輪3年", style: .default, handler: {action in
                    launchTesting(fromYears:10, forYears:3, loop:true)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            stocksPref()
        }

    }

    func stocksPref() {
        stock.resetSimTesting()

        if let t = defaults.object(forKey: "timeReported") {
            timeReported = t as! Date
        }
        let dt_updated  = twDateTime.stringFromDate(stock.timePriceDownloaded, format:"yyyy/MM/dd HH:mm:ss.SSS")
        let dt_reported = twDateTime.stringFromDate(timeReported, format:"yyyy/MM/dd HH:mm:ss.SSS")
        masterLog("updated:  \(dt_updated)")
        masterLog("reported: \(dt_reported)")

        if !NetConnection.isConnectedToNetwork() {
            messageWithTimer("沒有網路",seconds: 10)
            masterLog("沒有網路。")
        }

        askToRemoveStocks()

    }

    @objc func askToRemoveStocks() {
        if stock.isUpdatingPrice == false {
            if defaults.bool(forKey: "resetStocks") {
                let textMessage = "重算數值或刪除股群及價格？\n（移除股群時會保留\(self.stock.defaultName)喔）"
                let alert = UIAlertController(title: "重算或刪除股群", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
                    self.askToAddTestStocks()
                }))
                if stock.simPrices.count > 1 {
                    alert.addAction(UIAlertAction(title: "移除全部股群", style: .default, handler: { action in
                        self.removeAllStocks()
                    }))
                }
                alert.addAction(UIAlertAction(title: "刪除全部股價", style: .default, handler: { action in
                    self.deleteAllPrices()
                }))
                alert.addAction(UIAlertAction(title: "刪最後1個月股價", style: .default, handler: { action in
                    self.deleteOneMonth()
                }))
                alert.addAction(UIAlertAction(title: "重算統計數值", style: .default, handler: { action in
                    self.resetAllSim()
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                askToAddTestStocks()
            }
        } else {    //if stock.isUpdatingPrice == false
            Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(masterViewController.askToRemoveStocks), userInfo: nil, repeats: false)
            self.masterLog ("Timer for askToRemoveStocks in 7s.")

        }

    }
    
    func delayAndAskToRemoveAgain(_ target:String){
        let noRemove = UIAlertController(title: "暫停\(target)", message: "等網路作業結束一會兒，\n會再詢問是否要\(target)。", preferredStyle: UIAlertController.Style.alert)
        noRemove.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
            Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(masterViewController.askToRemoveStocks), userInfo: nil, repeats: false)
            self.masterLog ("Timer for askToRemoveStocks in 7s.")
            
        }))
        self.present(noRemove, animated: true, completion: nil)

    }


    func removeAllStocks() {
        if self.stock.isUpdatingPrice == false {
            self.lockUI("移除全部股群")
            self.globalQueue().addOperation {
                self.stock.removeAllStocks()
                OperationQueue.main.addOperation {
                    self.unlockUI()
                    self.stock.setupPriceTimer(mode:"all", delay:3)
                    self.askToAddTestStocks()
                }
            }
        } else {
            delayAndAskToRemoveAgain("移除股群")
        }
        

    }
    
    func deleteAllPrices() {
        if self.stock.isUpdatingPrice == false {
            self.lockUI("刪除全部股價")
            self.initSummary()
            globalQueue().addOperation {
                self.stock.deleteAllPrices()
                OperationQueue.main.addOperation {
                    self.unlockUI()
                    self.stock.setupPriceTimer(mode:"all", delay:3)
                    self.askToAddTestStocks()
                }
            }
        } else {
            delayAndAskToRemoveAgain("刪除股價")
        }
        
    }


    func deleteOneMonth() {
        if self.stock.isUpdatingPrice == false {
            self.lockUI("刪除1個月股價")
            globalQueue().addOperation {
                self.stock.deleteOneMonth()
                OperationQueue.main.addOperation {
                    self.unlockUI()
                    self.stock.setupPriceTimer(mode:"all", delay:3)
                    self.askToAddTestStocks()
                }
            }
        } else {
            delayAndAskToRemoveAgain("刪除股價")
        }

    }

    func resetAllSim() {
        if self.stock.isUpdatingPrice == false {
            self.lockUI("清除統計數值")
            globalQueue().addOperation {
                self.stock.resetAllSimUpdated()
                OperationQueue.main.addOperation {
                    self.unlockUI()
                    self.stock.setupPriceTimer(mode:"all", delay:3)
                    self.askToAddTestStocks()
                }
            }
        } else {
            delayAndAskToRemoveAgain("重算數值")
        }

    }

    @objc func askToAddTestStocks() {
        self.defaults.set(false, forKey: "resetStocks") //到這裡就是之前已經完成刪除股群及價格或重算數值的作業了
        if self.stock.isUpdatingPrice == false {
            globalQueue().addOperation {
                if self.defaults.bool(forKey: "willAddStocks") { //self.willLoadSims.count > 0 {
                    let textMessage = "要載入哪類股群？\n（50股要下載好一會兒喔）"
                    let alert = UIAlertController(title: "載入股群", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { action in
                        self.defaults.set(false, forKey: "willAddStocks")
                        self.stock.setupPriceTimer(mode:"all")
                    }))
                    alert.addAction(UIAlertAction(title: "測試5股群", style: .default, handler: { action in
                        self.addTestStocks("Test5")
                    }))
                    alert.addAction(UIAlertAction(title: "測試10股群", style: .default, handler: { action in
                        self.addTestStocks("Test10")
                    }))
                    alert.addAction(UIAlertAction(title: "測試50股群", style: .default, handler: { action in
                        self.addTestStocks("Test50")
                    }))
                    alert.addAction(UIAlertAction(title: "台灣50股群", style: .default, handler: { action in
                        self.addTestStocks("TW50")
                    }))
                    alert.addAction(UIAlertAction(title: "*台灣加權指數", style: .default, handler: { action in
                        self.addTestStocks("t00")
                    }))
                    self.present(alert, animated: true, completion: nil)

                } else {
                    if self.stock.needPriceTimer() || self.stock.needModeALL {
                        //==================== setupPriceTimer ====================
                        //事先都沒有指定什麼，就可以開始排程下載新股價
                        let realtimeOnly:Bool = !self.stock.needModeALL && self.stock.timePriceDownloaded.compare(twDateTime.time0900(delayMinutes:5)) == .orderedDescending
                        var timeDelay:TimeInterval = 1
                        if self.stock.isUpdatingPrice {
                            timeDelay = 30
                        } else if self.stock.timePriceDownloaded.timeIntervalSinceNow > -300 && realtimeOnly {
                            timeDelay = 300 + self.stock.timePriceDownloaded.timeIntervalSinceNow
                        } else if self.stock.versionLast == "" {
                            timeDelay = 0
                        } else if self.stock.versionLast != self.stock.versionNow {
                            timeDelay = 10
                        } else {
                            timeDelay = 3
                        }

                        if realtimeOnly {
                            self.masterLog("set <realtime> priceTimer in \(timeDelay)s.\n")
                            self.stock.setupPriceTimer(mode:"realtime", delay:timeDelay)
                        } else {
                            self.masterLog("set <all> priceTimer in \(timeDelay)s.\n")
                            self.stock.setupPriceTimer(mode:"all", delay:timeDelay)
                        }
                    } else {
                        self.masterLog("no priceTimer.\n")
                        self.showPrice()
                    }
                }

            }
        } else {    //if self.stock.isUpdatingPrice == false
            Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(masterViewController.askToAddTestStocks), userInfo: nil, repeats: false)
            self.masterLog ("Timer for askToAddTestStocks in 7s.")


        }

    }



    func addTestStocks(_ group:String) {
        
        if self.stock.isUpdatingPrice == false {
            self.masterLog("addTestStocks: \(group)")
            self.stock.addTestStocks(group)
            self.defaults.set(false, forKey: "willAddStocks")
            self.defaults.removeObject(forKey: "dateStockListDownloaded")   //清除日期以強制importFromDictionary()
            self.stock.setupPriceTimer(mode:"all")
        } else {
            self.masterLog("delay: addTestStocks: \(group)")
            let noRemove = UIAlertController(title: "暫停載入股群", message: "等網路作業結束一會兒，\n會再詢問是否要載入。", preferredStyle: UIAlertController.Style.alert)
            noRemove.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(masterViewController.askToAddTestStocks), userInfo: nil, repeats: false)
                self.masterLog ("Timer for askToAddTestStocks in 7s.")
                
            }))
            self.present(noRemove, animated: true, completion: nil)
        }

    }





    func checkStocksCopy() {
        self.setProgress(0)
        if let _ = self.sortedStocksCopy {     //有沒有改動股群清單，或刪除又新增而使willUpdateAllSim為true？
            var eq:Bool = true
            for s in stock.sortedStocks {  //刪除的不用理，新增的或willUpdateAllSim才要更新
                if !self.sortedStocksCopy!.contains(where: {$0.id == s.id}) || stock.simPrices[s.id]!.willUpdateAllSim {
                    eq = false
                    if s.id == stock.simId {
//                        initSummary()   //而且主畫面是要切換到新代號，就先改股票名稱標題
                        showPrice()     //主畫面先切換到新代號
                    }
                    break
                }
            }

            if eq == false {    //改動了要去抓價格
                stock.setupPriceTimer(mode: "all")
//            } else {
//                if self.simIdCopy != "" && self.simIdCopy != stock.simId {
//                    showPrice()
//                }
            }


            self.sortedStocksCopy = nil
            self.simIdCopy = ""
        }
        
    }























    @IBAction func uiSwipeLeft(_ sender: UISwipeGestureRecognizer) {
        if self.stock.isUpdatingPrice == false {
            if sender.direction == UISwipeGestureRecognizer.Direction.left {
                if stock.shiftRight() {
                    showPrice()
                }
            } else if sender.direction == UISwipeGestureRecognizer.Direction.right {
                if stock.shiftLeft() {
                    showPrice()
                }
            }
        }
    }


    var PanX:Int = 0
    @IBAction func uiPanGesture(_ sender: UIPanGestureRecognizer) {
        if stock.isUpdatingPrice == false {
            switch sender.state {
            case .began:
                PanX = 0
            case .changed:
                let theOldX = PanX
                let theNewX = Int(round(sender.translation(in: view).x / 40))
                if theOldX != theNewX {
                    let movedX = theNewX - theOldX
                    if movedX > 0 { //向右拖曳
//                        let _ = stock.shiftLeft()
                        if stock.shiftLeft() {
                            showPrice()
                        }
                    } else {
//                        let _ = stock.shiftRight()
                        if stock.shiftRight() {
                            showPrice()
                        }
                    }
                    setStockNameTitle(stock.simId)
                    PanX = theNewX
                }
            default:
                if PanX != 0 {
//                    showPrice()
                    tableView.isUserInteractionEnabled = true
                }
            }
        }
    }


    @IBAction func uiSegmentChanged(_ sender: UISegmentedControl) {
        if let t = sender.titleForSegment(at: sender.selectedSegmentIndex) {
            if let Id = stock.segmentId[t] {
                self.showPrice(Id)
            }
        }
    }

    func setSegment() { //這段都應該在main執行
        let segmentCount:Int = self.stock.segment.count
        let countLimit:Int = (self.isPad ? (UIDevice.current.orientation.isLandscape ? 25 : 21) : 7)    //iPhone直7、iPad橫25直21
        let countMid:Int   = (countLimit - 1) / 2
        var IndexFrom:Int = 0
        var IndexTo:Int   = 0
        var simIndex:Int  = 0
        if let sIndex = self.stock.segmentIndex[self.stock.simId] {
            simIndex = sIndex   //畫面目前的Id對照首字的Index
        }
        if segmentCount > countLimit {
            if simIndex <= countMid {
                IndexFrom = 0
                IndexTo   = countLimit - 1
            } else if simIndex >= (segmentCount - countMid) {
                IndexFrom = segmentCount - countLimit
                IndexTo   = segmentCount - 1
            } else {
                IndexFrom = simIndex - countMid
                IndexTo   = simIndex + countMid
            }
        } else if segmentCount > 2 {
            IndexTo = segmentCount - 1
        }
        self.uiSegment.isEnabled = false
        self.uiSegment.isHidden = true
        self.uiSegment.removeAllSegments()
        if IndexTo > 0 && segmentCount == self.stock.segment.count {
            var simN0:String = ""
            if let n0 = self.stock.simName.first {
                simN0 = String(n0)
            }
            let sItems = Array(self.stock.segment[IndexFrom...IndexTo])
            for title in sItems {
                let i = self.uiSegment.numberOfSegments
                self.uiSegment.insertSegment(withTitle: title, at: i, animated: false)
                if title == simN0 {
                    self.uiSegment.selectedSegmentIndex = i
                }
            }
            if self.uiSegment.numberOfSegments > 2 {
                self.uiSegment.isHidden = false
                self.uiSegment.isEnabled = true
                self.uiSegment.sizeToFit()  //可能是iOS12的bug有時不會autosize
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.setSegment()   //iPad橫置時即時切換，最多可顯示25個首字分段按鈕
    }





































    @objc func appNotification(_ notification: Notification) {
        switch notification.name {
        case UIApplication.didBecomeActiveNotification:
            self.masterLog ("=== appDidBecomeActive ===")
            if gotDevelopPref == false {
                let refreshTime:Bool = stock.timePriceDownloaded.compare(twDateTime.time1330()) == .orderedAscending && !stock.isTodayOffDay()  //不是休市日
                if defaults.bool(forKey: "removeStocks") || defaults.bool(forKey: "willAddStocks") || refreshTime {
                    navigationController?.popToRootViewController(animated: true)
                }
                getDevelopPref()
            }

        case UIApplication.willResignActiveNotification:
            self.masterLog ("=== appWillResignActive ===\n")
            if self.stock.priceTimer.isValid {
                self.stock.priceTimer.invalidate()
            }
            self.gotDevelopPref = false
//            if self.stock.isUpdatingPrice {
//                self.stock.isUpdatingPrice = false
//                let context = self.getContext()
//                context.rollback()
//                context.reset()
//                self.unlockUI()
//            }
            if !self.stock.simTesting {
                self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
            }
            idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
            if idleTimerWasDisabled {   //如果現在是停止休眠
                disableIdleTimer(false) //則離開前應立即恢復休眠排程
            }
            guard let url = URL(string: "http://mis.twse.com.tw/stock/fibest.jsp?lang=zh_tw") else {return}
            let storage = HTTPCookieStorage.shared
            if let cookies = storage.cookies(for: url) {
                for cookie in cookies {
                    storage.deleteCookie(cookie)
                }
            }
//            HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        default:
            break
        }

    }



    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.masterLog(">>> didReceiveMemoryWarning <<<\n")
        globalQueue().maxConcurrentOperationCount = 1
    }


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.masterLog("=== viewWillAppear ===")
        if idleTimerWasDisabled {   //如果之前有停止休眠
            if self.stock.isUpdatingPrice {
                self.setIdleTimer(timeInterval: -2)  //立即停止休眠
            } else if self.stock.needPriceTimer() {
                self.setIdleTimer(timeInterval: -1)  //有插電則停止休眠，否則120秒後恢復休眠
            } else {
                 self.setIdleTimer(timeInterval: 60)
            }
        }
        self.checkStocksCopy()

    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.masterLog ("=== viewDidAppear ===")

    }

    var idleTimerWasDisabled:Bool = false
    override func viewWillDisappear(_ animated: Bool) {
        self.masterLog("=== viewWillDisappear ===")
        idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        if idleTimerWasDisabled {   //如果現在是停止休眠
            disableIdleTimer(false) //則離開前應立即恢復休眠排程
        }

    }


    @IBAction func uiDoubleTap(_ sender: UITapGestureRecognizer) {
        if let _ = fetchedResultsController.fetchedObjects {
            if fetchedResultsController.fetchedObjects!.count > 0 {
                let indexPath:IndexPath = IndexPath(row: 0, section: 0)
                tableView.scrollToRow(at: indexPath, at: .none, animated: true)
            }
        }
    }


    @IBAction func uiTripleTap(_ sender: UITapGestureRecognizer) {
        if let _ = fetchedResultsController.fetchedObjects {
            if fetchedResultsController.fetchedObjects!.count > 0 {
                let firstPrice = fetchedResultsController.fetchedObjects!.last as! Price //最後1筆，也就是最早的股價
                if let indexPath = fetchedResultsController.indexPath(forObject: firstPrice) {
                    tableView.scrollToRow(at: indexPath, at: .none, animated: true)
                }
            }
        }
    }



    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "segueSetting" {
            if let _ = stock.simPrices[stock.simId] {
                return true
            } else {
                return false
            }
        }
        return true
    }


    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var identifier:String
        if let _ = segue.identifier {
            identifier = segue.identifier!
        } else {
            identifier = ""
        }
        switch identifier {
        case "segueToStockList":
            self.masterLog ("=== segueToStockList ===")

            if let stockView = segue.destination as? stockViewController {
                self.simIdCopy = stock.simId
                self.sortedStocksCopy = stock.sortStocks()
                stockView.masterUI = self

                let backItem = UIBarButtonItem()
                backItem.title = ""
                navigationItem.backBarButtonItem = backItem
            }
        case "segueStockPicker":
            if let pickerView = segue.destination as? pickerViewController {
                self.simIdCopy = stock.simId
                pickerView.masterUI = self
                pickerView.popoverPresentationController?.delegate = self
                if let sourceView = pickerView.popoverPresentationController?.sourceView {
                    pickerView.popoverPresentationController?.sourceRect = sourceView.bounds
                }

            }
        case "segueSetting":
            if let settingView = segue.destination as? settingViewController {
                if let sim = stock.simPrices[stock.simId] {
                    simPriceCopy = stock.copySimPrice(sim)    //保存未變動前的單股設定
                    settingView.sim = sim
                }
                settingView.popoverPresentationController?.delegate = self
                if let sourceView = settingView.popoverPresentationController?.sourceView {
                    settingView.popoverPresentationController?.sourceRect = sourceView.bounds
                }

            }
        default:
            break
        }
    }





























//
//
//
//
//
//
//
//
//
//
//
//
//
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// ========== updatePrice ========
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//    
//

    let dispatchGroupWaitForPrices:DispatchGroup = DispatchGroup()
    let dispatchGroupWaitForRemoves:DispatchGroup = DispatchGroup()

    // ********** 模擬參數 **********
    var simPriceCopy:simPrice?
    var simSettingChangedCopy:simPrice?
    var simIdCopy:String?
    var sortedStocksCopy:[(id:String,name:String)]?

    func lockUI(_ message:String="") {
        if stock.priceTimer.isValid {
            stock.priceTimer.invalidate()
        }
        self.messageWithTimer(message,seconds: 0)
        uiProfitLoss.textColor    = UIColor.lightGray
        uiInformation.isEnabled   = false
        uiBarAdd.isEnabled        = false
        uiBarAction.isEnabled     = false
        uiBarRefresh.isEnabled    = false    //先lock沒錯
        uiSetting.isEnabled       = false
        uiMoneyChanged.isEnabled  = false
        uiSimReversed.isEnabled   = false
        uiStockName.isEnabled     = false
        uiRightButton.isEnabled   = false
        uiLeftButton.isEnabled    = false
        uiSegment.isEnabled       = false
        refreshControl.endRefreshing()
        if let rows = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: rows, with: .fade)   //讓加碼按鈕失效
        }
        defaults.set(true, forKey: "locked")
        self.masterLog("lockAll...\(message)")
        self.setIdleTimer(timeInterval: -2)     //立即停止休眠，即使沒有插電




    }

    func unlockUI(_ message:String="") { //上層呼叫時要確保是在main thread被執行
        self.uiProfitLoss.textColor    = UIColor.darkGray
        self.uiBarAdd.isEnabled        = true
        self.uiBarAction.isEnabled     = true
        self.uiBarRefresh.isEnabled    = true
        self.uiInformation.isEnabled   = true
        self.uiSetting.isEnabled       = true
        self.uiMoneyChanged.isEnabled  = true
        self.uiSimReversed.isEnabled   = true
        self.uiStockName.isEnabled     = true
        self.uiRightButton.isEnabled   = true
        self.uiLeftButton.isEnabled    = true
        self.uiSegment.isEnabled       = true
        if let rows = self.tableView.indexPathsForVisibleRows {
            self.tableView.reloadRows(at: rows, with: .fade)   //讓加碼按鈕生效
        }
        self.setProgress(1)
        self.setProgress(0)
        defaults.set(false, forKey: "locked")
        self.showPrice()
        if message.count > 0 {
            self.messageWithTimer(message,seconds: 10)
            self.masterLog("unlock: \(message)")
        } else {
            self.uiMessageClear()
            self.masterLog("unlock.")
        }

        if stock.versionLast < stock.versionNow && message != "" { //含versionLast == "" 的時候
            goToReleaseNotes()
            stock.versionLast = stock.versionNow
        }
        reportToLINE()
        self.setIdleTimer(timeInterval: 60) //60秒後恢復休眠排程

    }

    func goToReleaseNotes() {
        if self.stock.simTesting {
            return
        }
        let textMessage = "前往開發網站查看\n" + stock.versionNow + "版的變更說明？"
        let alert = UIAlertController(title: "Release Notes", message: textMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
            if let URL = URL(string: "https://sites.google.com/site/appsimStock/ban-ben-shuo-ming") {
                UIApplication.shared.open(URL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
            }
        }))
        self.present(alert, animated: true, completion: nil)

    }

    var timeReported:Date = Date.distantPast
    var reportCopy:String = ""
    func reportToLINE(oneTimeReport:Bool=false) {
        if stock.simTesting == false && lineReport {
            if let _ = self.bot?.userProfile {
                var closedReport:Bool = false
                var inReportTime:Bool = false
                if !oneTimeReport {
                    let todayNow = Date()
                    let time0920:Date = twDateTime.timeAtDate(todayNow, hour: 09, minute: 20)
                    let time1020:Date = twDateTime.timeAtDate(todayNow, hour: 10, minute: 20)
                    let time1120:Date = twDateTime.timeAtDate(todayNow, hour: 11, minute: 20)
                    let time1220:Date = twDateTime.timeAtDate(todayNow, hour: 12, minute: 20)
                    let time1320:Date = twDateTime.timeAtDate(todayNow, hour: 13, minute: 20)
                    let time1335:Date = twDateTime.time1330(todayNow, delayMinutes: 5)

                    let inMarketingTime:Bool = !stock.todayIsNotWorkingDay && twDateTime.marketingTime(todayNow)
                    inReportTime = inMarketingTime && (
                        (todayNow.compare(time0920) == .orderedDescending && self.timeReported.compare(time0920) == .orderedAscending) ||
                            (todayNow.compare(time1020) == .orderedDescending && self.timeReported.compare(time1020) == .orderedAscending) ||
                            (todayNow.compare(time1120) == .orderedDescending && self.timeReported.compare(time1120) == .orderedAscending) ||
                            (todayNow.compare(time1220) == .orderedDescending && self.timeReported.compare(time1220) == .orderedAscending) ||
                            (todayNow.compare(time1320) == .orderedDescending && self.timeReported.compare(time1320) == .orderedAscending))
                    closedReport = !stock.todayIsNotWorkingDay && todayNow.compare(time1335) == .orderedDescending && self.timeReported.compare(time1335) == .orderedAscending
                }
                if (inReportTime || closedReport || oneTimeReport) {
                    //以上3種時機：盤中時間、收盤日報、日報測試
                    let suggest = stock.composeSuggest(isTest:oneTimeReport)
                    let report = suggest + stock.composeReport(isTest:oneTimeReport,withTitle: (suggest.count > 0 ? false : true))
                    if report.count > 0 && (report != self.reportCopy || !inReportTime)  {
                        if isPad {  //我用iPad時為特殊情況，日報是送到小確幸群組
                            self.bot!.pushTextMessages(to: "team", message: report)
                        } else {    //其他人是從@Line送給自己的帳號
                            self.bot!.pushTextMessages(message: report)
                        }
                        self.timeReported = defaults.object(forKey: "timeReported") as! Date
                        if self.timeReported.compare(twDateTime.time1330()) != .orderedAscending {
                            self.timeReported = Date()  //收盤後的1335是最後一次日報截止時間
                            self.defaults.set(self.timeReported, forKey: "timeReported")
                        }
                        self.reportCopy = report
                    }

                }
            }
        }
    }

















    var idleTimer:Timer?
    func setIdleTimer(timeInterval:TimeInterval) {  //幾秒後恢復休眠排程
        //  UIDevice.current.batteryState == .unplugged
        if timeInterval == 0 {
            disableIdleTimer(false)     //立即恢復休眠
        } else if timeInterval < 0  {
            if timeInterval == -1 && UIDevice.current.batteryState == .unplugged {
                self.idleTimer = Timer.scheduledTimer(timeInterval: 120, target: self, selector: #selector(masterViewController.disableIdleTimer), userInfo: nil, repeats: false)
                self.masterLog("idleTimer in \(120)s.\n") //沒插電延後120秒恢復休眠排程
            }  else {
                disableIdleTimer(true)      //立即停止休眠
                if let _ = idleTimer {
                    idleTimer?.invalidate()
                    idleTimer = nil
                    self.masterLog("no idleTimer.\n")
                }
            }
        } else {
            self.idleTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(masterViewController.disableIdleTimer), userInfo: nil, repeats: false)
            self.masterLog("idleTimer in \(timeInterval)s.\n") //恢復休眠排程
        }
    }

    @objc func disableIdleTimer(_ on:Bool=false) {
        UIApplication.shared.isIdleTimerDisabled = on    //預設參數是啟動休眠
    }

    @objc func uiMessageClear() {
        uiMessage.text = ""
    }

    func messageWithTimer(_ text:String="",seconds:Int=10) {  //timer是0秒，表示不設timer來清除訊息
        self.uiMessage.text = text
        if seconds > 0 {
            Timer.scheduledTimer(timeInterval: Double(seconds), target: self, selector: #selector(masterViewController.uiMessageClear), userInfo: nil, repeats: false)
        }

    }

    func setProgress(_ progress:Float, message:String?="") { //progress == -1 表示沒有執行什麼，跳過
        let animate:Bool = (progress > 0 ? true : false)
        let hidden:Bool = (progress == 0 ? true : false)
        if self.uiProgress.isHidden != hidden {
            self.uiProgress.isHidden = hidden
        }
        self.uiProgress.setProgress(progress, animated: animate)
        if let _ = message {
            if message!.count > 0 {
                self.messageWithTimer(message!,seconds:0)
            }
        }
    }





























    
    func showPrice(_ Id:String?=nil) {
        //fetch之前要先save不然就會遇到以下error:
        //CoreData: error:  API Misuse: Attempt to serialize store access on non-owning coordinator
        if let _ = Id {
            let _ = self.stock.setSimId(newId: Id!)
        }
        OperationQueue.main.addOperation {
            self.updateSummary()
            self.saveContext()
            self.setProgress(0)
            self.fetchPrice()
            self.updateSummary()
        }

    }

    func fetchPrice() {
        _fetchedResultsController = nil
        //帶入資料庫的起迄交易日期
        if fetchedResultsController.fetchedObjects!.count > 0 {
            let fetchedCount = fetchedResultsController.fetchedObjects?.count
            self.masterLog("*\(stock.simId) \(stock.simName) \tfetchPrice: \(fetchedCount!)筆")

        } else {
            self.masterLog("\(stock.simId) \(stock.simName) \tfetchPrice... no objects.")

        }
        tableView.reloadData()

    }

    func initSummary() {
        uiMessageClear()
        setStockNameTitle()
        uiSetting.setTitle(String(format:"本金%.f萬元 期間%.1f年",0,0), for: UIControl.State())
        uiProfitLoss.text = formatProfitLoss(simPL: 0,simROI: 0, qtyInventory: 0)
        uiMoneyChanged.isHidden = true
        uiSimReversed.isHidden = true
    }

    func setStockNameTitle(_ id:String="") {
        var newId:String = ""
        if id == "" {
            newId = stock.simId
        } else {
            newId = id
        }
        if let sim = stock.simPrices[newId] {
            uiStockName.setTitle(stock.simId + " " + sim.name, for: UIControl.State())
        }
    }

    //更新結餘標示，在runAllsimPrice之後執行
    func updateSummary() {
        setStockNameTitle()

        if let last = stock.simPrices[stock.simId]?.getPropertyLast() {
            if let roi = stock.simPrices[stock.simId]?.ROI() {

                uiProfitLoss.text = formatProfitLoss(simPL:roi.pl, simROI:roi.roi, qtyInventory: last.qtyInventory)
                var moneyTitle:String = String(format:"本金%.f萬元",stock.simPrices[stock.simId]!.initMoney)
                if stock.simPrices[stock.simId]!.maxMoneyMultiple > 1 {
                    uiMoneyChanged.isHidden = false
                    moneyTitle = moneyTitle + String(format:"x%.f",stock.simPrices[stock.simId]!.maxMoneyMultiple)
                } else {
                    uiMoneyChanged.isHidden = true
                }
                if stock.simPrices[stock.simId]!.simReversed {
                    uiSimReversed.isHidden = false
                } else {
                    uiSimReversed.isHidden = true
                }
                let timeTitle:String = String(format:"期間%.1f年",roi.years)
                uiSetting.setTitle((moneyTitle + " " + timeTitle), for: UIControl.State())

                return
            }
        }

        initSummary()
        return

    }

    func formatProfitLoss(simPL:Double,simROI:Double,qtyInventory:Double) -> String {
        var textString:String = ""
        var formatTxt = ""
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency   //貨幣格式
        numberFormatter.maximumFractionDigits = 0
        var textPL:String = ""
        if let t = numberFormatter.string(for: simPL) {
            textPL = t
        }
        formatTxt = "累計損益:%@"
        if qtyInventory > 0 {
            formatTxt = "損益含未實現:%@"
        }

        formatTxt = formatTxt + " 平均年報酬率:%.1f%%"

        textString = String(format:formatTxt,textPL,simROI)

        return textString
    }




















    // Export function

    func saveAndExport(_ id: String) {
        if stock.sortedStocks.count > 2 {
            let textMessage = "選擇範圍和內容？"
            let alert = UIAlertController(title: "匯出CSV檔案"+(lineReport ? "或傳送日報" : ""), message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "匯出全部股的CSV", style: .default, handler: { action in
                self.csvFiles()
            }))
            alert.addAction(UIAlertAction(title: "只要\(stock.simName)的CSV", style: .default, handler: { action in
                self.csvFiles(id)
            }))
            if lineReport {
                alert.addAction(UIAlertAction(title: "送出LINE日報", style: .default, handler: { action in
                    self.reportToLINE(oneTimeReport: true)
                }))
            }
            self.present(alert, animated: true, completion: nil)
        } else {
            self.csvFiles(id)
        }
    }

    func csvFiles (_ target:String="all") {
        var fileURLs:[URL] = []
        var filePaths:[String] = []

        func csv(id:String) -> String {
            let dtStart:String = twDateTime.stringFromDate(self.stock.simPrices[id]!.dateStart, format: "yyyyMMdd")
            let dtEnd:String = twDateTime.stringFromDate((self.stock.simPrices[id]!.dateEndSwitch ? self.stock.simPrices[id]!.dateEnd : Date()), format: "yyyyMMdd")
            let fileName = id + self.stock.simPrices[id]!.name + "_" + dtStart + "-" + dtEnd + ".csv"
            let filePath = NSTemporaryDirectory().appending(fileName)
            let csv:String = self.stock.simPrices[id]!.exportString(self.extVersion)
            do {
                try csv.write(toFile: filePath, atomically: true, encoding: .utf8)
            } catch {
                self.masterLog("error in saveAndExport\n\(error)")
            }

            return filePath

        }

        self.globalQueue().addOperation {
            if target == "all" {
                OperationQueue.main.addOperation {
                    self.lockUI("檔案壓縮中")
                    self.uiProgress.setProgress(0, animated: false)
                    self.uiProgress.isHidden = false
                }
                let timeStamp = Date()

                for (offset: index,element: (id: id,name: _)) in self.stock.sortedStocks.enumerated() {
                    filePaths.append(csv(id: id))
                    let p:Float = Float(index + 1) / Float(self.stock.sortedStocks.count + 1)
                    OperationQueue.main.addOperation {
                        self.uiProgress.setProgress(p, animated: true)
                    }
                    self.masterLog("*csv \(index + 1)/\(self.stock.sortedStocks.count) \(id) \(self.stock.simPrices[id]!.name)")
                }
                filePaths.append(self.csvSummaryFile(timeStamp: timeStamp))
                filePaths.append(self.csvMonthlyRoiFile(timeStamp: timeStamp))

                let zipName = twDateTime.stringFromDate(timeStamp, format: "yyyyMMdd_HHmmssSSS") + ".zip"
                let zipPath = NSTemporaryDirectory().appending(zipName)
                SSZipArchive.createZipFile(atPath: zipPath, withFilesAtPaths: filePaths)

                fileURLs = [URL(fileURLWithPath: zipPath)]
            } else {
                OperationQueue.main.addOperation {
                    self.lockUI("檔案匯出中")
                }
                fileURLs = [URL(fileURLWithPath: csv(id: target))]

            }
            OperationQueue.main.addOperation {
                self.exportFiles(fileURLs)
            }

        }

    }


    func exportFiles(_ fileURLs:[URL]) {
        let activityViewController : UIActivityViewController = UIActivityViewController(activityItems: fileURLs, applicationActivities: nil)

        activityViewController.excludedActivityTypes = [
            UIActivity.ActivityType.assignToContact,
            UIActivity.ActivityType.addToReadingList,
            UIActivity.ActivityType.saveToCameraRoll,
            UIActivity.ActivityType.openInIBooks,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToTwitter,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.postToFacebook,
            UIActivity.ActivityType.postToTencentWeibo,
            UIActivity.ActivityType.postToWeibo
        ]

        activityViewController.popoverPresentationController?.sourceView = self.view

        self.present(activityViewController, animated: true, completion: {
            self.sortedStocksCopy = self.stock.sortStocks() //作弊讓master view will apear時不再updatePrices
            self.unlockUI()
        })


     }




    func csvSummaryFile(timeStamp:Date) -> String {
        let fileName = twDateTime.stringFromDate(timeStamp, format: "_累計年平均_yyyyMMdd_hhmmssSSS") + ".csv"
        let filePath = NSTemporaryDirectory().appending(fileName)

        var text = ""
        text  = self.stock.csvSummary() //<<<<<<<<<< 產出csv內容
        text += "\n匯出時間: \(twDateTime.stringFromDate(timeStamp, format: "yyyy/MM/dd HH:mm:ss.SSS"))\n"
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            self.masterLog("error in csvSummaryFile\n\(error)")
        }
        self.masterLog("*csv \(fileName)")
        OperationQueue.main.addOperation {
            self.uiProgress.setProgress(1, animated: true)
        }
        return filePath

    }

    func csvMonthlyRoiFile(timeStamp:Date) -> String {
        let fileName = twDateTime.stringFromDate(timeStamp, format: "_逐月已實現_yyyyMMdd_hhmmssSSS") + ".csv"
        let filePath = NSTemporaryDirectory().appending(fileName)

        var text = ""
        text  = self.stock.csvMonthlyRoi()  //<<<<<<<<<< 產出csv內容，不指定起迄日代表模擬期間全部
        text += "\n匯出時間: \(twDateTime.stringFromDate(timeStamp, format: "yyyy/MM/dd HH:mm:ss.SSS"))\n"
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            self.masterLog("error in csvSummaryFile\n\(error)")
        }
        self.masterLog("*csv \(fileName)")
        OperationQueue.main.addOperation {
            self.uiProgress.setProgress(1, animated: true)
        }
        return filePath

    }
































    // ===== Table View =====

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        let sections = (fetchedResultsController.sections?.count ?? 0)
        return sections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let _ = fetchedResultsController.sections {
            let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
            return sectionInfo.numberOfObjects
        }
        return 0


    }



    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cellPrice", for: indexPath) as! priceCell
        cell.masterView = self  //cellDelegate
        
        let price = fetchedResultsController.object(at: indexPath) as! Price


        cell.uiDate.adjustsFontSizeToFitWidth = true
        cell.uiTime.adjustsFontSizeToFitWidth = true
        cell.uiClose.adjustsFontSizeToFitWidth = true
        cell.uiDivCash.adjustsFontSizeToFitWidth = true
        cell.uiSimTrans1.adjustsFontSizeToFitWidth = true
        cell.uiSimUnitCost.adjustsFontSizeToFitWidth = true
        cell.uiSimDays.adjustsFontSizeToFitWidth = true
        cell.uiSimIncome.adjustsFontSizeToFitWidth = true
        cell.uiSimROI.adjustsFontSizeToFitWidth = true
        cell.uiMA20.adjustsFontSizeToFitWidth = true
        cell.uiMA60.adjustsFontSizeToFitWidth = true
        cell.uiK.adjustsFontSizeToFitWidth = true
        cell.uiD.adjustsFontSizeToFitWidth = true
        cell.uiJ.adjustsFontSizeToFitWidth = true
        cell.uiOpen.adjustsFontSizeToFitWidth = true
        cell.uiHigh.adjustsFontSizeToFitWidth = true
        cell.uiLow.adjustsFontSizeToFitWidth = true
        cell.uiSimMoney.adjustsFontSizeToFitWidth = true
        cell.uiSimCost.adjustsFontSizeToFitWidth = true
        cell.uiMoneyBuy.adjustsFontSizeToFitWidth = true
        cell.uiSimUnitCost.adjustsFontSizeToFitWidth = true
        cell.uiSimUnitDiff.adjustsFontSizeToFitWidth = true
        cell.uiSimCost.adjustsFontSizeToFitWidth = true
        cell.uiSimPL.adjustsFontSizeToFitWidth = true
        cell.uiLabelPL.adjustsFontSizeToFitWidth = true
        cell.uiLabelClose.adjustsFontSizeToFitWidth = true
        cell.uiLabelCost.adjustsFontSizeToFitWidth = true
        cell.uiLabelUnitCost.adjustsFontSizeToFitWidth = true
        cell.uiLabelUnitDiff.adjustsFontSizeToFitWidth = true
        cell.uiLabelIncome.adjustsFontSizeToFitWidth = true
        cell.uiRank.adjustsFontSizeToFitWidth = true
        cell.uiMacdOsc.adjustsFontSizeToFitWidth = true
        cell.uiOscHL.adjustsFontSizeToFitWidth = true
        cell.uiPrice60HighLow.adjustsFontSizeToFitWidth = true
        cell.uiBaseK.adjustsFontSizeToFitWidth = true
        cell.uiUpdatedBy.adjustsFontSizeToFitWidth = true
        cell.uiMa60DiffHL.adjustsFontSizeToFitWidth = true
        cell.uiMa20DiffHL.adjustsFontSizeToFitWidth = true
        



        cell.uiDate.text = twDateTime.stringFromDate(price.dateTime, format: "yyyy/MM/dd")
        cell.uiTime.text = twDateTime.stringFromDate(price.dateTime, format: "EEE HH:mm:ss")
        cell.uiClose.text = String(format:"%.2f",price.priceClose)
        
        cell.uiClose.textColor = simRuleColor(price.simRule)    //收盤價的顏色根據可買規則分類


        if twDateTime.marketingTime(price.dateTime) {
            cell.uiLabelClose.text = "成交價"
            cell.uiTime.textColor = UIColor.orange
        } else {
            cell.uiLabelClose.text = "收盤價"
            cell.uiTime.textColor = UIColor.black
        }


        switch price.priceUpward {
        case "▲","▵","up":
            cell.uiLabelClose.text = cell.uiLabelClose.text! + price.priceUpward
            cell.uiLabelClose.textColor = UIColor.red
        case "▼","▿","down":
            cell.uiLabelClose.text = cell.uiLabelClose.text! + price.priceUpward
            cell.uiLabelClose.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        default:
            cell.uiLabelClose.textColor = UIColor.black
        }
        cell.uiDivCash.text = ""
        cell.uiDivCash.isHidden = true
        cell.uiConsDivCash.constant = 0
        if price.dividend == 0 {
            cell.uiLabelClose.text = cell.uiLabelClose.text! + "\n[除權息]"
            if let amt = self.stock.simPrices[self.stock.simId]?.dateDividend[twDateTime.startOfDay(price.dateTime)] {
                if amt > 0 {
                    cell.uiDivCash.text = String(format:"(+%.2f)",amt)
                    cell.uiDivCash.isHidden = false
                    cell.uiConsDivCash.constant = 4
                }
            }
        }
//        //為測試暫時顯示成交量
//        cell.uiDivCash.text = String(format:"(+%.2f)",price.priceVolume)
//        cell.uiDivCash.isHidden = false
//        cell.uiConsDivCash.constant = 4

        if price.qtyBuy != 0 {
            cell.uiSimTrans1.text = "買"
            cell.uiSimTrans1.textColor = UIColor.red
            cell.uiSimTrans2.text = String(format:"%.f",price.qtyBuy)
            cell.uiSimTrans2.textColor = UIColor.red
        } else if price.qtySell != 0 {
            cell.uiSimTrans1.text = "賣"
            cell.uiSimTrans1.textColor = UIColor.blue
            cell.uiSimTrans2.text = String(format:"%.f",price.qtySell)
            cell.uiSimTrans2.textColor = UIColor.blue
        } else if price.qtyInventory != 0 {
            cell.uiSimTrans1.text = "餘"
            cell.uiSimTrans1.textColor = UIColor.brown
            cell.uiSimTrans2.text = String(format:"%.f",price.qtyInventory)
            cell.uiSimTrans2.textColor = UIColor.brown
        } else {
            cell.uiSimTrans1.text = ""
            cell.uiSimTrans2.text = ""
            cell.uiSimTrans1.textColor = UIColor.black
            cell.uiSimTrans2.textColor = UIColor.black
        }

        if price.simDays != 0 {
            cell.uiSimDays.text = String(format:"%.f天",price.simDays)
        } else {
            cell.uiSimDays.text = ""
        }

        if price.qtyInventory != 0 || price.qtySell != 0 {
            cell.uiSimUnitCost.text = String(format:"%.2f",price.simUnitCost)
            cell.uiSimUnitDiff.text = String(format:"%.2f%%",price.simUnitDiff)
            if price.simUnitDiff < -45 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:192/255, blue:0, alpha:1)
            } else if price.simUnitDiff >= -45 && price.simUnitDiff < -35 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:160/255, blue:0, alpha:1)
            } else if price.simUnitDiff >= -35 && price.simUnitDiff < -25 {
                cell.uiSimUnitDiff.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
            } else if price.simUnitDiff > 6.4 && price.simUnitDiff <= 9.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:128/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 9.4 && price.simUnitDiff <= 13.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:160/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 13.4 && price.simUnitDiff <= 16.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:192/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 16.4 && price.simUnitDiff <= 19.4 {
                cell.uiSimUnitDiff.textColor = UIColor(red:224/255, green:0, blue:0, alpha:1)
            } else if price.simUnitDiff > 19.4  {
                cell.uiSimUnitDiff.textColor = UIColor.red
            } else {
                cell.uiSimUnitDiff.textColor = UIColor.darkGray
            }

            cell.uiSimCost.text = String(format:"%.f萬元",price.simCost/10000)
            cell.uiSimCost.isHidden = false
            cell.uiSimUnitCost.isHidden = false
            cell.uiSimUnitDiff.isHidden = false
            cell.uiLabelCost.isHidden = false
            cell.uiLabelUnitCost.isHidden = false
            cell.uiLabelUnitDiff.isHidden = false
            cell.uiTipForQty.isHidden = false
        } else {
            cell.uiSimCost.text = ""
            cell.uiSimUnitCost.text = ""
            cell.uiSimUnitDiff.text = ""
            cell.uiSimCost.isHidden = true
            cell.uiSimUnitCost.isHidden = true
            cell.uiSimUnitDiff.isHidden = true
            cell.uiLabelCost.isHidden = true
            cell.uiLabelUnitCost.isHidden = true
            cell.uiLabelUnitDiff.isHidden = true
            cell.uiTipForQty.isHidden = true
        }
        
        if price.simROI != 0 || price.qtySell != 0 {
            cell.uiSimROI.text = String(format:"%.1f%%",price.simROI)
            cell.uiTipForButton.text = "報酬率"
        } else {
            cell.uiSimROI.text = ""
            cell.uiTipForButton.text = ""
        }


        if price.simIncome != 0 {
            cell.uiSimIncome.text = String(format:"%.f千元",price.simIncome/1000)
            cell.uiSimIncome.isHidden = false
            cell.uiLabelIncome.isHidden = false
        } else {
            cell.uiSimIncome.text = ""
            cell.uiSimIncome.isHidden = true
            cell.uiLabelIncome.isHidden = true
        }

        
        if price.moneyMultiple > 0 {
            if price.moneyMultiple == 1 {
                cell.uiMoneyBuy.text = "本金餘"
            } else {
                cell.uiMoneyBuy.text = String(format:"%.fx本金餘",price.moneyMultiple)
            }
            let buyMoney:Double = price.simBalance //(price.moneyMultiple * stock.simPrices[stock.simId]?.initMoney * 10000) - price.simCost
            cell.uiSimMoney.text = String(format:"%.f萬元",buyMoney/10000)
            if let initMoney = stock.simPrices[stock.simId]?.initMoney {
                let simPL:Double = price.simBalance - (price.moneyMultiple  * initMoney * 10000) + (price.qtyInventory > 0 ? price.simIncome + price.simCost : 0)
                cell.uiSimPL.text = String(format:"%.f千元",simPL/1000)
            } else {
                cell.uiSimPL.text = "0元"
            }
            cell.uiMoneyBuy.isHidden = false
            cell.uiSimMoney.isHidden = false
            cell.uiSimPL.isHidden = false
            cell.uiLabelPL.isHidden = false
        } else {
            cell.uiSimMoney.text = ""
            cell.uiMoneyBuy.text = ""
            cell.uiMoneyBuy.isHidden = true
            cell.uiSimMoney.isHidden = true
            cell.uiSimPL.isHidden = true
            cell.uiLabelPL.isHidden = true
        }


        //以下是cell展開後的欄位

        cell.uiOpen.text = String(format:"%.2f",price.priceOpen)
        cell.uiHigh.text = String(format:"%.2f",price.priceHigh)
        cell.uiLow.text = String(format:"%.2f",price.priceLow)
        cell.uiMA20.text = String(format:"%.2f",price.ma20)
        cell.uiMA60.text = String(format:"%.2f",price.ma60)
        cell.uiMacdOsc.text = String(format:"%.2f",price.macdOsc)
//        cell.uiRank.text = price.ma60Rank
        cell.uiK.text = String(format:"%.2f",price.kdK)
        cell.uiD.text = String(format:"%.2f",price.kdD)
        cell.uiJ.text = String(format:"%.2f",price.kdJ)



        var lastPrice:Price?
        var nextIndexPath = indexPath

        let numberOfRows = fetchedResultsController.sections![indexPath.section].numberOfObjects
        let numberOfSections = fetchedResultsController.sections!.count
        if numberOfRows > 1 && indexPath.row < numberOfRows - 1 {
            nextIndexPath.row += 1
        } else if numberOfSections > 1 && indexPath.section < numberOfSections - 1 {
            nextIndexPath.section += 1
            nextIndexPath.row = 0
        }
        if nextIndexPath != indexPath {
            lastPrice = fetchedResultsController.object(at: nextIndexPath) as? Price
        }

        if let last = lastPrice {
            let priceHighDiff = 100 * (price.priceHigh - last.priceClose) / last.priceClose
            if priceHighDiff > 9 {
                cell.uiHigh.textColor = UIColor.red
                if price.priceHigh > last.priceHigh {
                    cell.uiHigh.text = "▲" + cell.uiHigh.text!
                }
            } else if priceHighDiff >= 6 {
                cell.uiHigh.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                if price.priceHigh > last.priceHigh {
                    cell.uiHigh.text = "▵" + cell.uiHigh.text!
                }
            } else {
                cell.uiHigh.textColor = UIColor.darkGray
            }

            if price.priceLowDiff > 9 {
                cell.uiLow.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
                if price.priceLow < last.priceLow {
                    cell.uiLow.text = "▼" + cell.uiLow.text!
                }
            } else if price.priceLowDiff >= 5 {
                cell.uiLow.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
                if price.priceLow < last.priceLow {
                    cell.uiLow.text = "▿" + cell.uiLow.text!
                }
            } else {
                cell.uiLow.textColor = UIColor.darkGray
            }

        }

        var growing:String = ""
        if price.macd9 != 0 {    //不是最早那一筆
            if price.kdK == price.kMinIn5d {
                growing = "▼"
            } else if price.kdK == price.kMaxIn5d {
                growing = "▲"
            } else if let last = lastPrice {
                if price.kdK > last.kdK {
                    growing = "▵"
                } else if price.kdK < last.kdK {
                    growing = "▿"
                }
            }
        }
        cell.uiK.text = growing + cell.uiK.text!

        growing = ""
        if price.macd9 != 0 {
            if price.macdOsc == price.macdMin9d {
                growing = "▼"
            } else if price.macdOsc == price.macdMax9d {
                growing = "▲"
            } else if let last = lastPrice {
                if price.macdOsc > last.macdOsc {
                    growing = "▵"
                } else if price.macdOsc < last.macdOsc {
                    growing = "▿"
                }
            }
        }
        cell.uiMacdOsc.text = growing + cell.uiMacdOsc.text!


        if price.macdOsc < price.macdOscL {
            cell.uiMacdOsc.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
        } else if price.macdOsc < (price.macdOscL * 0.6) {
            cell.uiMacdOsc.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        } else if price.macdOsc > price.macdOscH {
            cell.uiMacdOsc.textColor = UIColor.red
        } else if price.macdOsc > (price.macdOscH * 0.6) {
            cell.uiMacdOsc.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
        } else {
            cell.uiMacdOsc.textColor = UIColor.darkGray
        }

        //K,D,J的顏色標示
        if (price.kdK > price.k80Base) {
            cell.uiK.textColor = UIColor.red
        } else if (price.kdK) < round(price.k20Base / 2) {
            cell.uiK.textColor = UIColor(red:0, green:192/255, blue:0, alpha:1)
        } else if (price.kdK < price.k20Base) {
            cell.uiK.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiK.textColor = UIColor.darkGray
        }
        if (price.kdD > price.k80Base) {
            cell.uiD.textColor = UIColor.red
        } else if (price.kdD < price.k20Base) {
            cell.uiD.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiD.textColor = UIColor.darkGray
        }
        if (price.kdJ > 100) {
            cell.uiJ.textColor = UIColor.red
        } else if (price.kdJ < -1) {
            cell.uiJ.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
        } else {
            cell.uiJ.textColor = UIColor.darkGray
        }

        //以下是Extension欄位
        if extVersion {

            cell.uiMA20Diff.text = String(format:"%.2f",price.ma20Diff)
            cell.uiMA60Diff.text = String(format:"%.2f",price.ma60Diff)
            cell.uiMADiff.text = String(format:"%.2f",price.maDiff)

            cell.uiMA20Min.text = String(format:"%.2f",price.ma20Min9d)
            cell.uiMA60Min.text = String(format:"%.2f",price.ma60Min9d)
            cell.uiMAMin.text = String(format:"%.2f",price.maMin9d)

            cell.uiMA20Max.text = String(format:"%.2f",price.ma20Max9d)
            cell.uiMA60Max.text = String(format:"%.2f",price.ma60Max9d)
            cell.uiMAMax.text = String(format:"%.2f",price.maMax9d)

            cell.uiMA20Days.text = String(format:"%.f",price.ma20Days)
            cell.uiMA60Days.text = String(format:"%.f",price.ma60Days)
            cell.uiMADays.text = String(format:"%.f",price.maDiffDays)

            if price.ma20Diff < price.ma20L {
                cell.uiMA20Diff.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else if price.ma20Diff > price.ma20H {
                cell.uiMA20Diff.textColor = UIColor.red
            } else {
                cell.uiMA20Diff.textColor = UIColor.darkGray
            }
            if price.ma60Diff < price.ma60L {
                cell.uiMA60Diff.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else if price.ma60Diff > price.ma60H {
                cell.uiMA60Diff.textColor = UIColor.red
            } else {
                cell.uiMA60Diff.textColor = UIColor.darkGray
            }
            if price.ma20Diff == price.ma20Min9d {
                cell.uiMA20Min.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiMA20Min.textColor = UIColor.darkGray
            }
            if price.ma20Diff == price.ma20Max9d {
                cell.uiMA20Max.textColor = UIColor.red
            } else {
                cell.uiMA20Max.textColor = UIColor.darkGray
            }
            if price.ma60Diff == price.ma60Min9d {
                cell.uiMA60Min.textColor = UIColor(red: 0, green:128/255, blue:0, alpha:1)
            } else {
                cell.uiMA60Min.textColor = UIColor.darkGray
            }
            if price.ma60Diff == price.ma60Max9d {
                cell.uiMA60Max.textColor = UIColor.red
            } else {
                cell.uiMA60Max.textColor = UIColor.darkGray
            }


            cell.uiBaseK.text = String(format:"K(%.f,%.f/%.1f)",price.k20Base,price.k80Base,price.kdKZ)
            if self.isPad {
                cell.uiPrice60HighLow.text = String(format:"HL(%.1f,%.1f/%.1f,%.1f)",price.price60HighDiff,price.price60LowDiff,price.price250HighDiff,price.price250LowDiff)
            } else {
                cell.uiPrice60HighLow.text = String(format:"HL(%.1f,%.1f)",price.price60HighDiff,price.price60LowDiff)
            }
            if self.isPad {
                cell.uiOscHL.text = String(format:"OSC(%.2f,%.2f/%.2f,%.2f/%.1f)",price.macdOscL,price.macdOscH,price.macdMin9d,price.macdMax9d,price.macdOscZ)
            } else {
                cell.uiOscHL.text = String(format:"OSC(%.2f,%.2f/%.1f)",price.macdOscL,price.macdOscH,price.macdOscZ)
            }
            let ma20HL:Double = (price.ma20H - price.ma20L == 0 ? 0.5 : price.ma20H - price.ma20L)
            let ma60HL:Double = (price.ma60H - price.ma60L == 0 ? 0.5 : price.ma60H - price.ma60L)
            let ma20MaxHL:Double = (price.ma20Max9d - price.ma20Min9d) / ma20HL
            let ma60MaxHL:Double = (price.ma60Max9d - price.ma60Min9d) / ma60HL
            if self.isPad {
                cell.uiMa20DiffHL.text = String(format:"ma20(%.2f/%.f,%.f)",ma20MaxHL,price.ma20L,price.ma20H)
                cell.uiMa60DiffHL.text = String(format:"ma60(%.2f/%.f,%.f)",ma60MaxHL,price.ma60L,price.ma60H)
            } else {
                cell.uiMa20DiffHL.text = String(format:"ma20(%.2f)",ma20MaxHL)
                cell.uiMa60DiffHL.text = String(format:"ma60(%.2f)",ma60MaxHL)
            }

            cell.uiUpdatedBy.text = price.updatedBy
            switch price.updatedBy {
            case "Google","Yahoo","yahoo","twse":
                cell.uiUpdatedBy.textColor = UIColor.orange
            case "CNYES":
                cell.uiUpdatedBy.textColor = UIColor(red:128/255, green:128/255, blue:0, alpha:1) //黃綠色
            case "TWSE":
                cell.uiUpdatedBy.textColor = UIColor(red:0/255, green:51/255, blue:153/255, alpha:1)
            default:
                cell.uiUpdatedBy.textColor = UIColor.darkGray
            }
            let rules:[String] = ["L","M","N","H","I","J","S","S-"]
            let ruleLevel:String = (rules.contains(price.simRule) ? String(format:"%.f",price.simRuleLevel) : "")
            let ruleS1:String = (price.simRuleBuy.count > 0 && price.simRule.count > 0 ? "/" : "")
            let buyRule:String = price.simRuleBuy + ruleS1 + price.simRule + ruleLevel
            let ruleS2:String = (buyRule.count > 0 ? "," : "")
            cell.uiRank.text = buyRule + ruleS2 + String(format:"%.1f",price.ma60Avg) + "/" + String(format:"%.1f",price.ma60Z) + "/" + String(format:"%.1f",price.priceVolumeZ)


            //Rank的顏色標示
            switch price.ma60Rank {
            case "A":
                cell.uiRank.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
            case "B":
                cell.uiRank.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
            case "C+":
                cell.uiRank.textColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
            case "C":
                cell.uiRank.textColor = UIColor.darkGray
            case "C-":
                cell.uiRank.textColor = UIColor(red: 0, green:64/255, blue:0, alpha:1)
            case "D":
                cell.uiRank.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
            case "E":
                cell.uiRank.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
            default:
                cell.uiRank.textColor = UIColor.black
            }

            if price.simUpdated {
                cell.uiUpdatedBy.backgroundColor = UIColor.clear
            } else {
                cell.uiUpdatedBy.backgroundColor = UIColor.yellow
                cell.uiUpdatedBy.textColor = UIColor.red
            }
        }


        //反轉按鈕
        if self.stock.isUpdatingPrice == false {
            cell.uiSimReverse.isSelected = false
            cell.uiSimReverse.isEnabled = true
            cell.uiSimReverse.isHidden = false
            if price.simReverse == "" {
                cell.uiSimReverse.isHidden = true
            } else if price.simReverse != "無" {
                cell.uiSimReverse.isSelected = true
            }
        } else {
            cell.uiSimReverse.isEnabled = false
            cell.uiSimReverse.isSelected = false
            cell.uiSimReverse.isHidden = false
        }
        if cell.uiSimReverse.isSelected {
            cell.uiSimReverse.tintColor = UIColor.clear
        } else {
            cell.uiSimReverse.tintColor = self.view.tintColor
        }



        //加碼按鈕
        if let button = cell.uiButtonIncrease {
            if price.moneyChange > 0 {
                button.isSelected = true
                button.isHidden = false
                button.tintColor = UIColor.clear
            } else if price.moneyRemark != "+" { //既未曾加碼也沒有建議加碼
                button.isSelected = false
                cell.uiButtonIncrease.isHidden = true
                button.tintColor = self.view.tintColor
            } else {
                button.isSelected = false
                button.isHidden = false
                button.tintColor = self.view.tintColor
            }
            if stock.isUpdatingPrice == false {
                button.isEnabled = true
            } else {
                button.isEnabled = false
            }
        }


        return cell




    }





    func simRuleColor(_ simRule:String) -> UIColor {
        //可買規則分色
        var sRule:String = ""
        var rColor:UIColor = UIColor.darkGray
        if let r = simRule.first {
            sRule = String(describing: r)
        }
        
        switch sRule {
        case "H":   //追高
            rColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
        case "L":   //承低
            rColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
        case "X":   //測試
            rColor = UIColor.blue
        case "":    //沒有、不變
            rColor = UIColor.black
        default:
            break   //暫停、待變
        }
        
        return rColor

    }




    //加減碼按鈕的行動
    func moneyChanging (_ sender:UITableViewCell,changeFactor:Double) {
        if let indexPath = self.tableView.indexPath(for: sender) {
            let price = fetchedResultsController.object(at: indexPath) as! Price
            var change:Double = 0
            if price.moneyChange == 0 {   //還沒增減
                if price.moneyMultiple > 1 {
                    if changeFactor == -1 { //已經超過1個資本，應該要減到1個資本
                        change = changeFactor * (price.moneyMultiple - 1)
                    } else if changeFactor == 1 { //繼續加碼
                        change = changeFactor
                    }
                } else if price.moneyMultiple == 1 {
                    if changeFactor == 1 { //已1個資本，只能繼續加碼
                        change = changeFactor
                    }
                }
                price.moneyChange = change   //還沒加碼就加碼（或減碼）
            } else {
                price.moneyChange = 0        //已加碼就還原（或減碼）
            }
            saveContext()
            stock.simPrices[stock.simId]?.privateContext.reset()
            if let rows = tableView.indexPathsForVisibleRows {
                tableView.reloadRows(at: rows, with: .fade)
            }
            self.stock.simPrices[self.stock.simId]!.willGiveMoney = false   //暫停自動加碼
            self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
            self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
        }
    }

    //反轉模擬按鈕的行動
    var lastReversed:(date:Date,action:String) = (Date.distantPast,"")
    func reverseAction (_ sender:UITableViewCell,button:UIButton) {
        if let indexPath = self.tableView.indexPath(for: sender) {
            self.stock.isUpdatingPrice = true
            let price = self.fetchedResultsController.object(at: indexPath) as! Price

            let dt:Date = twDateTime.startOfDay(price.dateTime)
            if let act = stock.simPrices[stock.simId]?.setReverse(date: dt) {
                if dt == lastReversed.date && act == lastReversed.action && self.stock.sortedStocks.count > 2 {
                    var actionMessage:String = ""
                    switch act {
                    case "買":
                        actionMessage = "買入"
                    case "賣":
                        actionMessage = "賣出"
                    default:
                        actionMessage = "復原"
                    }
                    let textMessage = "套用到其他股票\n" + "於同日全部" + actionMessage + "？"
                    let alert = UIAlertController(title: "全部套用", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: { action in
//                        self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
                        self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
                        self.lastReversed.date = Date.distantPast
                        self.lastReversed.action = ""
                    }))
                    alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                        for (id,_) in self.stock.sortedStocks {
                            if id != price.id {
                                _ = self.stock.simPrices[id]!.setReverse(date: dt,action: act)
                                //這裡已經有把willUpdateAllSim = true
                            }
                        }
                        self.stock.setupPriceTimer(mode: "simOnly")
                        self.lastReversed.action = ""
                        self.lastReversed.date = Date.distantPast
                    }))
                    self.present(alert, animated: true, completion: nil)

                } else {
//                    self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
                    self.stock.setupPriceTimer(self.stock.simId, mode: "simOnly")
                    lastReversed.date = dt
                    lastReversed.action = act
                }
            }
            if let rows = self.tableView.indexPathsForVisibleRows {
                self.tableView.reloadRows(at: rows, with: .fade)
            }
            self.stock.isUpdatingPrice = false
        }

    }











    func goNextMoneyChange() {
        if let dt = stock.simPrices[stock.simId]?.dateRange() {
            var scrollToIndexPath:IndexPath?
            var dateOfMoneyChange:Date = dt.last

            if fetchedResultsController.fetchedObjects!.count > 0 {
                if let visibleRows = tableView.indexPathsForVisibleRows {
                    for indexPath in visibleRows.reversed() {
                        let price = fetchedResultsController.object(at: indexPath) as! Price
                        if price.moneyChange > 0 {
                            dateOfMoneyChange = price.dateTime  //得畫面第一筆有moneyChange的日期
                            break
                        }
                    }
                }
                let prices = stock.simPrices[stock.simId]!.fetchPrice("<", dtStart: dateOfMoneyChange,asc: false)
                for price in prices { //往後找
                    if price.moneyChange > 0 {
                        if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                            scrollToIndexPath = priceIndexPath
                        }
                        break
                    }

                }
                if scrollToIndexPath == nil {   //後面沒有，再從頭找起
                    let prices = stock.simPrices[stock.simId]!.fetchPrice(">", dtEnd: dateOfMoneyChange,asc: false)
                    for price in prices {
                        if price.moneyChange > 0 {
                            if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                                scrollToIndexPath = priceIndexPath
                            }
                            break
                        }
                    }

                }
                if let _ = scrollToIndexPath {  //找到了就捲過去
                    tableView.scrollToRow(at: scrollToIndexPath!, at: UITableView.ScrollPosition.middle, animated: true)
                }
            }
        }
    }

    func goNextSimReverse() {
        if let dt = stock.simPrices[stock.simId]?.dateRange() {
            var scrollToIndexPath:IndexPath?
            var dateOfSimReverse:Date = dt.last

            if fetchedResultsController.fetchedObjects!.count > 0 {
                if let visibleRows = tableView.indexPathsForVisibleRows {
                    for indexPath in visibleRows.reversed() {
                        let price = fetchedResultsController.object(at: indexPath) as! Price
                        if price.simReverse != "無" && price.simReverse != "" {
                            dateOfSimReverse = price.dateTime  //得畫面末筆有moneyChange的日期
                            break
                        }
                    }
                }
                let prices = stock.simPrices[stock.simId]!.fetchPrice("<", dtStart: dateOfSimReverse,asc: false)
                for price in prices { //往後找
                    if price.simReverse != "無" && price.simReverse != "" {
                        if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                            scrollToIndexPath = priceIndexPath
                        }
                        break
                    }
                }
                if scrollToIndexPath == nil {   //後面沒有，再從頭找起
                    let prices = stock.simPrices[stock.simId]!.fetchPrice(">", dtEnd: dateOfSimReverse,asc: false)
                    for price in prices {
                        if price.simReverse != "無" && price.simReverse != "" {
                            if let priceIndexPath = fetchedResultsController.indexPath(forObject: price) {
                                scrollToIndexPath = priceIndexPath
                            }
                            break
                        }
                    }
                }
                if let _ = scrollToIndexPath {  //找到了就捲過去
                    tableView.scrollToRow(at: scrollToIndexPath!, at: UITableView.ScrollPosition.middle, animated: true)
                }
            }
        }
    }













    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let pad0:CGFloat = 250
        let padExt:CGFloat = 150

        let phone0:CGFloat = 200
        let phoneExt:CGFloat = 120

        let phone6Line:CGFloat = 36
        let padLine:CGFloat = 44

        var height:CGFloat = 0

        var selectedCellHeight:CGFloat = 0
        var unselectedCellHeight:CGFloat = 0

        if self.isPad {
            selectedCellHeight = pad0 + (extVersion ? padExt : 0)
            unselectedCellHeight = padLine
        } else {
            selectedCellHeight = phone0 + (extVersion ? phoneExt : 0)
            unselectedCellHeight = phone6Line
        }

        if selectedCellIndexPath == indexPath {
            height = selectedCellHeight
        } else {
            height = unselectedCellHeight
        }

        return height

    }



    var selectedCellIndexPath: IndexPath?

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if selectedCellIndexPath != nil && selectedCellIndexPath == indexPath {
            selectedCellIndexPath = nil
        } else {
            selectedCellIndexPath = indexPath
        }
        tableView.beginUpdates()    //???
        tableView.endUpdates()

        if selectedCellIndexPath != nil {
            // This ensures, that the cell is fully visible once expanded
            tableView.scrollToRow(at: indexPath, at: .none, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if extVersion {
            if let c = tableView.cellForRow(at: indexPath) {
                let cell = c as! priceCell
                let price = fetchedResultsController.object(at: indexPath) as! Price
                if price.simUpdated {
                    cell.uiUpdatedBy.backgroundColor = UIColor.clear
                } else {
                    cell.uiUpdatedBy.backgroundColor = UIColor.yellow
                }
            }
        }

    }


    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        var sectionHeader:String = ""
        if let sections = fetchedResultsController.sections {
            sectionHeader = sections[section].name
         }

        return sectionHeader
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let title = UILabel()
        if self.isPad {
            title.font = UIFont.systemFont(ofSize: CGFloat(20))
        } else {
            title.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)   //標準字體大小
        }
        title.textColor = UIColor.lightGray

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font=title.font
        header.textLabel?.textColor=title.textColor

    }



        //提供年度末兩碼的索引，不好按
        func sectionIndexTitles(for tableView: UITableView) -> [String]? {
            var titles:[String] = []
            if let sections = fetchedResultsController.sections {
                if sections.count > 7 {
                    for section in sections {
                        let t = String(section.name[section.name.index(section.name.endIndex, offsetBy: -2)...])
                        titles.append(t)
                    }
                    return titles
                }
            }
            return nil

        }
    
        func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
            if let sections = fetchedResultsController.sections {
                for (i,section) in sections.enumerated() {
                    let t = String(section.name[section.name.index(section.name.endIndex, offsetBy: -2)...])
                    if t == title {
                        return i
                    }
                }
            }
            return index
        }




    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        // Return no adaptive presentation style, use default presentation behaviour
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        //do som stuff from the popover
        var settingDate:(startOnly:Bool,endOnly:Bool,allStart:Bool,allEnd:Bool,allSwitch:Bool) = (false,false,false,false,false)
        var settingInitMoney:(selfOnly:Bool,all:Bool) = (false,false)
        var settingGiveMoney:(resetOnly:Bool,resetAll:Bool,giveOnly:Bool,giveAll:Bool,resetReverse:Bool) = (false,false,false,false,false)
        var settingMessage:String = ""
        if let _ = simPriceCopy {   //股票設定的開窗關閉之後
            if let _ = stock.simPrices[stock.simId] {
                if stock.simPrices[stock.simId]!.willResetReverse {
                    if let _ = simSettingChangedCopy {
                        if stock.simPrices[stock.simId]!.willResetReverse && simSettingChangedCopy!.willResetReverse && simSettingChangedCopy!.id != stock.simId {
                            settingMessage += "\n回復預設"
                            settingGiveMoney.resetReverse = true
                        }
                    }
                }
                if stock.simPrices[stock.simId]!.willGiveMoney {
                    settingGiveMoney.giveOnly = true
                    if let _ = simSettingChangedCopy {
                        if simSettingChangedCopy!.willGiveMoney && simSettingChangedCopy!.id != stock.simId {
                            settingMessage += "\n自動2次加碼"
                            settingGiveMoney.giveAll = true
                        }
                    }
                } else if stock.simPrices[stock.simId]!.willResetMoney && stock.simPrices[stock.simId]!.willGiveMoney == false && stock.simPrices[stock.simId]!.maxMoneyMultiple > 1 {
                    settingGiveMoney.resetOnly = true
                    if let _ = simSettingChangedCopy {
                        if simSettingChangedCopy!.willResetMoney && simSettingChangedCopy!.willGiveMoney == false && simSettingChangedCopy!.id != stock.simId {
                            settingMessage += "\n清除加碼"
                            settingGiveMoney.resetAll = true
                        }
                    }
                }
                if stock.simPrices[stock.simId]!.dateStart != simPriceCopy!.dateStart {
                    settingDate.startOnly = true
                    if let _ = simSettingChangedCopy {
                        if stock.simPrices[stock.simId]!.dateStart == simSettingChangedCopy!.dateStart && simSettingChangedCopy!.id != stock.simId {
                            settingDate.allStart = true
                            settingMessage += "\n起日＝ " + twDateTime.stringFromDate(simSettingChangedCopy!.dateStart)
                        }
                    }
                }
                if stock.simPrices[stock.simId]!.dateEnd != simPriceCopy!.dateEnd || stock.simPrices[stock.simId]!.dateEndSwitch != simPriceCopy!.dateEndSwitch {
                    settingDate.endOnly = true
                    if let _ = simSettingChangedCopy {
                        if (stock.simPrices[stock.simId]!.dateEndSwitch != simPriceCopy!.dateEndSwitch && stock.simPrices[stock.simId]!.dateEndSwitch == simSettingChangedCopy!.dateEndSwitch) || (stock.simPrices[stock.simId]!.dateEnd != simPriceCopy!.dateEnd && stock.simPrices[stock.simId]!.dateEnd == simSettingChangedCopy!.dateEnd) && simSettingChangedCopy!.id != stock.simId {
                            if stock.simPrices[stock.simId]!.dateEndSwitch {
                                settingDate.allEnd = true
                                settingDate.allSwitch = true
                                settingMessage += "\n迄日＝ " + twDateTime.stringFromDate(simSettingChangedCopy!.dateEnd)
                            } else {
                                settingDate.allSwitch = true
                                settingMessage += "\n不指定迄日"
                            }
                        }
                    }
                }
                if stock.simPrices[stock.simId]!.initMoney != simPriceCopy!.initMoney {
                    settingInitMoney.selfOnly = true
                    if let _ = simSettingChangedCopy {
                        if stock.simPrices[stock.simId]!.initMoney == simSettingChangedCopy!.initMoney && simSettingChangedCopy!.id != stock.simId {
                            settingInitMoney.all = true
                            settingMessage += "\n本金＝ " + String(format: "%.f萬元",simSettingChangedCopy!.initMoney)
                        }
                    }
                }
            }




            func changeSetting (changeAll:Bool=false) {
                if changeAll {
                    for (id,_) in self.stock.sortedStocks {
                        if id != simSettingChangedCopy!.id {
                            if id != self.stock.simId {
                                if settingGiveMoney.resetReverse {
                                    self.stock.simPrices[id]!.resetToDefault()
                                }
                                if settingGiveMoney.giveAll {
                                    self.stock.simPrices[id]!.willGiveMoney   = self.stock.simPrices[self.stock.simId]!.willGiveMoney
                                    self.stock.simPrices[id]!.willResetMoney  = self.stock.simPrices[self.stock.simId]!.willResetMoney
                                } else if settingGiveMoney.resetAll {
                                    self.stock.simPrices[id]!.willResetMoney  = self.stock.simPrices[self.stock.simId]!.willResetMoney
                                }
                                if settingDate.allStart {
                                    self.stock.simPrices[id]!.dateStart       = self.stock.simPrices[self.stock.simId]!.dateStart
                                    self.stock.simPrices[id]!.dateEarlier     = self.stock.simPrices[self.stock.simId]!.dateEarlier
                                    self.stock.simPrices[id]!.willGiveMoney   = true
                                    self.stock.simPrices[id]!.willResetMoney  = true
                                    self.stock.simPrices[id]!.twseTask        = [:]
                                    self.stock.simPrices[id]!.cnyesTask       = [:]
                                }
                                if settingDate.allSwitch {
                                    self.stock.simPrices[id]!.dateEndSwitch   = self.stock.simPrices[self.stock.simId]!.dateEndSwitch
                                    if self.stock.simPrices[id]!.dateEndSwitch == false {
                                        self.stock.simPrices[id]!.dateEnd         = self.stock.simPrices[self.stock.simId]!.dateEnd
                                    }
                                }
                                if settingDate.allEnd {
                                    self.stock.simPrices[id]!.dateEnd         = self.stock.simPrices[self.stock.simId]!.dateEnd
                                }
                                if settingInitMoney.all && id != "t00" {
                                    self.stock.simPrices[id]!.initMoney       = self.stock.simPrices[self.stock.simId]!.initMoney
                                    self.stock.simPrices[id]!.willGiveMoney = true
                                    self.stock.simPrices[id]!.willResetMoney = true

                                }
                            } else if settingDate.startOnly {
                                self.stock.simPrices[id]!.willGiveMoney = true
                                self.stock.simPrices[id]!.willResetMoney = true
                            }   //if id != self.stock.simId
                            self.stock.simPrices[id]!.willUpdateAllSim = true
                        }   //if id != simSettingChangedCopy!.id
                    }   //for id in self.stock.simPrices.keys

                    if settingGiveMoney.resetReverse {  //全部的股都改預設時，恢復起始本金和年數
                        self.defaults.set(self.stock.defaultMoney, forKey: "defaultMoney")
                        self.defaults.set(self.stock.defaultYears, forKey: "defaultYears")
                    }
                    if settingInitMoney.all {    //全部的股都變更起始本金時，也要變更預設的起始本金
                        self.masterLog("set defaultMoney=\(self.stock.simPrices[self.stock.simId]!.initMoney)")
                        self.defaults.set(self.stock.simPrices[self.stock.simId]!.initMoney, forKey: "defaultMoney")
                    }
                    if settingDate.allStart || settingDate.allEnd {
                        if let start = twDateTime.calendar.ordinality(of: .day, in: .era, for: self.stock.simPrices[self.stock.simId]!.dateStart) {
                            var endDate:Date = Date()
                            if self.stock.simPrices[self.stock.simId]!.dateEndSwitch {
                                endDate = self.stock.simPrices[self.stock.simId]!.dateEnd
                            }
                            if let end = twDateTime.calendar.ordinality(of: .day, in: .era, for: endDate) {
                                let years = Int(round(Float(end - start) / 365.4))
                                if years > 1 {
                                    self.masterLog("set defaultYears=\(years)")
                                    self.defaults.set(years, forKey: "defaultYears")
                                }
                            }
                        }
                    }

                    if !self.stock.simTesting {
                        self.defaults.set(NSKeyedArchiver.archivedData(withRootObject: self.stock.simPrices) , forKey: "simPrices")
                    }
                    self.stock.setupPriceTimer(mode: "all")

                } else {
                    if settingDate.startOnly {
                        self.stock.simPrices[self.stock.simId]!.twseTask    = [:]
                        self.stock.simPrices[self.stock.simId]!.cnyesTask   = [:]
                    }
                    if settingDate.startOnly || settingInitMoney.selfOnly || self.stock.simPrices[self.stock.simId]!.willResetReverse {
                        self.stock.simPrices[self.stock.simId]!.willGiveMoney = true
                        self.stock.simPrices[self.stock.simId]!.willResetMoney = true
                    }
                    self.initSummary()
                    self.stock.simPrices[self.stock.simId]!.willUpdateAllSim = true
                    self.stock.setupPriceTimer(self.stock.simId, mode: "all")

                }

            }


            if (settingDate.allStart || settingDate.allEnd || settingDate.allSwitch || settingInitMoney.all || settingGiveMoney.giveAll || settingGiveMoney.resetAll) && stock.sortedStocks.count > 2 {
                let textMessage = "將以下設定套用到其他股票？\n" + settingMessage
                let alert = UIAlertController(title: "全部套用", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "不用", style: .cancel, handler: { action in
                    changeSetting(changeAll: false)
                    self.simSettingChangedCopy = nil

                }))
                alert.addAction(UIAlertAction(title: "好", style: .default, handler: { action in
                    changeSetting(changeAll: true)
                    self.simSettingChangedCopy = nil

                }))
                self.present(alert, animated: true, completion: nil)

            } else if settingDate.startOnly || settingDate.endOnly || settingInitMoney.selfOnly || settingGiveMoney.resetOnly || settingGiveMoney.giveOnly {
                changeSetting(changeAll: false)
                if let sim = stock.simPrices[stock.simId] {
                    self.simSettingChangedCopy = self.stock.copySimPrice(sim)
                    Timer.scheduledTimer(timeInterval: 5*60, target: self, selector: #selector(masterViewController.clearSettingCopy), userInfo: nil, repeats: false)
                }
            }

            simPriceCopy = nil


        } else {    //股票名稱滾輪關閉之後
            if self.simIdCopy != stock.simId {
                showPrice(stock.simId)
                self.simIdCopy = nil
            }
        }

    }

    @objc func clearSettingCopy() {
        simSettingChangedCopy  = nil
    }









    var lineMsg:String = ""
    func masterLog(_ msg:String) {
        let logLine:Bool = msg.first == "!"         //只用於抓蟲測試時強制輸出訊息到LINE
        if self.lineLog || logLine || self.debugRun {
            let notHideToLine:Bool = msg.first != "*"    //在LINE隱藏不發
            let testReport:Bool = (msg.first == "=" || !stock.simTesting)   //有接Xcode就要發
            if self.debugRun && testReport {
                NSLog(msg)
            }
            if (self.lineLog || logLine) && notHideToLine && lineReport {
                lineMsg += "\n" + msg
                if (lineMsg.count > 1000 || msg.contains("\n") || logLine) {
                    if let _ = bot?.userProfile {
                        bot!.pushTextMessages(message:lineMsg)
                        lineMsg = ""
                    } else {
                        lineMsg += "LINE is not ready.\n"
                    }

                }
            }
        }
    }


}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
