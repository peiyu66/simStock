//
//  priceCell.swift
//  simStock
//
//  Created by peiyu on 2016/4/1.
//  Copyright © 2016年 unLock.com.tw. All rights reserved.
//

import UIKit

protocol priceCellDelegate:class {
    func moneyChanging (_ sender:UITableViewCell,changeFactor:Double)
    func reverseAction (_ sender:UITableViewCell,button:UIButton)
}

//******************************************
//********** 價格與模擬明細的介面元件 **********
//******************************************

class priceCell: UITableViewCell {
    var masterView:priceCellDelegate?

    @IBOutlet weak var uiDate: UILabel!
    @IBOutlet weak var uiTime: UILabel!
    @IBOutlet weak var uiClose: UILabel!
    @IBOutlet weak var uiDivCash: UILabel!
    @IBOutlet weak var uiConsDivCash: NSLayoutConstraint!
    
    @IBOutlet weak var uiSimDays: UILabel!
    @IBOutlet weak var uiSimIncome: UILabel!
    @IBOutlet weak var uiSimTrans1: UILabel!
    @IBOutlet weak var uiSimTrans2: UILabel!
    @IBOutlet weak var uiSimUnitCost: UILabel!
    @IBOutlet weak var uiSimUnitDiff: UILabel!
    @IBOutlet weak var uiMoneyBuy: UILabel!
    @IBOutlet weak var uiSimMoney: UILabel!
    @IBOutlet weak var uiSimCost: UILabel!
    @IBOutlet weak var uiLabelCost: UILabel!
    @IBOutlet weak var uiSimPL: UILabel!
    @IBOutlet weak var uiLabelPL: UILabel!

    @IBOutlet weak var uiLabelUnitCost: UILabel!
    @IBOutlet weak var uiLabelUnitDiff: UILabel!
    @IBOutlet weak var uiLabelIncome: UILabel!
    @IBOutlet weak var uiTipForQty: UILabel!

    @IBOutlet weak var uiOpen: UILabel!
    @IBOutlet weak var uiHigh: UILabel!
    @IBOutlet weak var uiLow: UILabel!
    @IBOutlet weak var uiLabelLow: UILabel!
    @IBOutlet weak var uiLabelHigh: UILabel!
    @IBOutlet weak var uiLabelOpen: UILabel!

    @IBOutlet weak var uiK: UILabel!
    @IBOutlet weak var uiD: UILabel!
    @IBOutlet weak var uiJ: UILabel!
    @IBOutlet weak var uiMA20: UILabel!
    @IBOutlet weak var uiMA60: UILabel!
    @IBOutlet weak var uiLabelD: UILabel!
    @IBOutlet weak var uiLabelK: UILabel!
    @IBOutlet weak var uiLabelJ: UILabel!
    @IBOutlet weak var uiLabelRank: UILabel!
    @IBOutlet weak var uiMacdOsc: UILabel!
    @IBOutlet weak var uiUpdatedBy: UILabel!

    @IBOutlet weak var uiLabelClose: UILabel!
    @IBOutlet weak var uiSimROI: UILabel!

    @IBOutlet weak var uiButtonIncrease: UIButton!
    @IBOutlet weak var uiTipForButton: UILabel!
    @IBOutlet weak var uiSimReverse: UIButton!

    @IBOutlet weak var uiMA20Diff: UILabel!
    @IBOutlet weak var uiMA60Diff: UILabel!
    @IBOutlet weak var uiMADiff: UILabel!
    @IBOutlet weak var uiMA20Min: UILabel!
    @IBOutlet weak var uiMA60Min: UILabel!
    @IBOutlet weak var uiMAMin: UILabel!
    @IBOutlet weak var uiMA20Max: UILabel!
    @IBOutlet weak var uiMA60Max: UILabel!
    @IBOutlet weak var uiMAMax: UILabel!
    @IBOutlet weak var uiMA20Days: UILabel!
    @IBOutlet weak var uiMA60Days: UILabel!
    @IBOutlet weak var uiMADays: UILabel!
    @IBOutlet weak var uiLabelMA20Diff: UILabel!
    @IBOutlet weak var uiLabelMA60Diff: UILabel!

    @IBOutlet weak var uiPrice60HighLow: UILabel!
    @IBOutlet weak var uiRank: UILabel!
    @IBOutlet weak var uiOscHL: UILabel!

