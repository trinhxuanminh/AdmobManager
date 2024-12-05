# AdMobManager

A package to help support the implementation of ads on your **iOS** app.
- For Swift 5.3, Xcode 12.5 (macOS Big Sur) or later.
- Support for apps from iOS 13.0 or newer.

## Ad Type
- InterstitialAd
- RewardedAd
- RewardedInterstitialAd
- AppOpenAd
- NativeAd
- BannerAd

## Installation

### Swift Package Manager

The Swift Package Manager is a tool for managing the distribution of **Swift** code. To use `AdMobManager` with Swift Package Manger, add it to dependencies in your `Package.swift`.
```swift
  dependencies: [
    .package(url: "https://github.com/trinhxuanminh/AdMobManager.git")
]
```

## Get started
Initial setup as documented by _Google AdMob_:
- [Update your Info.plist](https://developers.google.com/admob/ios/quick-start?hl=vi#update_your_infoplist)

Manually add the `-ObjC` linker flag to `Other Linker Flags` in your target's build settings:
- Select target project.
- Select tab `All`, find `Other Linker Flags`.
- You must set the `-ObjC` flag for both the `Debug` and `Release` configurations.

Integrate Firebase RemoteConfig with any `Key name` and configure it in [this json format](https://github.com/trinhxuanminh/AdMobManager/blob/develop/4.8.0/Sources/AdMobManager/Ad/Template/RegistrationStructure.json).
**Note**: The name of each ad is unique.

## Demo
Refer to the following [Demo project](https://github.com/trinhxuanminh/DemoAdMobManager/tree/develop/4.8.0) to implement the ad.

## Usage
Firstly, import `AdMobManager`.
```swift
import AdMobManager
```

### 1. Parameter setting

#### Upgrade premium
This function will block registration, loading, and show ads.
**Note**: Priority to use before registration and use after successful premium purchase.
```swift
AdMobManager.shared.upgradePremium()
```

#### ConfigValue
The function allows receiving additional values from RemoteConfig.
```swift
AdMobManager.shared.addActionConfigValue(_ handler: @escaping ((RemoteConfig) -> Void))
```

#### Register advertising ID
```swift
AdMobManager.shared.register(remoteKey: String, defaultData: Data)
```
- remoteKey: The `Key name` you have set on RemoteConfig.
- defaultData: The data of the default json string in the application, it is used when the remote cannot be loaded.

### 2. Control
#### state
Status of consent.
- `unknow`: Consent has not been requested, do not call show splash in this state.
- `allow`: Agreed. Call to load ads in this state.
- `reject`: Denied.

#### status()
This function returns the value _**true/false**_ indicating whether the ad is allowed to show. You can call it to make UI changes, logic in your code.
- Returns _**nil**_ when registration is not successful or there is no ad with the corresponding name.
```swift
AdMobManager.shared.status(type: AdType, name: String) -> Bool?
```

#### load()
This function will start loading ads.
```swift
AdMobManager.shared.load(type: Reuse,
                         name: String,
                         success: Handler? = nil,
                         fail: Handler? = nil)
```

#### preloadNative()
This function will start preloading `NativeAd`.
```swift
AdMobManager.shared.preloadNative(name: String,
                                  success: Handler? = nil,
                                  fail: Handler? = nil)
```

#### show()
This function will display ads when ready.

##### Parameters:
- didFail: The block executes after the ad is not displayed.
- didEarnReward: The block handle the reward for the user.
- didHide: The block executes after the ad has disappeared.

```swift
AdMobManager.shared.show(type: Reuse,
                         name: String,
                         rootViewController: UIViewController,
                         didFail: Handler?,
                         didEarnReward: Handler? = nil,
                         didHide: Handler?)
```

#### requestConsentUpdate()
This function will display permission change form.
```swift
AdMobManager.shared.requestConsentUpdate()
```

### 3. NativeAd
- Download & add file [`CustomNativeAdView.xib`](https://github.com/trinhxuanminh/AdMobManager/blob/develop/4.8.0/Sources/AdMobManager/Ad/Template/CustomNativeAdView.xib).
**Note**: Linked outlets to views, update constraints only.
- Create the corresponding `File's owner`, inherit `NativeAdMobView`.
```swift
class CustomNativeAdView: NativeAdMobView {
  override func setProperties() {
    load(name: String,
         nativeAdView: GADNativeAdView,
         rootViewController: UIViewController? = nil,
         didReceive: Handler?,
         didError: Handler?)
  }
}
```
- Ads will be loaded automatically.
- Call `binding` method to display ads when loading successfully.

### 4. BannerAd
Ads will be loaded automatically.
Then, there are two ways you can create `BannerAdMobView`:
- By storyboard, changing class of any `UIView` to `BannerAdMobView`. _**Note**: Set `Module` to `AdMobManager`._
- By code, using initializer.

```swift
bannerAdMobView.load(name: String, rootViewController: UIViewController, didReceive: Handler?)
```

# TrackingSDK

A package to help supports MMP AppsFlyer and ATT tracking integration on your **iOS** app.
- For Swift 5.3, Xcode 12.5 (macOS Big Sur) or later.
- Support for apps from iOS 13.0 or newer.

## Installation

### Swift Package Manager

The Swift Package Manager is a tool for managing the distribution of **Swift** code. To use `TrackingSDK` with Swift Package Manger, add it to dependencies in your `Package.swift`.
```swift
  dependencies: [
    .package(url: "https://github.com/trinhxuanminh/TrackingSDK.git")
]
```

## Get started
Add key - value to the file `Info.plist`.
```swift
  <key>FIREBASE_ANALYTICS_COLLECTION_ENABLED</key>
  <true/>
  <key>NSUserTrackingUsageDescription</key>
  <string>This will help us optimize the content and improve the app experience for you</string>
  <key>NSAdvertisingAttributionReportEndpoint</key>
  <string>https://appsflyer-skadnetwork.com/</string>
```

## Usage
Firstly, import `TrackingSDK`.
```swift
import TrackingSDK
```

### 1. Parameter setting

#### initialize()
Initialize, start tracking once permission is granted.

##### Parameters:
- devKey: The AppsFlyer dev key.
- appID: The Apple App ID (without the id prefix).
- timeout: Set `timeout` as such that app users have enough time to see and engage with the ATT prompt. 
```swift
TrackingSDK.shared.initialize(devKey: String, appID: String, timeout: Double? = nil)
```

### 2. Control
#### debug()
You can enable debug logs.
```swift
TrackingSDK.shared.debug(enable: Bool)
```

#### status()
This function indicates whether tracking authorization needs to be displayed.
```swift
TrackingSDK.shared.status() -> Bool
```

#### requestAuthorization()
This function will display the tracking authorization request.
```swift
TrackingSDK.shared.requestAuthorization(completed: Handler?)
```

## License
### [ProX Global](https://proxglobal.com)
### Copyright (c) Trịnh Xuân Minh 2022 [@trinhxuanminh](minhtx@proxglobal.com)
