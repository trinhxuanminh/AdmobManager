//
//  AdMobManager.swift
//  AdMobManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit
import FirebaseRemoteConfig
import GoogleMobileAds
import Combine
import UserMessagingPlatform

/// An ad management structure. It supports setting InterstitialAd, RewardedAd, RewardedInterstitialAd, AppOpenAd, NativeAd, BannerAd.
/// ```
/// import AdMobManager
/// ```
/// - Warning: Available for Swift 5.3, Xcode 12.5 (macOS Big Sur). Support from iOS 13.0 or newer.
public class AdMobManager {
  public static var shared = AdMobManager()
  
  public enum State {
    case unknow
    case allow
    case reject
  }
  
  public enum OnceUsed: String {
    case native
    case banner
  }
  
  public enum Reuse: String {
    case splash
    case appOpen
    case interstitial
    case rewarded
    case rewardedInterstitial
  }
  
  public enum AdType {
    case onceUsed(_ type: OnceUsed)
    case reuse(_ type: Reuse)
  }
  
  @Published public private(set) var state: State = .unknow
  private let remoteConfig = RemoteConfig.remoteConfig()
  private let consentKey = "CMP"
  private let remoteTimeout = 10.0
  private var subscriptions = [AnyCancellable]()
  private var remoteKey: String?
  private var defaultData: Data?
  private var didRemoteTimeout = false
  private var didSetup = false
  private var didRequestConsent = false
  private var isDebug = false
  private var testDeviceIdentifiers = [String]()
  private var configValue: ((RemoteConfig) -> Void)?
  private var isPremium = false
  private var adMobConfig: AdMobConfig?
  private var consentConfig: ConsentConfig?
  private var listReuseAd: [String: AdProtocol] = [:]
  private var listNativeAd: [String: NativeAd] = [:]
  
  public func upgradePremium() {
    self.isPremium = true
  }
  
  public func addActionConfigValue(_ handler: @escaping ((RemoteConfig) -> Void)) {
    self.configValue = handler
  }
  
  public func register(remoteKey: String,
                       defaultData: Data,
                       appID: String,
                       keyID: String,
                       issuerID: String,
                       privateKey: String
  ) {
    if isPremium {
      print("[AdMobManager] Premium!")
      self.state = .reject
    }
    guard self.remoteKey == nil else {
      return
    }
    print("[AdMobManager] Register!")
    LogEventManager.shared.log(event: .register)
    self.remoteKey = remoteKey
    self.defaultData = defaultData
    
    AutoRelease.shared.$isRelease
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isRelease in
        guard let self else {
          return
        }
        guard isRelease != nil else {
          return
        }
        fetchConsentCache()
        fetchAdMobCache()
        fetchRemote()
      }.store(in: &subscriptions)
    
