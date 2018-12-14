//
//  settingViewController.swift
//  simPrice
//
//  Created by peiyu on 2016/9/12.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit

protocol settingDelegate:class {
    func changeInitMoney(_ money:Double)
    func changeDateEndSwitch(_ switchOn:Bool)
    func changeDatePicker(_ date:Date,settingItem:String)
}

class settingViewController: UITableViewController, settingDelegate {

    var sim:simPrice?
    var settingWhichDate:String = ""
    var defaultYearsMax:Int = {
        let defaults = UserDefaults.standard
        let yearsMax = defaults.integer(forKey: "defaultYearsMax")
        if yearsMax > 0 {
            return yearsMax
        } else {
            return 5
        }

    } ()

    func dateFormat(_ format:String?=nil) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-TW")
        if let _ = format {
            formatter.dateFormat = format
        }
        return formatter
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        if let _ = sim {
            let defaults = UserDefaults.standard
            defaultYearsMax = defaults.integer(forKey: "defaultYearsMax")
        } else {
            self.dismiss(animated: true, completion: {})
        }

    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 6
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row     = indexPath.row
        switch section {
        case 0:
            switch row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellInitMoney", for: indexPath) as! initMoneyCell
                cell.settingView = self  //settingDelegate
                 if let _ = sim {
                    let money = sim!.initMoney
                    var value:Float = 0
                    if money > 1000 {
                        value = round(31 + (Float(money) / 500))
                    } else if money > 500 {
                        value = round(23 + (Float(money) / 100))
                    } else if money > 100 {
                        value = round(18 + (Float(money) / 50))
                    } else {
                        value = (round(Float(money) / 10) * 2) - 1
                    }
                    cell.uiMoney.adjustsFontSizeToFitWidth = true
                    cell.uiMoney.text = String(format:"%.f萬元",money)
                    cell.uiMoneySlider.setValue(value, animated: false)
                }
                return cell

            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDateLabel", for: indexPath) as! dateLabelCell
                cell.uiDateLabelTitle.text = "起始日期"
                if let _ = sim {
                    let dateFormatter = self.dateFormat("yyyy/MM/dd")
                    cell.uiDateLabel.text = dateFormatter.string(from: sim!.dateStart as Date)
                }
                return cell

            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDatePicker", for: indexPath) as! datePickerCell
                cell.settingView = self  //settingDelegate
                cell.settingItem = "dateStart"
                let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                let today = calendar.startOfDay(for: Date())
                cell.uiDatePicker.maximumDate = today  //起始日限制在5年前開始，到今天結束
                cell.uiDatePicker.minimumDate = (calendar as NSCalendar).date(byAdding: .year, value: (0 - defaultYearsMax), to: today, options: NSCalendar.Options.init(rawValue: 0))
                if let _ = sim {
                    cell.uiDatePicker.date = sim!.dateStart as Date
                }
                return cell

            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDateSwitch", for: indexPath) as! dateSwitchCell
                cell.settingView = self  //settingDelegate
                if let _ = sim {
                    cell.uiDateSwitch.setOn(sim!.dateEndSwitch, animated: false)
                }
                return cell

            case 4:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDateLabel", for: indexPath) as! dateLabelCell
                cell.uiDateLabelTitle.text = "截止日期"
                if let _ = sim {
                    let dateFormatter = self.dateFormat("yyyy/MM/dd")
                    cell.uiDateLabel.text = dateFormatter.string(from: sim!.dateEnd as Date)
                }
                return cell

            case 5:
                let cell = tableView.dequeueReusableCell(withIdentifier: "cellDatePicker", for: indexPath) as! datePickerCell
                cell.settingView = self  //settingDelegate
                cell.settingItem = "dateEnd"
                if let _ = sim {
                    cell.uiDatePicker.minimumDate = sim!.dateStart as Date   //截止日限制從起始日開始，不限制結束日期
                    cell.uiDatePicker.date = sim!.dateEnd as Date
                }
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = indexPath.row
        switch row {
        case 1:
            if settingWhichDate == "dateStart" {
                settingWhichDate = ""
            } else {
                settingWhichDate = "dateStart"
            }

        case 4:
            if settingWhichDate == "dateEnd" {
                settingWhichDate = ""
            } else {
                settingWhichDate = "dateEnd"
            }

        default:
            settingWhichDate = ""
        }
        if settingWhichDate != "" {
            _ = indexPath.row.advanced(by: 1)   //移動到下一列，即datePicker
            tableView.scrollToRow(at: indexPath, at: .none, animated: false)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        var height:CGFloat = 44
        let row = indexPath.row
        switch row {
        case 2:
            if settingWhichDate == "dateStart" {
                height = 150
            } else {
                height = 0
            }
        case 4:
            if let _ = sim {
                if sim!.dateEndSwitch {
                    height = 44
                } else {
                    height = 0
                }
            }
        case 5:
            if settingWhichDate == "dateEnd" {
                height = 150
            } else {
                height = 0
            }
        default:
            break
        }

        return height
        
    }





    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let height:CGFloat = 36
        return height
    }


    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellSettingButton") as! settingButtonCell
//        uiWillResetMoneyButton = cell.uiWillResetMoney
        if sim!.maxMoneyMultiple > 1 || sim!.willGiveMoney {
            if sim!.willResetMoney {
                cell.uiWillResetMoney.setTitle("取消清除加碼", for: UIControl.State())
            } else {
                cell.uiWillResetMoney.setTitle("清除加碼", for: UIControl.State())
            }
            cell.uiWillResetMoney.isHidden = false
        } else {
            cell.uiWillResetMoney.isHidden = true
        }

