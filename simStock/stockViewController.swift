//
//  StockIdViewController.swift
//  simStock
//
//  Created by peiyu on 2016/6/26.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit
import CoreData


protocol stockViewDelegate:class {
    func addSearchedToList(_ cell:stockListCell)
}


class stockViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, NSFetchedResultsControllerDelegate, stockViewDelegate {


    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var uiProgress: UIProgressView!
    @IBOutlet weak var uiNavigationItem: UINavigationItem!
    @IBOutlet weak var uiBarAction: UIBarButtonItem!
    
    var searchString:String = ""
    var dateStockListDownloaded:Date = Date.distantPast
    var defaultId:String = {
        if let defaultId = UserDefaults.standard.string(forKey: "defaultId") {
            return defaultId
        } else {
            return "2330"
        }
    }()
    let waitForImportFromInternet:DispatchGroup = DispatchGroup()
    var isNotEditingList:Bool = true
    var importingFromInternet:Bool = false
    var simPrices:[String:simPrice] = [:]
    var stockIdCopy:String = ""
    var addedStock:String = ""
    var foundStock:String = ""
    var masterUI:masterUIDelegate?

    var stockListVersion:String = ""
    var version:String = ""
    var isPad:Bool = false
    let defaults:UserDefaults = UserDefaults.standard