    @IBOutlet weak var uiBaseK: UILabel!
    @IBOutlet weak var uiMa20DiffHL: UILabel!
    @IBOutlet weak var uiMa60DiffHL: UILabel!



    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func uiIncreasePrincipal(_ sender: UIButton) {
        masterView?.moneyChanging(self, changeFactor: 1)
    }

    @IBAction func uiReverse(_ sender: UIButton) {
        masterView?.reverseAction(self, button: sender)
    }
}







//****************************************
//********** 模擬參數的輸入介面元件 **********
//****************************************

class settingButtonCell:UITableViewCell {
    @IBOutlet weak var uiWillResetMoney: UIButton!

}


class initMoneyCell: UITableViewCell {
    var settingView:settingDelegate?
    @IBOutlet weak var uiMoney: UILabel!
    @IBOutlet weak var uiMoneySlider: UISlider!

    @IBAction func uiMoneyChanged(_ sender: UISlider) {
        var value:Float = sender.value
        value = round(value)
        sender.setValue(value, animated: false)
        var money:Double = 100
        if value > 33 {
            money = Double(value - 31) * 500
        } else if value > 28 {
            money = Double(value - 23) * 100
        } else if value > 19 {
            money = Double(value - 18) * 50
        } else {
            money = ceil(Double(value + 1) / 2) * 10
        }
        uiMoney.adjustsFontSizeToFitWidth = true
        uiMoney.text = String(format:"%.f萬元",money)
        settingView?.changeInitMoney(money)
    }

}

class dateLabelCell: UITableViewCell {
    @IBOutlet weak var uiDateLabelTitle: UILabel!
    @IBOutlet weak var uiDateLabel: UILabel!
}

class datePickerCell: UITableViewCell {
    var settingView:settingDelegate?
    var settingItem:String?
    @IBOutlet weak var uiDatePicker: UIDatePicker!
    @IBAction func uiDatePickerChanged(_ sender: UIDatePicker) {
         if let _ = settingItem {
            settingView?.changeDatePicker(sender.date, settingItem: settingItem!)
        } else {
            settingView?.changeDatePicker(sender.date, settingItem: "")
        }

    }
}

class dateSwitchCell: UITableViewCell {
    var settingView:settingDelegate?
    @IBOutlet weak var uiDateSwitch: UISwitch!
    @IBAction func uiDateSwitchChanged(_ sender: UISwitch) {
        let switchOn = sender.isOn
        settingView?.changeDateEndSwitch(switchOn)
    }
}










//*****************************************
//********** stockViewController **********
//*****************************************

class stockListCell: UITableViewCell {
    var stockView:stockViewDelegate?

    @IBOutlet weak var uiId: UILabel!
    @IBOutlet weak var uiName: UILabel!
    @IBOutlet weak var uiButtonAdd: UIButton!
    @IBOutlet weak var uiROI: UILabel!
    @IBOutlet weak var uiYears: UILabel!
    @IBOutlet weak var uiButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var uiMultiple: UILabel!
    @IBOutlet weak var uiDays: UILabel!

    @IBAction func uiCellAddButton(_ sender: UIButton) {
        stockView?.addSearchedToList(self)
    }

    @IBOutlet weak var uiCellPriceClose: UILabel!
    @IBOutlet weak var uiCellPriceUpward: UILabel!
    @IBOutlet weak var uiCellAction: UILabel!
    @IBOutlet weak var uiCellQty: UILabel!

}



//Class for ToolTip Label
class ToolTipUp: UILabel {

    var newRect:CGRect!

    override func drawText(in rect: CGRect) {
        super.drawText(in: newRect)
    }

    override func draw(_ rect: CGRect) {
        let tailSize:CGFloat = rect.height / 4
        newRect = CGRect(x: rect.minX, y: rect.minY + tailSize, width: rect.width, height: rect.height - tailSize)

        let triangleBez = UIBezierPath()
        triangleBez.move(to: CGPoint(x: rect.midX - (tailSize / 2), y:newRect.minY))
        triangleBez.addLine(to: CGPoint(x:rect.midX,y:rect.minY))
        triangleBez.addLine(to: CGPoint(x: rect.midX + (tailSize / 2), y:newRect.minY))
        triangleBez.close()

        UIColor.groupTableViewBackground.setFill()
        let roundRectBez = UIBezierPath(roundedRect: newRect, cornerRadius: 5)
        roundRectBez.append(triangleBez)
        roundRectBez.fill()
        
        super.draw(rect)
        
    }
    
}