        let header = cell.contentView
        return header

    }

//    var uiWillResetMoneyButton:UIButton?

    @IBAction func uiResetMoney(_ sender: UIButton) {
        if let _ = sim {
            if sender.titleLabel?.text == "清除加碼" {
                if sim!.willGiveMoney  {
                    sim!.willGiveMoney = false
                }
                if  sim!.maxMoneyMultiple <= 1 {
                    sender.isHidden = true
                } else {
                    sender.setTitle("取消清除加碼", for: UIControl.State())
                }
                sim!.willResetMoney = true
            } else {
                sim!.willResetMoney = false
                sender.setTitle("清除加碼", for: UIControl.State())
            }
        }
    }

    @IBAction func uiSetToDefault(_ sender: UIButton) {
        settingWhichDate = ""
        if let _ = sim {
            sim!.resetToDefault()
        }
        tableView.reloadData()
    }

    func changeInitMoney(_ money:Double) {
        if let _ = sim {
            sim!.initMoney = money
        }
        settingWhichDate = ""
        tableView.reloadData()
    }

    func changeDatePicker (_ date:Date,settingItem:String) {

        switch settingItem {
        case "dateStart":
            let indexPath = IndexPath(row: 1, section: 0)
            let cell = tableView.cellForRow(at: indexPath) as! dateLabelCell
            let dateFormatter = self.dateFormat("yyyy/MM/dd")
            cell.uiDateLabel.text = dateFormatter.string(from: date)
            if let _ = sim {
                sim!.dateStart(date)
                sim!.willResetMoney = false
            }
        case "dateEnd":
            let indexPath = IndexPath(row: 4, section: 0)
            let cell = tableView.cellForRow(at: indexPath) as! dateLabelCell
            let dateFormatter = self.dateFormat("yyyy/MM/dd")
            cell.uiDateLabel.text = dateFormatter.string(from: date)
            if let _ = sim {
                sim!.dateEnd = date
            }
        default:
            break
        }
        tableView.reloadData()
    }

    func changeDateEndSwitch(_ switchOn:Bool) {
        if let _ = sim {
            sim!.dateEndSwitch = switchOn
        }
        if switchOn {
            settingWhichDate = "dateEnd"
        } else {
            settingWhichDate = ""
        }
        tableView.reloadData()
    }


}
