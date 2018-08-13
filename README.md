# simStock
小確幸股票模擬機

小確幸下載台灣上市股票歷史成交價格，設計簡單的買賣規則，模擬買賣及評估報酬率。

版本說明： https://sites.google.com/site/appsimstock/ban-ben-shuo-ming


### import frameworks
simStock需要以下元件：
* [LINE SDK for iOS](https://github.com/archmagees/LineSDK) 用來輸出日報表或查錯用的log到LINE。
    * 需先登錄[LINE Developers](https://developers.line.me/en/)，再來[這裡](https://developers.line.me/en/docs/ios-sdk/)下載LINESDK.framework。
    * 參考[Integrate LINE Login with your iOS app](https://developers.line.me/en/docs/line-login/ios/integrate-line-login/)有詳細的說明，所需匯入的frameworks包括：
        * LINESDK.framework
        * Security.framework
        * CoreTelephony.framework
* [SSZipArchive](https://github.com/ZipArchive/ZipArchive) 用來壓縮csv匯出檔案。
    * 來[這裡](https://github.com/ZipArchive/ZipArchive/releases)下載ZipArchive.framework。
    * 在Xcode的Build Phases中除了把ZipArchive.framework加入"Link Binary With Libraries"，也要加入到"Embed Frameworks"。
