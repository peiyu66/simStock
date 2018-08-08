//
//  RuleTableViewController.swift
//  simStock
//
//  Created by peiyu on 2016/4/12.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit

protocol masterViewDelegate: class {
    func initParameters () -> [AnyObject] //[initPrincipal, dateStart, dateEndSwitch, dateEnd, dateEarlier, firstDate, lastDate]
    func removeAllPrices (id:String) -> Bool
}

class ruleViewController: UITableViewController, ruleViewDelegate, ruleStockListDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    var masterView:masterViewDelegate?
//    var defaults:NSUserDefaults?
    var defaults:NSUserDefaults = NSUserDefaults.standardUserDefaults()
    let dateformatter:NSDateFormatter = NSDateFormatter()

    var stockId:String = "0050"                 //--
    var stockNames:([String:String]) = [:]      //--- 這三個由masterView的prepareForSegue直接塞入
    var simStocks:([String:[AnyObject]]) = [:]  //--
    var aStockNames:([(String,String)]) = []
    var stockName:String = ""
    var previousId:String = ""
    var miniDate:Int = -5



    var initPrincipal:Double = 1000000
    var dateStart:NSDate = NSDate.distantPast()   //模擬起始日
    var dateEndSwitch:Bool = false                //指定截止日
    var dateEnd:NSDate = NSDate()                 //模擬截止日
    var dateEarlier:NSDate = NSDate.distantFuture()   //dateStart往前3個月
    var lastDate:NSDate = NSDate.distantPast()      //最久遠的過去
    var firstDate:NSDate = NSDate.distantFuture()   //最久遠的未來
    var ver:String = ""
    var dividendDates:[NSDate] = []

    var waitForAllSimStock:Bool = false
    var defaultsChanged:Bool = false


    override func viewDidLoad() {
        super.viewDidLoad()
        aStockNames = Array(stockNames).sort{$0.1<$1.1}   //依照簡稱排序
        defaultsChanged    = false
        waitForAllSimStock = false
        previousId = stockId    //主畫面的id保留，滾輪動來動去，最後才知道是不是被換過

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //stockId不管有沒有被換過，根據目前的id抓出其參數以供tableView顯示
        reloadParameters ()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.endEditing(true)
//        var newSims:Bool = true
//        if let _ = simStocks[stockId] {
//            newSims = false
//        }
        if defaultsChanged || waitForAllSimStock {
            self.defaults.setObject(self.stockId, forKey: "stockId")
            self.simStocks[self.stockId] = [initPrincipal, dateStart, dateEndSwitch, dateEnd, dateEarlier, firstDate, lastDate, ver, dividendDates]
            self.defaults.setObject(self.simStocks, forKey: "simStocks")
            if waitForAllSimStock {
                self.defaults.setObject(true, forKey: "waitForAllSimStock")
            }
        }

    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "segueStockList" {
            NSLog ("--> prepareForSegue:segueStockList")
            if let destViewController = segue.destinationViewController as? stockListViewController {
                destViewController.ruleView = self
                destViewController.stockNames = self.stockNames
                destViewController.simIds = Array(simStocks.keys)
                

                let backItem = UIBarButtonItem()
                backItem.title = ""
                navigationItem.backBarButtonItem = backItem
            }
        }
    }

    func stockNamesReload(stockNames:[String:String]) {
        self.stockNames = stockNames
        self.aStockNames = Array(stockNames).sort{$0.1<$1.1}   //依照簡稱排序
        ruleViewReloadData ()
    }

    // MARK: - Table view data source



    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 8    //股票代號、股票名稱picker、起始本金、起始日期、起始日期picker、指定截止日switch、截止日期picker
        default:
            return 0
        }
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "輸入股票代號，或用滾輪切換常用代號。\n或點股票簡稱，可搜尋和管理常用代號。"
        default:
            return ""
        }
    }

    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return ""
        default:
            return ""
        }
    }

    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int)
    {
        let title = UILabel()
        if self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
            title.font = UIFont(name: "Futura", size: 16)
        } else {
            title.font = UIFont(name: "Futura", size: 14)
        }
        title.textColor = UIColor.lightGrayColor()

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font=title.font
        header.textLabel?.textColor=title.textColor
    }



    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCellWithIdentifier("stockIdCell", forIndexPath: indexPath) as! stockIdCell
                cell.ruleView = self
