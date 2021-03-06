# simStock 小確幸股票模擬機

！！！試改寫為[simStock21](https://github.com/peiyu66/simStock21)，沒意外的話這邊不會再更新了吧。

* 備份的[說明頁面](https://peiyu66.github.io/simStock-Documents-legacy-version/home.html)

<br><br><br>

小確幸下載台灣上市股票歷史成交價格，設計簡單的買賣規則，模擬買賣及評估報酬率。

資料來源：TWSE、Yahoo!、CNYES，詳見[wiki](https://github.com/peiyu66/simStock/wiki/資料來源)。


### import frameworks
simStock需要以下framework：
* [LINE SDK for iOS](https://github.com/archmagees/LineSDK) 用來輸出日報表到LINE。
    * 需先登錄[LINE Developers](https://developers.line.me/en/)，再來[這裡](https://developers.line.me/en/docs/ios-sdk/)下載LINESDK.framework。
    * 參考[Integrate LINE Login with your iOS app](https://developers.line.me/en/docs/line-login/ios/integrate-line-login/)有詳細的說明，所需匯入的frameworks包括：
        * LINESDK.framework
        * Security.framework
        * CoreTelephony.framework

* [SSZipArchive](https://github.com/ZipArchive/ZipArchive) 用來壓縮csv匯出檔案。
    * 原本應可比照LINE SDK來[這裡](https://github.com/ZipArchive/ZipArchive/releases)直接下載ZipArchive.framework，但是我試了好像link有問題總是失敗。所以只好下載source重新編譯。
    * 從[這裡](https://github.com/ZipArchive/ZipArchive)下載副本，但僅複製ZipArchive.xcodeproj和SSZipArchive（內含minizip）並加入到simStock專案內。
    * 在Xcode的Product/Scheme/Manage Schemes...刪除macOS,tvOS,watchOS的scheme版本，只保留iOS。
    * 在Xcode的ZipArchive.xcodeproj刪除macOS,tvOS,watchOS的target版本，只保留iOS。
    * 在Xcode的Build Phases中，把ZipArchive.framework(iOS)加入到"Link Binary With Libraries"和"Embed Frameworks"之內。