    AutoRelease.shared.check(appID: appID,
                             keyID: keyID,
                             issuerID: issuerID,
                             privateKey: privateKey)
  }
  
  public func status(type: AdType, placementID: String) -> Bool? {
    guard !isPremium else {
      print("[AdMobManager] Premium!")
      return nil
    }
    guard let adMobConfig else {
      print("[AdMobManager] Not yet registered!")
      return nil
    }
    guard adMobConfig.status else {
      return false
    }
    guard state == .allow else {
      print("[AdMobManager] Can't Request Ads!")
      return nil
    }
    guard let adConfig = getAd(type: type, placementID: placementID) as? AdConfigProtocol else {
      print("[AdMobManager] Ads don't exist! (\(placementID))")
      return nil
    }
    if AutoRelease.shared.isRelease == false, adConfig.isAuto == true {
      return false
    }
    return adConfig.status
  }
  
  public func load(type: Reuse,
                   placementID: String,
                   success: Handler? = nil,
                   fail: Handler? = nil
  ) {
    switch status(type: .reuse(type), placementID: placementID) {
    case false:
      print("[AdMobManager] Ads are not allowed to show! (\(placementID))")
      fail?()
      return
    case true:
      break
    default:
      fail?()
      return
    }
    guard let adConfig = getAd(type: .reuse(type), placementID: placementID) as? AdConfigProtocol else {
      print("[AdMobManager] Ads don't exist! (\(placementID))")
      fail?()
      return
    }
    guard listReuseAd[adConfig.name] == nil else {
      fail?()
      return
    }
    
    let adProtocol: AdProtocol!
    switch type {
    case .splash:
      guard let splash = adConfig as? Splash else {
        print("[AdMobManager] Format conversion error! (\(placementID))")
        fail?()
        return
      }
      let splashAd = SplashAd()
      splashAd.config(timeout: splash.timeout)
      adProtocol = splashAd
    case .appOpen:
      adProtocol = AppOpenAd()
    case .interstitial:
      adProtocol = InterstitialAd()
    case .rewarded:
      adProtocol = RewardedAd()
    case .rewardedInterstitial:
      adProtocol = RewardedInterstitialAd()
    }
    adProtocol.config(didFail: fail, didSuccess: success)
    adProtocol.config(id: adConfig.id, name: adConfig.name)
    self.listReuseAd[adConfig.name] = adProtocol
  }
  
  public func isReady(type: Reuse, placementID: String) -> Bool {
    switch status(type: .reuse(type), placementID: placementID) {
    case false:
      print("[AdMobManager] Ads are not allowed to show! (\(placementID))")
      return false
    case true:
      break
    default:
      return false
    }
    guard let adConfig = getAd(type: .reuse(type), placementID: placementID) as? AdConfigProtocol else {
      print("[AdMobManager] Ads don't exist! (\(placementID))")
      return false
    }
    guard let ad = listReuseAd[adConfig.name] else {
      print("[AdMobManager] Ads do not exist! (\(placementID))")
      return false
    }
    guard !checkIsPresent() else {
      print("[AdMobManager] Ads display failure - other ads is showing! (\(placementID))")
      return false
    }
    guard checkFrequency(adConfig: adConfig, ad: ad) else {
      print("[AdMobManager] Ads hasn't been displayed yet! (\(placementID))")
      return false
    }
    return true
  }
  
  public func preloadNative(placementID: String,
                            success: Handler? = nil,
                            fail: Handler? = nil
  ) {
    switch status(type: .onceUsed(.native), placementID: placementID) {
    case false:
      print("[AdMobManager] Ads are not allowed to show! (\(placementID))")
      fail?()
      return
    case true:
      break
    default:
      fail?()
      return
    }
    guard let native = getAd(type: .onceUsed(.native), placementID: placementID) as? Native else {
      print("[AdMobManager] Ads don't exist! (\(placementID))")
      fail?()
      return
    }
    guard native.isPreload == true else {
      print("[AdMobManager] Ads are not preloaded! (\(placementID))")
      fail?()
      return
    }
    guard listNativeAd[placementID] == nil else {
      fail?()
      return
    }
    let nativeAd = NativeAd()
    nativeAd.bind(didReceive: success, didError: fail)
    nativeAd.config(ad: native, rootViewController: nil)
    self.listNativeAd[placementID] = nativeAd
  }
  
  public func show(type: Reuse,
                   placementID: String,
                   rootViewController: UIViewController,
                   didFail: Handler?,
                   willPresent: Handler? = nil,
                   didEarnReward: Handler? = nil,
                   didHide: Handler?
  ) {
    switch status(type: .reuse(type), placementID: placementID) {
    case false:
      print("[AdMobManager] Ads are not allowed to show! (\(placementID))")
      didFail?()
      return
    case true:
      break
    default:
      didFail?()
      return
    }
    guard let adConfig = getAd(type: .reuse(type), placementID: placementID) as? AdConfigProtocol else {
      print("[AdMobManager] Ads don't exist! (\(placementID))")
      didFail?()
      return
    }
    guard let ad = listReuseAd[adConfig.name] else {
      print("[AdMobManager] Ads do not exist! (\(placementID))")
      didFail?()
      return
    }
    guard !checkIsPresent() else {
      print("[AdMobManager] Ads display failure - other ads is showing! (\(placementID))")
      didFail?()
      return
    }
    guard checkFrequency(adConfig: adConfig, ad: ad) else {
      print("[AdMobManager] Ads hasn't been displayed yet! (\(placementID))")
      didFail?()
      return
    }
    ad.show(placementID: adConfig.placementID,
            rootViewController: rootViewController,
            didFail: didFail,
            willPresent: willPresent,
            didEarnReward: didEarnReward,
            didHide: didHide)
  }
  
  public func requestConsentUpdate() {
    guard let topVC = UIApplication.topStackViewController() else {
      return
    }
    
    UMPConsentForm.presentPrivacyOptionsForm(from: topVC) { [weak self] formError in
      guard let self else {
        return
      }
      if let formError {
        print("[AdMobManager] [CMP] Form error - \(formError.localizedDescription)!")
        return
      }
      let canShowAds = canShowAds()
      if canShowAds {
        self.startGoogleMobileAdsSDK()
      }
      self.state = canShowAds == true ? .allow : .reject
    }
  }
  
  public func activeDebug(testDeviceIdentifiers: [String], reset: Bool) {
    self.isDebug = true
    self.testDeviceIdentifiers = testDeviceIdentifiers
    if reset {
      UMPConsentInformation.sharedInstance.reset()
    }
  }
}