//                cell.defaults = self.defaults
                cell.uiStockId.text = self.stockId  //(defaults.objectForKey("stockId") as! String)
                cell.uiStockId.clearButtonMode = .WhileEditing

                if let stockName = stockNames[cell.uiStockId.text!] {
                    cell.uiStockName.text = stockName
                    cell.uiStockName.adjustsFontSizeToFitWidth = true
                } else {
                    cell.uiStockName.text = ""
                }
                cell.stockNames = stockNames


                return cell
            case 1:
                let cell = tableView.dequeueReusableCellWithIdentifier("stockPickerCell", forIndexPath: indexPath) as! stockPickerCell
                cell.uiStockPicker.dataSource = self
                cell.uiStockPicker.delegate = self
                ruleStockPickerScrollTo(self.stockId,cell:cell)

                return cell
            case 2:
                let cell = tableView.dequeueReusableCellWithIdentifier("initPrincipalCell", forIndexPath: indexPath) as! initPrincipalCell
                cell.ruleView = self
                let initPrincipal:Double = self.initPrincipal / 10000
                cell.uiPrincipal.text = String(format:"%.0f",initPrincipal)
                cell.uiPrincipal.clearButtonMode = .WhileEditing

                return cell
            case 3:
                let cell = tableView.dequeueReusableCellWithIdentifier("dateCell", forIndexPath: indexPath) as! dateCell
                cell.uiCellTitle.text = "起始日期"
                dateformatter.locale = NSLocale(localeIdentifier: "zh-TW")
                dateformatter.dateFormat = "yyyy/MM/dd"
                cell.uiCellDetail.text = dateformatter.stringFromDate(self.dateStart)
                return cell
            case 4:
                let cell = tableView.dequeueReusableCellWithIdentifier("datePickerCell", forIndexPath: indexPath) as! datePickerCell
                cell.ruleView = self
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                cell.uiDatePicker.maximumDate = (NSDate())  //起始日限制在5年前開始
                cell.uiDatePicker.minimumDate = calendar.dateByAddingUnit(.Year, value: miniDate, toDate: NSDate(), options: NSCalendarOptions.init(rawValue: 0))
                cell.uiDatePicker.date = self.dateStart
                cell.defaultsKey = "dateStart"
                return cell
            case 5:
                let cell = tableView.dequeueReusableCellWithIdentifier("dateSwitchCell", forIndexPath: indexPath) as! dateSwitchCell
                cell.ruleView = self
                cell.uiSwitch.setOn(self.dateEndSwitch, animated: false)
                return cell
            case 6:
                let cell = tableView.dequeueReusableCellWithIdentifier("dateCell", forIndexPath: indexPath) as! dateCell
                cell.uiCellTitle.text = "       截止日期"
                dateformatter.locale = NSLocale(localeIdentifier: "zh-TW")
                dateformatter.dateFormat = "yyyy/MM/dd"
                cell.uiCellDetail.text = dateformatter.stringFromDate(self.dateEnd)
                return cell
            case 7:
                let cell = tableView.dequeueReusableCellWithIdentifier("datePickerCell", forIndexPath: indexPath) as! datePickerCell
                cell.ruleView = self
                cell.uiDatePicker.minimumDate = (self.dateStart)
                cell.uiDatePicker.date = self.dateEnd
                cell.defaultsKey = "dateEnd"
                return cell
            default:
                let cell = UITableViewCell()
                return cell
            }
        default:
            let cell = UITableViewCell()
            return cell
        }
    }

    var showWhichPicker:String = ""

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let datePickerHeight: CGFloat = 200.0
        let normalCellHeight: CGFloat = 44.0

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 1:     //stockPicker
                if showWhichPicker == "stockPicker" {
                    return datePickerHeight
                } else {
                    return 0
                }
            case 4:     //picker
                if showWhichPicker == "dateStart" {
                    return datePickerHeight
                } else {
                    return 0
                }
            case 6:
                if self.dateEndSwitch  {
                    return normalCellHeight
                } else {
                    return 0
                }
            case 7:     //picker
                if showWhichPicker == "dateEnd" {
                    return datePickerHeight
                } else {
                    return 0
                }
            default:
                return normalCellHeight
            }
        default:    // section 1 the rule cells
             return normalCellHeight
        }
    }


    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        tableView.endEditing(true)   //關閉鍵盤
        switch indexPath.section {
        case 0:
            switch indexPath.row {
//            case 0:
//                if showWhichPicker == "stockPicker" {
//                    showWhichPicker = ""
//                } else {
//                    showWhichPicker = "stockPicker"
//                }
            case 3:
                if showWhichPicker == "dateStart" {   //重複點就收起來，第一次點就打開picker
                    showWhichPicker = ""
                } else {
                    showWhichPicker = "dateStart"
                }
            case 6:
                if showWhichPicker == "dateEnd" {
                    showWhichPicker = ""
                } else {
                    showWhichPicker = "dateEnd"
                }
           default:
                showWhichPicker = ""
            }
        default:    // section 1 the rule cells
            showWhichPicker = ""
        }

        tableView.beginUpdates()
        tableView.endUpdates()

        if showWhichPicker != "" {
            // This ensures, that the cell is fully visible once expanded
            indexPath.row.advancedBy(1)   //移動到下一列，即datePicker
            tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .None, animated: false)
        }
    }

    func ruleViewBeginUpdates (action:String) {
        switch action {
        case "noPicker":
            showWhichPicker=""
        case "stockPicker":
            showWhichPicker="stockPicker"
        case "clear":
            showWhichPicker=""
            tableView.endEditing(true)   //關閉鍵盤
        default:
            break
        }
        tableView.beginUpdates()
        tableView.endUpdates()
     }

    func ruleViewReloadData () {
        tableView.reloadData()
    }

    func ruleSetParameter(key:String,value:AnyObject) {
        switch key {
        case "stockId":
            let id:String = value as! String
            if id.characters.count >= 4 {
                self.stockId        = id
                ruleStockPickerScrollTo(self.stockId)
            } else {    //碼數不足是無效id則復原
                let cell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! stockIdCell
                cell.uiStockId.text = self.stockId
            }
        case "initPrincipal":
            self.initPrincipal  = value as! Double
        case "dateStart":
            self.dateStart      = value as! NSDate
        case "dateEndSwitch":
            self.dateEndSwitch  = value as! Bool
        case "dateEnd":
            self.dateEnd        = value as! NSDate
        case "dateEarlier":
            self.dateEarlier    = value as! NSDate
        case "firstDate":
            self.firstDate      = value as! NSDate
        case "lastDate":
            self.lastDate       = value as! NSDate
        default:
            break
        }
        if previousId != stockId {
            defaultsChanged = true
        } else {
            defaultsChanged = false
        }
        if key != "stockId" {
            defaultsChanged = true
            waitForAllSimStock = true
        }
    }

    func ruleGetParameter(key:String) -> AnyObject{
        switch key {
        case "initPrincipal":
            return self.initPrincipal
        case "dateStart":
            return self.dateStart
        case "dateEndSwitch":
            return self.dateEndSwitch
        case "dateEnd":
            return self.dateEnd
        case "dateEarlier":
            return self.dateEarlier
        case "firstDate":
            return self.firstDate
        case "lastDate":
            return self.lastDate
        default:
            return 0
        }
    }

    //===== stockId Picker dataSource and delegate =====
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return stockNames.count
    }

    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let key = aStockNames[row].0  //這是股票代號
        if let _ = simStocks[key] {
            return "∙ "+key + " " + stockNames[key]!    //已經存在於資料庫，是觀察中股票，做個 ∙ 標記
        } else {
            return key + " " + stockNames[key]!
        }
    }

    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let cell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0)) as! stockIdCell
        self.stockId = aStockNames[row].0   //這是股票代號
        reloadParameters ()
        cell.uiStockId.text = self.stockId
        cell.uiStockName.text = self.stockName
        ruleViewReloadData ()
        if previousId != stockId {
            defaultsChanged = true
        } else {
            defaultsChanged = false
        }
    }

    func reloadParameters () {
        if let sName = self.stockNames[self.stockId] {
            self.stockName = sName
        } else {
            self.stockName = ""
        }
        if !waitForAllSimStock {
            if let _ = simStocks[stockId] {
                self.initPrincipal  = simStocks[stockId]?[0] as! Double
                self.dateStart      = simStocks[stockId]?[1] as! NSDate
                self.dateEndSwitch  = simStocks[stockId]?[2] as! Bool
                self.dateEnd        = simStocks[stockId]?[3] as! NSDate
                self.dateEarlier    = simStocks[stockId]?[4] as! NSDate
                self.firstDate      = simStocks[stockId]?[5] as! NSDate
                self.lastDate       = simStocks[stockId]?[6] as! NSDate
                if simStocks[stockId]?.count > 7 {
                    self.ver        = simStocks[stockId]?[7] as! String
                } else {
                    self.ver        = ""
                }
                if simStocks[stockId]?.count > 8 {
                    self.dividendDates        = simStocks[stockId]?[8] as! [NSDate]
                } else {
                    self.dividendDates        = []
                }

            } else {
                if let parameters = masterView?.initParameters() {
                    //[initPrincipal, dateStart, dateEndSwitch, dateEnd, dateEarlier, firstDate, lastDate, ver, dividendDates]
                    initPrincipal   = parameters[0] as! Double
                    dateStart       = parameters[1] as! NSDate
                    dateEndSwitch   = parameters[2] as! Bool
                    dateEnd         = parameters[3] as! NSDate
                    dateEarlier     = parameters[4] as! NSDate
                    firstDate       = parameters[5] as! NSDate
                    lastDate        = parameters[6] as! NSDate
                    ver             = parameters[7] as! String
                    dividendDates   = parameters[8] as! [NSDate]
                }
            }
        }

    }

    func ruleStockPickerScrollTo(stockId:String,cell:stockPickerCell?=nil) {  //捲到stockId那一列
        var pickerCell:stockPickerCell
        if let _ = cell {
            pickerCell = cell!
        } else {
            pickerCell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 1, inSection: 0)) as! stockPickerCell
        }
        if let row = aStockNames.indexOf({$0.0 == stockId}) {
            pickerCell.uiStockPicker.selectRow(row, inComponent: 0, animated: false)
        } else {
            reloadParameters()  //不在常用代號之內，捲不到，就給新參數
        }
    }

    func removeAllPrices (id:String) -> Bool {
        let isFront = masterView!.removeAllPrices (id)
        if isFront || id == stockId {
            //自dictionary移除代號之前，先試移動目前stockId到下支觀察股，以備稍後textField填入
            //這裡和shiftLeft相同邏輯
            var keys:[String]=[]
            let names = Array(stockNames).sort{$0.1<$1.1}
            for e in names {
                if let _ = simStocks[e.0] {
                    keys.append(e.0)
                }
            }
            if let index = keys.indexOf(stockId) {
                if index < keys.count - 1 {
                    stockId = keys[index+1]
                } else {        //循環到首筆
                    if index != 0 { //有首筆而且不是自己
                        stockId = keys[0]
                    }   //都沒有就不動
                }
            }
            defaultsChanged = true
        }

        simStocks.removeValueForKey(id)
        stockNames.removeValueForKey(id)
        defaultsChanged = true
        return isFront
    }


}

