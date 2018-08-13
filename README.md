# simStock
小確幸股票模擬機

小確幸下載台灣上市股票歷史成交價格，設計簡單的買賣規則，模擬買賣及評估報酬率。

版本說明： https://sites.google.com/site/appsimstock/ban-ben-shuo-ming


### import frameworks
simStock需要以下framework：
* [LINE SDK for iOS](https://github.com/archmagees/LineSDK) 用來輸出日報表或查錯用的log到LINE。
    * 需先登錄[LINE Developers](https://developers.line.me/en/)，再來[這裡](https://developers.line.me/en/docs/ios-sdk/)下載LINESDK.framework。
    * 參考[Integrate LINE Login with your iOS app](https://developers.line.me/en/docs/line-login/ios/integrate-line-login/)有詳細的說明，所需匯入的frameworks包括：
        * LINESDK.framework
        * Security.framework
        * CoreTelephony.framework
* [SSZipArchive](https://github.com/ZipArchive/ZipArchive) 用來壓縮csv匯出檔案。
    * 從[這裡](https://github.com/ZipArchive/ZipArchive)下載副本，但僅複製ZipArchive.xcodeproj和SSZipArchive（內含minizip）並加入專案內。
    * 在Xcode的Product/Scheme/Manage Schemes...刪除macOS,tvOS,watchOS的scheme版本，只保留iOS。
    * 在Xcode的ZipArchive.xcodeproj刪除macOS,tvOS,watchOS的target版本，只保留iOS。
    * 在Xcode的Build Phases中，把ZipArchive.framework(iOS)加入到"Link Binary With Libraries"和"Embed Frameworks"之內。