extension AdMobManager {
  func getAd(type: AdType, placementID: String) -> Any? {
    guard let adMobConfig else {
      return nil
    }
    switch type {
    case .onceUsed(let type):
      switch type {
      case .banner:
        return adMobConfig.banners?.first(where: { $0.placementID == placementID })
      case .native:
        return adMobConfig.natives?.first(where: { $0.placementID == placementID })
      }
    case .reuse(let type):
      switch type {
      case .splash:
        return adMobConfig.splashs?.first(where: { $0.placementID == placementID })
      case .appOpen:
        return adMobConfig.appOpens?.first(where: { $0.placementID == placementID })
      case .interstitial:
        return adMobConfig.interstitials?.first(where: { $0.placementID == placementID })
      case .rewarded:
        return adMobConfig.rewardeds?.first(where: { $0.placementID == placementID })
      case .rewardedInterstitial:
        return adMobConfig.rewardedInterstitials?.first(where: { $0.placementID == placementID })
      }
    }
  }
  
  func getNativePreload(placementID: String) -> NativeAd? {
    return listNativeAd[placementID]
  }
}

extension AdMobManager {
  private func checkIsPresent() -> Bool {
    for ad in listReuseAd where ad.value.isPresent() {
      return true
    }
    return false
  }
  
  private func updateAdMobCache() {
    guard let remoteKey else {
      return
    }
    guard let adMobConfig else {
      return
    }
    guard let data = try? JSONEncoder().encode(adMobConfig) else {
      return
    }
    UserDefaults.standard.set(data, forKey: remoteKey)
  }
  
  private func updateConsentCache() {
    guard let consentConfig else {
      return
    }
    guard let data = try? JSONEncoder().encode(consentConfig) else {
      return
    }
    UserDefaults.standard.set(data, forKey: consentKey)
  }
  
  private func decoding(adMobData: Data) {
    guard let adMobConfig = try? JSONDecoder().decode(AdMobConfig.self, from: adMobData) else {
      print("[AdMobManager] Invalid (AdMobConfig) format!")
      return
    }
    self.adMobConfig = adMobConfig
    updateAdMobCache()
    
    if !didRequestConsent {
      self.didRequestConsent = true
      checkConsent()
    }
  }
  
  private func decoding(consentData: Data) {
    guard let consentConfig = try? JSONDecoder().decode(ConsentConfig.self, from: consentData) else {
      print("[AdMobManager] Invalid (ConsentConfig) format!")
      return
    }
    self.consentConfig = consentConfig
    updateConsentCache()
  }
  
  private func fetchAdMobCache() {
    guard let remoteKey else {
      return
    }
    guard let cacheData = UserDefaults.standard.data(forKey: remoteKey) else {
      return
    }
    decoding(adMobData: cacheData)
  }
  