    @IBAction func uiBarExport(_ sender: UIBarButtonItem) {
            let textMessage = "選擇範圍和內容？"
            let alert = UIAlertController(title: "匯出股群CSV內容", message: textMessage, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "匯出代號和名稱", style: .default, handler: { action in
                self.exportAllId("ID")
            }))
            alert.addAction(UIAlertAction(title: "匯出股群彙總", style: .default, handler: { action in
                self.exportAllId("SUMMARY")
            }))
            alert.addAction(UIAlertAction(title: "匯出逐月已實現損益", style: .default, handler: { action in
                self.exportAllId("ROI")
            }))
            self.present(alert, animated: true, completion: nil)

    }
    
    func exportAllId (_ contents:String) {
        var exportString:String = ""
        switch contents {
        case "SUMMARY":
            if let s = self.masterUI?.getStock() {
                exportString = s.csvSummary()
            }
        case "ROI":
            if let s = self.masterUI?.getStock() {
                exportString = s.csvMonthlyRoi()
            }
        default:    //匯出ID和名稱
            if let stocks = self.masterUI?.getStock().sortedStocks {
                for s in stocks {
                    if s.id != "t00" {
                        if exportString == "" {
                            exportString += s.id + " " + s.name
                        } else {
                            exportString += ", " + s.id + " " + s.name
                        }
                    }
                }
            }
        }
        if exportString.count > 0 {
            let activityViewController : UIActivityViewController = UIActivityViewController(activityItems: [exportString], applicationActivities: nil)
            activityViewController.excludedActivityTypes = [    //標為註解以排除可用的，留下不要的
                .addToReadingList,
                .airDrop,
                .assignToContact,
//                .copyToPasteboard,
//                .mail,
//                .markupAsPDF,   //iOS11之後才有
//                .message,
                .openInIBooks,
                .postToFacebook,
                .postToFlickr,
                .postToTencentWeibo,
                .postToTwitter,
                .postToVimeo,
                .postToWeibo,
                .print,
                .saveToCameraRoll]
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
                popover.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
            }
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    // *********************************
    // ***** ===== Core Data ===== *****
    // *********************************

    var _fetchedResultsController:NSFetchedResultsController<NSFetchRequestResult>?

    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        let searchKey:[String] = searchString.components(separatedBy: " ")
        let fetchRequest = coreData.shared.fetchRequestStock(id:searchKey,name:searchKey) as! NSFetchRequest<NSFetchRequestResult>
        _fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchRequest, managedObjectContext: coreData.shared.mainContext, sectionNameKeyPath: "list", cacheName: nil)
        _fetchedResultsController!.delegate = self
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            NSLog("stockView fetch error\n\(error)\n")
        }
        return _fetchedResultsController!

    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch(type) {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
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
    







    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(stockViewController.reloadAllStock), for: UIControl.Event.valueChanged)

        return refreshControl
    }()

    @objc func reloadAllStock() {
        self.refreshControl.endRefreshing()
        self.importFromInternet()
    }


















    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("=== stockList viewDidLoad ===")
        if (traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.pad) {
            isPad = true
        }
        if let sims = masterUI?.getStock().simPrices {
            simPrices = sims
        }

        self.clearNoDataElement ()
        self.uiProgress.setProgress(0, animated: false)
        self.tableView.addSubview(self.refreshControl)


        if let dt = defaults.object(forKey: "dateStockListDownloaded"){
            self.dateStockListDownloaded = (dt as! Date)
            NSLog("twseDailyMI:\(twDateTime.stringFromDate(dateStockListDownloaded, format: "yyyy/MM/dd HH:mm:ss"))")

            let bySearch1 = coreData.shared.fetchStock(list:[coreData.shared.sectionBySearch], fetchLimit: 1)
            if bySearch1.Stocks.count == 0 {
                importFromInternet()
            } else {
                if let f = fetchedResultsController.fetchedObjects {
                    if simPrices.count != f.count {
                        NSLog("fetchedObjects(\(f.count)) != simPrices(\(simPrices.count))")
                        self.importFromDictionary()
                    }
                }
            }
        } else {
            importFromInternet()
        }
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NSLog("== stockList viewWillDisappear ==\n")

        clearNoDataElement()

    }




    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        NSLog(">>>>> stockList didReceiveMemoryWarning <<<<<\n")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NSLog("=== stockList viewWillAppear ===")

        reloadTable ()
    }


    
    


    func importFromInternet () {
        lockUI()
        OperationQueue().addOperation {
            coreData.shared.deleteStock(list:["ALL"])
            self.importFromDictionary()
            self.twseDailyMI()
        }
    }
    
    func importFromDictionary (_ context:NSManagedObjectContext?=nil) {
        //從stockNames新增
        if let simStock = masterUI?.getStock() {
            let theContext = coreData.shared.getContext(context)
            let _ = coreData.shared.updateStock(theContext, id:"t00", name: "*加權指", list: coreData.shared.sectionBySearch)
            let sortedStocks = simStock.sortStocks(includePaused: true)
            for s in sortedStocks {
                if self.simPrices[s.id]!.paused {
                    let _ = coreData.shared.updateStock(theContext, id:s.id, name: s.name, list: coreData.shared.sectionWasPaused)
                } else {
                    let updated = coreData.shared.updateStock(theContext, id:s.id, name: s.name, list: coreData.shared.sectionInList)
                    print("importFromDictionary \(updated.stock.name):\(updated.stock.list)")
                }
            }
            coreData.shared.saveContext(theContext) 

        }
    }

    func lockUI() {
        addedStock = ""
        foundStock = ""
        searchString = ""
        uiSearchBar.text = ""
        uiSearchBar.isUserInteractionEnabled = false
        importingFromInternet = true
        uiNavigationItem.hidesBackButton = true
        UIApplication.shared.isIdleTimerDisabled = true  //更新資料時，防止睡著
    }

    func unlockUI() {
        OperationQueue.main.addOperation {
            self.uiProgress.setProgress(1, animated: true)
            self.uiProgress.setProgress(0, animated: false)
            self.reloadTable()
            UIApplication.shared.isIdleTimerDisabled = false  //更新資料完畢允許睡眠
            self.importingFromInternet = false
            self.tableView.isUserInteractionEnabled = true
            self.uiSearchBar.isUserInteractionEnabled = true
            self.uiNavigationItem.hidesBackButton = false
        }
    }


    var allStockCount:Int = 0
    func twseDailyMI(_ context:NSManagedObjectContext?=nil) {
        //        let y = calendar.component(.Year, fromDate: qDate) - 1911
        //        let m = calendar.component(.Month, fromDate: qDate)
        //        let d = calendar.component(.Day, fromDate: qDate)
        //        let YYYMMDD = String(format: "%3d/%02d/%02d", y,m,d)
        //================================================================================
        allStockCount = 0
        //從當日收盤行情取股票代號名稱

        self.waitForImportFromInternet.enter()

        //2017-05-24因應TWSE網站改版變更查詢方式為URLRequest
        //http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&date=20170523&type=ALLBUT0999

        let url = URL(string: "http://www.twse.com.tw/exchangeReport/MI_INDEX?response=csv&type=ALLBUT0999")
        let request = URLRequest(url: url!,timeoutInterval: 30)

        let task = URLSession.shared.dataTask(with: request, completionHandler: {(data, response, error) in
            if error == nil {
                let big5 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosChineseTrad.rawValue))
                if let downloadedData = String(data:data!, encoding:String.Encoding(rawValue: big5)) {

                    /* csv檔案的內容是混合格式：
                     2016年07月19日大盤統計資訊
                     "指數","收盤指數","漲跌(+/-)","漲跌點數","漲跌百分比(%)"
                     寶島股價指數,10452.88,+,26.8,0.26
                     發行量加權股價指數,9034.87,+,26.66,0.3
                     "成交統計","成交金額(元)","成交股數(股)","成交筆數"
                     "1.一般股票","86290700501","2396982245","807880"
                     "2.台灣存託憑證","25070276","4935658","1405"
                     "證券代號","證券名稱","成交股數","成交筆數","成交金額","開盤價","最高價","最低價","收盤價","漲跌(+/-)","漲跌價差","最後揭示買價","最後揭示買量","最後揭示賣價","最後揭示賣量","本益比"
                     ="0050  ","元大台灣50      ","17045587","2165","1179010803","69.2","69.3","68.8","69.25","+","0.1","69.25","615","69.3","40","0.00"
                     "1101  ","台泥            ","10196350","5055","362488555","35.55","35.75","35.4","35.6","+","0.1","35.55","122","35.6","152","25.25"
                     "1102  ","亞泥            ","5021942","3083","144691768","28.7","29","28.55","28.9","+","0.2","28.85","106","28.9","147","27.01"

                     "說明："
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
                    textString = textString.replacingOccurrences(of: "\"", with: "")  //去雙引號
                    textString = textString.replacingOccurrences(of: "\r\n", with: "\n")  //去換行

                    let lines:[String] = textString.components(separatedBy: CharacterSet.newlines) as [String]
                    var stockListBegins:Bool = false
                    let theContext = coreData.shared.getContext(context)
                    for (index, lineText) in lines.enumerated() {
                        var line:String = lineText
                        if lineText.first == "=" {
                            stockListBegins = true
                        }
                        if lineText != "" && lineText.contains(",") && lineText.contains(".") && index > 2 && stockListBegins {
                            if lineText.first == "=" {
                                line = lineText.replacingOccurrences(of: "=", with: "")   //去首列等號
                            }

                            let id = line.components(separatedBy: ",")[0]
                            let name = line.components(separatedBy: ",")[1]
                            var sectionName:String
                            if self.simPrices.keys.contains(id) {
                                sectionName = (self.simPrices[id]!.paused ? coreData.shared.sectionWasPaused : coreData.shared.sectionInList)
                                print("twseDailyMI update \(name):\(sectionName)")
                            } else {
                                sectionName = coreData.shared.sectionBySearch
                            }
                            
                            let _ = coreData.shared.updateStock(theContext, id:id, name: name, list: sectionName)
                            self.allStockCount += 1
                            let progress:Float = Float(index+1) / Float(lines.count)
                            OperationQueue.main.addOperation {
                                self.uiProgress.setProgress(progress, animated: true)
                            }

                        }   //if line != ""
                    } //for
                    coreData.shared.saveContext(theContext)    //self.saveContext()
                    self.dateStockListDownloaded = Date()
                    self.defaults.set(self.dateStockListDownloaded, forKey: "dateStockListDownloaded")
                    NSLog("twseDailyMI(ALLBUT0999): \(twDateTime.stringFromDate(self.dateStockListDownloaded, format: "yyyy/MM/dd HH:mm:ss")) \(self.allStockCount)筆")
                }   //if let downloadedData
            } else {  //if error == nil
                NSLog("twsePrices error:\(String(describing: error))")
            }
            self.unlockUI()
            self.waitForImportFromInternet.leave()
        })
        task.resume()
    }


    







    // MARK: - Table view data source
    //=========================================================================

    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects

    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let stock   = fetchedResultsController.object(at: indexPath) as! Stock
        let cell    = tableView.dequeueReusableCell(withIdentifier: "cellStockList", for: indexPath) as! stockListCell 
        cell.stockView = self

        cell.uiId.adjustsFontSizeToFitWidth = true
        cell.uiName.adjustsFontSizeToFitWidth = true
        cell.uiYears.adjustsFontSizeToFitWidth = true
        cell.uiROI.adjustsFontSizeToFitWidth = true
        cell.uiMultiple.adjustsFontSizeToFitWidth = true
        cell.uiDays.adjustsFontSizeToFitWidth = true


        cell.uiId.text    = stock.id
        cell.uiName.text  = stock.name

        if stock.list == coreData.shared.sectionBySearch {
            cell.uiButtonWidth.constant = 44
            cell.uiId.textColor = UIColor(red:128/255, green:120/255, blue:0, alpha:1)
            cell.uiName.textColor = UIColor(red:128/255, green:120/255, blue:0, alpha:1)
            if stock.name == coreData.shared.NoData || importingFromInternet {
                cell.uiButtonAdd.isHidden = true
            } else {
                cell.uiButtonAdd.isHidden = false
            }
            cell.uiYears.text = ""
            cell.uiROI.text = ""
            cell.uiDays.text = ""
            cell.uiMultiple.text = ""
            cell.uiDays.isHidden = true
            cell.uiYears.isHidden = true
            cell.uiROI.isHidden = true
            cell.uiMultiple.isHidden = true

            cell.uiCellPriceClose.text  = ""
            cell.uiCellPriceUpward.text = ""
            cell.uiCellAction.text      = ""
            cell.uiCellQty.text         = ""
            cell.uiCellPriceClose.isHidden  = true
            cell.uiCellPriceUpward.isHidden = true
            cell.uiCellAction.isHidden      = true
            cell.uiCellQty.isHidden         = true
        } else {
            cell.uiButtonWidth.constant = 8
            cell.uiButtonAdd.isHidden = true
            if let simPrice = simPrices[stock.id] {
                let maxMultiple = simPrice.maxMoneyMultiple
                let roiTuple = simPrice.ROI()
                let last     = simPrice.getPropertyLast()
                cell.uiYears.text = String(format:"%.1f年",roiTuple.years)
                cell.uiYears.textColor = (simPrice.paused ? UIColor.lightGray : UIColor.darkGray)
                let cumuROI = round(10 * roiTuple.roi) / 10
                if self.isPad && last.qtyInventory > 0 && !simPrice.paused {
                    let simROI = round(10 * last.simROI) / 10
                    cell.uiROI.text = String(format:"%.1f/%.1f%%",simROI,cumuROI)
                } else {
                    cell.uiROI.text = String(format:"%.1f%%",cumuROI)
                }
                if simPrice.paused {
                    cell.uiROI.textColor = UIColor.lightGray
                } else if cumuROI < -10 {
                    cell.uiROI.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                } else if cumuROI < 0 {
                    cell.uiROI.textColor = UIColor(red: 0, green:72/255, blue:0, alpha:1)
                } else if cumuROI > 20 {
                    cell.uiROI.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                } else if cumuROI > 10 {
                    cell.uiROI.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                } else {
                    cell.uiROI.textColor = UIColor.darkGray
                }

                cell.uiDays.isHidden = false
                var cutCount:String = ""
                if roiTuple.cut > 0 {
                    cutCount = String(format:"(%.f)",roiTuple.cut)
                }
                if last.simDays > 0 && self.isPad && !simPrice.paused {
                    cell.uiDays.text = String(format:"%.f/%.f天",last.simDays,roiTuple.days) + cutCount
                } else {
                    cell.uiDays.text = String(format:"%.f天",roiTuple.days) + cutCount
                }
                if simPrice.paused {
                    cell.uiDays.textColor = UIColor.lightGray
                } else if roiTuple.days > 200 {
                    cell.uiDays.textColor = UIColor(red:0, green:116/255, blue:0, alpha:1)
                } else if roiTuple.days > 150 {
                    cell.uiDays.textColor = UIColor(red:0, green:96/255, blue:0, alpha:1)
                } else if roiTuple.days > 75 {
                    cell.uiDays.textColor = UIColor(red:0, green:64/255, blue:0, alpha:1)
                } else if roiTuple.days > 50 {
                    cell.uiDays.textColor = UIColor.darkGray
                } else {
                    cell.uiDays.textColor = UIColor(red:192/255, green:0, blue:0, alpha:1)
                }

                if self.isPad {
                    cell.uiCellAction.adjustsFontSizeToFitWidth = true
                    cell.uiCellAction.isHidden      = false
                    if simPrice.paused {
                        cell.uiCellAction.text = ""
                        cell.uiCellQty.text = ""
                    } else if last.qtyBuy > 0 {
                        cell.uiCellAction.text = "買"
                        cell.uiCellAction.textColor = UIColor.red
                        cell.uiCellQty.text = String(format:"%.f",last.qtyBuy)
                        cell.uiCellQty.textColor = UIColor.red
                    } else if last.qtySell > 0 {
                        cell.uiCellAction.text = "賣"
                        cell.uiCellAction.textColor = UIColor.blue
                        cell.uiCellQty.text = String(format:"%.f",last.qtySell)
                        cell.uiCellQty.textColor = UIColor.blue
                    } else if last.qtyInventory > 0 {
                        cell.uiCellAction.text = "餘"
                        cell.uiCellAction.textColor = UIColor.brown
                        cell.uiCellQty.text = String(format:"%.f",last.qtyInventory)
                        cell.uiCellQty.textColor = UIColor.brown
                    } else {
                        cell.uiCellAction.text = ""
                        cell.uiCellQty.text = ""
                    }
                    
                    
                    cell.uiCellPriceClose.adjustsFontSizeToFitWidth = true
                    cell.uiCellPriceUpward.adjustsFontSizeToFitWidth = true
                    cell.uiCellQty.adjustsFontSizeToFitWidth = true

                    cell.uiCellPriceClose.isHidden  = false
                    cell.uiCellPriceUpward.isHidden = false
                    cell.uiCellQty.isHidden         = false

                    if simPrice.paused {
                        cell.uiCellPriceClose.text =  ""
                        cell.uiCellPriceUpward.text = ""

                    } else {
                        cell.uiCellPriceClose.text =  String(format:"%.2f",last.priceClose)
                        cell.uiCellPriceClose.textColor = self.masterUI?.simRuleColor(last.simRule) //與主畫面的收盤價同顏色
                        cell.uiCellPriceUpward.text = last.priceUpward
                        switch last.priceUpward {
                        case "▲":
                            cell.uiCellPriceUpward.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                        case "▵","up":
                            cell.uiCellPriceUpward.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                        case "▿","down":
                            cell.uiCellPriceUpward.textColor = UIColor(red: 0, green:72/255, blue:0, alpha:1)
                        case "▼":
                            cell.uiCellPriceUpward.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                        default:
                            cell.uiCellPriceUpward.textColor = UIColor.darkGray
                        }
                    }


                } else {
                    cell.uiCellPriceClose.text  = ""
                    cell.uiCellPriceUpward.text = ""
                    cell.uiCellQty.text         = ""
                    cell.uiCellPriceClose.isHidden  = true
                    cell.uiCellPriceUpward.isHidden = true
                    cell.uiCellQty.isHidden         = true
                }
                cell.uiYears.isHidden = false
                cell.uiROI.isHidden = false
                /*
                if maxMultiple > 1 {
                    cell.uiMultiple.textColor = (simPrice.paused ? UIColor.lightGray : UIColor.darkGray)
                    cell.uiMultiple.text = String(format:"x%.f",maxMultiple)
                    cell.uiMultiple.isHidden = false
                } else {
                    cell.uiMultiple.text = ""
                    cell.uiMultiple.isHidden = true
                }
 */
                var lastMultiple:Double = 0
                if let m = simPrice.getPriceLast()?.moneyMultiple {
                    lastMultiple = m
                }
                let lastMs:String = (last.qtyInventory > 0 ? String(format:"x%.f",lastMultiple) : "")
                let maxMs:String  = (roiTuple.days > 0 && maxMultiple > 0 ? String(format:(lastMs == "" ? "x" : "") + "%.f",maxMultiple) : "")
                let msSep:String = (lastMs == "" || maxMs == "" ? "" : "/")
                if lastMs != "" || maxMs != "" {
                    cell.uiMultiple.textColor = (simPrice.paused ? UIColor.lightGray : UIColor.darkGray)
                    cell.uiMultiple.text = lastMs + msSep + maxMs
                    cell.uiMultiple.isHidden = false

                } else {
                    cell.uiMultiple.text = ""
                    cell.uiMultiple.isHidden = true
                }
                
                if simPrice.simReversed {
                    cell.uiROI.textColor = (simPrice.paused ? UIColor.lightGray : self.view.tintColor)
                }

                //Rank的顏色標示
                if simPrice.paused {
                    cell.uiId.textColor = UIColor.lightGray
                } else {
                    switch roiTuple.rank {
                    case "A":
                        cell.uiId.textColor = UIColor(red: 192/255, green:0, blue:0, alpha:1)
                    case "B":
                        cell.uiId.textColor = UIColor(red: 128/255, green:0, blue:0, alpha:1)
                    case "C+":
                        cell.uiId.textColor = UIColor(red: 96/255, green:0, blue:0, alpha:1)
                    case "C":
                        cell.uiId.textColor = UIColor.darkGray
                    case "C-":
                        cell.uiId.textColor = UIColor(red: 0, green:64/255, blue:0, alpha:1)
                    case "D":
                        cell.uiId.textColor = UIColor(red: 0, green:96/255, blue:0, alpha:1)
                    case "E":
                        cell.uiId.textColor = UIColor(red:0, green:128/255, blue:0, alpha:1)
                    default:
                        cell.uiId.textColor = UIColor.darkGray
                    }
                }
                cell.uiName.textColor = cell.uiId.textColor

            } else {
                cell.uiId.textColor = UIColor.brown
                cell.uiName.textColor = UIColor.brown
                cell.uiYears.text = ""
                cell.uiROI.text = ""
                cell.uiYears.isHidden = true
                cell.uiROI.isHidden = true
                cell.uiMultiple.text = ""
                cell.uiMultiple.isHidden = true
                cell.uiDays.text = ""
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let sections = fetchedResultsController.sections {
            var text:String = ""
            let currentSection = sections[section]
            
            if self.importingFromInternet {
                text = "正在下載股票名單，請稍候。\n"
            } else {
                if addedStock != "" {
                    text = "已新增 " + addedStock + " 到股群清單。\n\n"
                }
                if foundStock != "" {
                    text = foundStock + " 已經在股群內。\n\n"
                }
                switch currentSection.name {
                case coreData.shared.sectionBySearch:
                    text = text + currentSection.name + "：已在股群內或是上櫃者不會列出。"
                case coreData.shared.sectionInList:
                    text = text + currentSection.name + "：從搜尋結果加入，或手勢左滑刪除。"
                case coreData.shared.sectionWasPaused:
                    text = text + currentSection.name + "：手勢左滑以重啟模擬或刪除。"
                default:
                    text = currentSection.name
                }
            }
            return text
        }
        return ""
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let sections = fetchedResultsController.sections {
            if sections[section].name == coreData.shared.sectionInList && sections[section].numberOfObjects > 1 {
                let isPaused:Bool = sections[section].name == coreData.shared.sectionWasPaused
                if let rois = masterUI?.getStock().roiSummary(forPaused: isPaused) {
                    let count:String    = "\(rois.count)支股 "
                    let roiAvg:String   = String(format:"平均年報酬率 %.1f%%", round(10 * rois.roi) / 10)
                    let daysAvg:String  = String(format:"(平均週期%.f天)", rois.days)
                    let lastMult:String = (rois.countMultiple > 0 ? String(format:"目前持股%.f支本金x%.f",rois.countMultiple,rois.sumMultiple) : "")
                    return "\(count)\(roiAvg) \(daysAvg) \(lastMult)"
                }
            }
        }
        return nil
    }


    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let title = UILabel()
        if self.isPad {
            title.font = UIFont.systemFont(ofSize: 16.0)
        } else {
            title.font = UIFont.systemFont(ofSize: 14.0)
        }

        if self.importingFromInternet {
            title.textColor = UIColor.orange
        } else if let sections = fetchedResultsController.sections {
            if sections[section].name == coreData.shared.sectionBySearch {
                title.textColor = UIColor.brown
            } else {
                title.textColor = UIColor.darkGray
            }
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font=title.font
        header.textLabel?.textColor=title.textColor
    }

    //新增代號
    func addSearchedToList(_ cell:stockListCell) {
        let maxStocks:Int = 1000
        if let simStock = masterUI?.getStock() {
            if simPrices.count < maxStocks {
                if isNotEditingList {
                    isNotEditingList = false
                    if let indexPath = tableView.indexPath(for: cell) {
                        let stock = fetchedResultsController.object(at: indexPath) as! Stock
                        stock.list = coreData.shared.sectionInList
                        self.addedStock = stock.id + " " + stock.name    //顯示於section header
                        self.simPrices = simStock.addNewStock(id:stock.id,name:stock.name) //重刷tableView前必須備妥新代號
                        coreData.shared.saveContext()
                        self.reloadTable()  //才能於section header顯示訊息
                        self.isNotEditingList = true
                    }
                }
            } else {
                let textMessage = "最多\n只能保存\(maxStocks)支股票。"
                let alert = UIAlertController(title: "Warning", message: textMessage, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)

            }
        }


    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions:[UITableViewRowAction] = []
        let stock = self.fetchedResultsController.object(at: indexPath) as! Stock
        let id = stock.id
        if let simPrice = self.simPrices[id] {
            if self.masterUI!.getStock().sortedStocks.count > 1 || simPrice.paused {
                let pause = UITableViewRowAction(style: .default, title: (simPrice.paused ? "重啟模擬" : "暫停模擬")) { action, index in
                    self.clearNoDataElement()
                    self.isNotEditingList = false
                    self.stockIdCopy = ""
                    OperationQueue.main.addOperation {
                        self.simPrices = self.masterUI!.getStock().pausePriceSwitch(id)
                        if self.simPrices[id]!.paused { //改名使簡稱排序在前 --> 還有其他地方要改
                            stock.list = coreData.shared.sectionWasPaused
                        } else {
                            stock.list = coreData.shared.sectionInList
                        }
                        coreData.shared.saveContext()
                        self.reloadTable()
                        self.isNotEditingList = true
                    }
                    
                }
                actions.append(pause)
            }
        }
        let delete = UITableViewRowAction(style: (actions.count > 0 ? .normal : .default), title: "刪除") { action, index in
            self.clearNoDataElement()
            self.isNotEditingList = false
            self.stockIdCopy = ""
            OperationQueue.main.addOperation {
                stock.list = coreData.shared.sectionBySearch
                coreData.shared.saveContext()
                self.simPrices = self.masterUI!.getStock().removeStock(id)
                if self.simPrices.count == 1 {
                    self.importFromDictionary()  //把預設的台積電加回來
                    self.reloadTable()
                }
                self.isNotEditingList = true
            }
        }
        actions.append(delete)
        
 
        return actions
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if self.importingFromInternet {
            return false
        }
        let stock = fetchedResultsController.object(at: indexPath) as! Stock
        if stock.list != coreData.shared.sectionBySearch && isNotEditingList && (self.simPrices.count > 1 || stock.id != defaultId) {
            return true
        } else {
            return false
        }
    }

    //刪除代號
//    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
//        self.clearNoDataElement()
//        if (editingStyle == UITableViewCell.EditingStyle.delete) {
//            isNotEditingList = false
//            self.stockIdCopy = ""
//            let stock = self.fetchedResultsController.object(at: indexPath) as! Stock
//            let id = stock.id
//            OperationQueue.main.addOperation {
//                stock.list = self.sectionBySearch
//                self.saveContext()
//                if let sims = self.masterUI?.getStock().removeStock(id) {  //等tableView重刷完畢才能移除
//                    self.simPrices = sims
//                }
//                if self.simPrices.count == 1 {
//                    self.importFromDictionary()  //把預設的台積電加回來
//                    self.reloadTable()
//                }
//                self.isNotEditingList = true
//            }
//
//
//        }
//    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.endEditing(true)
        let stock = fetchedResultsController.object(at: indexPath) as! Stock
        if stock.list == coreData.shared.sectionInList {
            //選到的股在回主畫面時切換到該股
            if let prevId = masterUI?.getStock().setSimId(newId:stock.id) {
                if stockIdCopy == "" {
                    stockIdCopy = prevId
                }
            }
        } else {
            //選到搜尋股則取消選取
            if stock.list == coreData.shared.sectionBySearch {  //但暫停股不要取消選取才看得出來是哪一筆
                tableView.deselectRow(at: indexPath, animated: true)
            }
            if stockIdCopy != "" {  //避免回主畫面時此選定Id無效以stockIdCopy還原前選定股
                let _ = masterUI?.getStock().setSimId(newId:stockIdCopy)
                stockIdCopy = ""
            }
        }
    }













    func reloadTable() {
        _fetchedResultsController = nil
        if let _ = self.fetchedResultsController.fetchedObjects {   ////這會觸動performFetch
            self.tableView.reloadData()
        }
    }




    //========== Search Bar Delegate ==========
    @IBOutlet weak var uiSearchBar: UISearchBar!

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.clearNoDataElement()

    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if importingFromInternet {
            return
        }
        if searchOrDownload () == true {
            self.importFromInternet()   //去下載完整的名單，然後再查詢一次
            self.waitForImportFromInternet.notify(queue: DispatchQueue.main, execute: {
                _ = self.searchOrDownload ()
            })
        }


    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if importingFromInternet {
            return
        }
        self.searchString = searchText.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "  ", with: " ").replacingOccurrences(of: "  ", with: " ")
        if searchText == "" {
            self.clearNoDataElement()
        }

    }

    func searchOrDownload () -> Bool {  //true if need download
        addedStock = ""
        foundStock = ""
        self.reloadTable()  //有關鍵字了，重查詢table
        var scrollToIndex:IndexPath = IndexPath(row: 0, section: 0) //捲到頂
        var noSearched:Bool = true
        if let sections = fetchedResultsController.sections {
            for s in sections {
                if s.name == coreData.shared.sectionBySearch {
                    noSearched = false
                    break
                }
            }
        }
        if noSearched || dateStockListDownloaded.compare(Date.distantPast) == ComparisonResult.orderedSame {   //只有已建檔代號，沒有搜尋來的代號，或還沒下載股票代號名稱 --> 可能沒找到或是還沒下載
            let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
            if calendar.isDateInToday(dateStockListDownloaded) {
                //已經下載過 --> 確定沒有搜尋結果，且今天剛下載不用更新，那結論就是找不到了
                let stocks:[Stock] = fetchedResultsController.fetchedObjects as! [Stock]
                for stock in stocks {
                    if stock.id == searchString || stock.name == searchString {
                        foundStock = stock.id + " " + stock.name    //稍後顯示於section header
                        uiSearchBar.text = ""
                        searchString = ""
                        tableView.reloadData()  //只是為了清搜尋列和重排tableview的相對位置
                        //已經在股群內就捲到那一列
                        if let indexPath = fetchedResultsController.indexPath(forObject: stock) {
                            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: UITableView.ScrollPosition.middle)
                            scrollToIndex = indexPath
                            tableView(tableView, didSelectRowAt: indexPath)    //還要在回主畫面時切換到該股
                        }
                        break
                    }
                }
                if foundStock == "" {   //新增"沒有符合的股票。"
//                    _ = self.updateStockList("",name: self.NoData,list: self.sectionBySearch, isNew:true)
//                    self.saveContext()
                    let updated = coreData.shared.updateStock(id:"", name: coreData.shared.NoData, list: coreData.shared.sectionBySearch)
                    coreData.shared.saveContext(updated.context)
                }
            } else {
                return true     //還沒下載過 --> 等下要去下載，然後再來 searchOrDownload ()
            }
        }
        //有搜尋到，而且只有1筆，就自動加入股群
        if let sections = fetchedResultsController.sections {
            if sections[0].name == coreData.shared.sectionBySearch && sections[0].numberOfObjects == 1 {
                if let stock = sections[0].objects?.first as? Stock {
                    if stock.name != coreData.shared.NoData {
                        uiSearchBar.text = ""
                        searchString = ""
                        addedStock = stock.id + " " + stock.name    //顯示於section header
                        stock.list = coreData.shared.sectionInList
                        coreData.shared.saveContext()
                        if let sims = masterUI?.getStock().addNewStock(id:stock.id,name:stock.name) {
                            self.simPrices = sims
                        }
                        self.tableView.scrollToRow(at: scrollToIndex, at: .middle, animated: true)
                        return false    //就不要endEditing
                    }
                }
            }
        }
        self.view.endEditing(true)
        self.tableView.scrollToRow(at: scrollToIndex, at: .middle, animated: true)
        return false    //有東西，不用下載

    }



    func clearNoDataElement () {
        if importingFromInternet {
            return
        }
        addedStock = ""
        foundStock = ""
        searchString = ""
        self.uiSearchBar.text = ""
        OperationQueue().addOperation{
            coreData.shared.deleteStock(name: [coreData.shared.NoData])   //self.fetchNoDataElement()
            OperationQueue.main.addOperation() {
                self.reloadTable()
            }
        }
    }



}