  private func fetchConsentCache() {
    guard let cacheData = UserDefaults.standard.data(forKey: consentKey) else {
      return
    }
    decoding(consentData: cacheData)
  }
  
  private func fetchDefault() {
    guard let defaultData else {
      return
    }
    decoding(adMobData: defaultData)
  }
  
  private func fetchRemote() {
    guard let remoteKey else {
      return
    }
    print("[AdMobManager] [Remote config] Start load!")
    LogEventManager.shared.log(event: .remoteConfigStartLoad)
    DispatchQueue.main.asyncAfter(deadline: .now() + remoteTimeout, execute: timeoutRemote)
    remoteConfig.fetch(withExpirationDuration: 0) { [weak self] _, error in
      guard let self = self else {
        return
      }
      guard error == nil else {
        errorRemote()
        return
      }
      self.remoteConfig.activate()
      self.configValue?(self.remoteConfig)
      let adMobData = remoteConfig.configValue(forKey: remoteKey).dataValue
      let consentData = remoteConfig.configValue(forKey: consentKey).dataValue
      guard !adMobData.isEmpty else {
        errorRemote()
        return
      }
      print("[AdMobManager] [Remote config] Success!")
      LogEventManager.shared.log(event: .remoteConfigSuccess)
      self.decoding(consentData: consentData)
      self.decoding(adMobData: adMobData)
    }
  }
  
  private func errorRemote() {
    guard adMobConfig == nil else {
      if didRemoteTimeout {
        print("[AdMobManager] [Remote config] First load error with timeout!")
        LogEventManager.shared.log(event: .remoteConfigErrorWithTimeout)
      }
      return
    }
    print("[AdMobManager] [Remote config] First load error!")
    LogEventManager.shared.log(event: .remoteConfigLoadFail)
    fetchDefault()
  }
  
  private func timeoutRemote() {
    guard adMobConfig == nil else {
      return
    }
    self.didRemoteTimeout = true
    print("[AdMobManager] [Remote config] First load timeout!")
    LogEventManager.shared.log(event: .remoteConfigTimeout)
    fetchDefault()
  }
  
  private func checkFrequency(adConfig: AdConfigProtocol, ad: AdProtocol) -> Bool {
    guard
      let interstitial = adConfig as? Interstitial,
      let start = interstitial.start,
      let frequency = interstitial.frequency
    else {
      return true
    }
    let countClick = FrequencyManager.shared.getCount(placementID: adConfig.placementID) + 1
    guard countClick >= start else {
      FrequencyManager.shared.increaseCount(placementID: adConfig.placementID)
      return false
    }
    let isShow = (countClick - start) % frequency == 0
    if !isShow || ad.isExist() {
      FrequencyManager.shared.increaseCount(placementID: adConfig.placementID)
    }
    return isShow
  }
  
  private func checkConsent() {
    print("[AdMobManager] [CMP] Check consent!")
    LogEventManager.shared.log(event: .cmpCheckConsent)
    guard !isPremium else {
      print("[AdMobManager] [CMP] Not request consent!")
      LogEventManager.shared.log(event: .cmpNotRequestConsent)
      return
    }
    guard let adMobConfig else {
      return
    }
    guard adMobConfig.status else {
      print("[AdMobManager] [CMP] Not request consent!")
      LogEventManager.shared.log(event: .cmpNotRequestConsent)
      allow()
      return
    }
    
    let parameters = UMPRequestParameters()
    parameters.tagForUnderAgeOfConsent = false
    
    if isDebug {
      let debugSettings = UMPDebugSettings()
      debugSettings.testDeviceIdentifiers = testDeviceIdentifiers
      debugSettings.geography = .EEA
      parameters.debugSettings = debugSettings
    } else {
      guard let consentConfig, consentConfig.status else {
        print("[AdMobManager] [CMP] Not request consent!")
        LogEventManager.shared.log(event: .cmpNotRequestConsent)
        allow()
        return
      }
    }
    
    print("[AdMobManager] [CMP] Request consent!")
    LogEventManager.shared.log(event: .cmpRequestConsent)
    UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] requestConsentError in
      guard let self else {
        return
      }
      if let requestConsentError {
        print("[AdMobManager] [CMP] Request consent error - \(requestConsentError.localizedDescription)!")
        LogEventManager.shared.log(event: .cmpConsentInformationError)
        allow()
        return
      }
      
      guard let topVC = UIApplication.topStackViewController() else {
        return
      }
      
      UMPConsentForm.loadAndPresentIfRequired(from: topVC) { [weak self] loadAndPresentError in
        guard let self else {
          return
        }
        if let loadAndPresentError {
          print("[AdMobManager] [CMP] Load and present error - \(loadAndPresentError.localizedDescription)!")
          LogEventManager.shared.log(event: .cmpConsentFormError)
          allow()
          return
        }
        
        guard isGDPR() else {
          print("[AdMobManager] [CMP] Auto agree consent GDPR!")
          LogEventManager.shared.log(event: .cmpAutoAgreeConsentGDPR)
          allow()
          return
        }
        
        let canShowAds = canShowAds()
        if canShowAds {
          print("[AdMobManager] [CMP] Agree consent!")
          LogEventManager.shared.log(event: .cmpAgreeConsent)
          self.startGoogleMobileAdsSDK()
        } else {
          print("[AdMobManager] [CMP] Reject consent!")
          LogEventManager.shared.log(event: .cmpRejectConsent)
        }
        self.state = canShowAds == true ? .allow : .reject
      }
    }
    
    if canShowAds() {
      print("[AdMobManager] [CMP] Auto agree consent!")
      LogEventManager.shared.log(event: .cmpAutoAgreeConsent)
      allow()
    }
  }
  
  private func allow() {
    self.startGoogleMobileAdsSDK()
    self.state = .allow
  }
  
  private func startGoogleMobileAdsSDK() {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      guard !didSetup else {
        return
      }
      self.didSetup = true
      
      GADMobileAds.sharedInstance().start()
    }
  }
  
  private func isGDPR() -> Bool {
    let settings = UserDefaults.standard
    let gdpr = settings.integer(forKey: "IABTCF_gdprApplies")
    return gdpr == 1
  }
  
  private func canShowAds() -> Bool {
    let userDefaults = UserDefaults.standard
    
    let purposeConsent = userDefaults.string(forKey: "IABTCF_PurposeConsents") ?? ""
    let vendorConsent = userDefaults.string(forKey: "IABTCF_VendorConsents") ?? ""
    let vendorLI = userDefaults.string(forKey: "IABTCF_VendorLegitimateInterests") ?? ""
    let purposeLI = userDefaults.string(forKey: "IABTCF_PurposeLegitimateInterests") ?? ""
    
    let googleId = 755
    let hasGoogleVendorConsent = hasAttribute(input: vendorConsent, index: googleId)
    let hasGoogleVendorLI = hasAttribute(input: vendorLI, index: googleId)
    
    return hasConsentFor([1], purposeConsent, hasGoogleVendorConsent)
    && hasConsentOrLegitimateInterestFor([2,7,9,10],
                                         purposeConsent,
                                         purposeLI,
                                         hasGoogleVendorConsent,
                                         hasGoogleVendorLI)
  }
  
  private func hasAttribute(input: String, index: Int) -> Bool {
    return input.count >= index && String(Array(input)[index - 1]) == "1"
  }
  
  private func hasConsentFor(_ purposes: [Int], _ purposeConsent: String, _ hasVendorConsent: Bool) -> Bool {
    return purposes.allSatisfy { i in hasAttribute(input: purposeConsent, index: i) } && hasVendorConsent
  }
  
  private func hasConsentOrLegitimateInterestFor(_ purposes: [Int],
                                                 _ purposeConsent: String,
                                                 _ purposeLI: String,
                                                 _ hasVendorConsent: Bool,
                                                 _ hasVendorLI: Bool
  ) -> Bool {
    return purposes.allSatisfy { i in
      (hasAttribute(input: purposeLI, index: i) && hasVendorLI) ||
      (hasAttribute(input: purposeConsent, index: i) && hasVendorConsent)
    }
  }
}
