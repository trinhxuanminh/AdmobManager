//
//  InterstitialAd.swift
//  AdMobManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue
import AppsFlyerLib

class InterstitialAd: NSObject, AdProtocol {
  private var interstitialAd: GADInterstitialAd?
  private var adUnitID: String?
  private var placement: String?
  private var name: String?
  private var isShowing = false
  private var isLoading = false
  private var retryAttempt = 0
  private var didLoadFail: Handler?
  private var didLoadSuccess: Handler?
  private var didShowFail: Handler?
  private var willPresent: Handler?
  private var didEarnReward: Handler?
  private var didHide: Handler?
  private var loadTime: Date?
  private var timeInterval: TimeInterval?
  
  func config(didFail: Handler?, didSuccess: Handler?) {
    self.didLoadFail = didFail
    self.didLoadSuccess = didSuccess
  }
  
  func config(id: String, name: String) {
    self.adUnitID = id
    self.name = name
    load()
  }
  
  func config(timeInterval: Double) {
    self.timeInterval = timeInterval
  }
  
  func isPresent() -> Bool {
    return isShowing
  }
  
  func isExist() -> Bool {
    return interstitialAd != nil
  }
  
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?
  ) {
    guard !isShowing else {
      print("[AdMobManager] [InterstitialAd] Display failure - ads are being displayed! (\(placement))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(placement))
    guard isReady() else {
      print("[AdMobManager] [InterstitialAd] Display failure - not ready to show! (\(placement))")
      didFail?()
      return
    }
    guard wasLoadTimeGreaterThanInterval() else {
      print("[AdMobManager] [AppOpenAd] Display failure - Load time is less than interval! (\(placement))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowReady(placement))
    print("[AdMobManager] [AppOpenAd] Requested to show! (\(placement))")
    self.placement = placement
    self.didShowFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    interstitialAd?.present(fromRootViewController: rootViewController)
  }
  
  func isTestMode() -> Bool? {
    guard
      let interstitialAd,
      let lineItems = interstitialAd.responseInfo.dictionaryRepresentation["Mediation line items"] as? [Any],
      let dictionary = lineItems.first as? [String: Any],
      let adSourceInstanceName = dictionary["Ad Source Instance Name"] as? String
    else {
      return nil
    }
    return adSourceInstanceName.lowercased().contains("test")
  }
}

extension InterstitialAd: GADFullScreenContentDelegate {
  func ad(_ ad: GADFullScreenPresentingAd,
          didFailToPresentFullScreenContentWithError error: Error
  ) {
    if let placement {
      print("[AdMobManager] [InterstitialAd] Did fail to show content! (\(placement))")
      LogEventManager.shared.log(event: .adShowFail(placement, error))
    }
    didShowFail?()
    self.interstitialAd = nil
    load()
  }
  
  func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    if let placement {
      print("[AdMobManager] [InterstitialAd] Will display! (\(placement))")
      LogEventManager.shared.log(event: .adShowSuccess(placement))
    }
    willPresent?()
    self.isShowing = true
  }
  
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    if let placement {
      print("[AdMobManager] [InterstitialAd] Did hide! (\(placement))")
      LogEventManager.shared.log(event: .adShowHide(placement))
    }
    didHide?()
    self.interstitialAd = nil
    self.isShowing = false
    self.loadTime = Date()
    load()
  }
}

extension InterstitialAd {
  private func isReady() -> Bool {
    if !isExist(), retryAttempt >= 2 {
      load()
    }
    return isExist()
  }
  
  private func wasLoadTimeGreaterThanInterval() -> Bool {
    guard
      let loadTime = loadTime,
      let timeInterval = timeInterval
    else {
      return true
    }
    return Date().timeIntervalSince(loadTime) >= timeInterval
  }
  
  private func load() {
    guard !isLoading else {
      return
    }
    
    guard !isExist() else {
      return
    }
    
    guard let adUnitID = adUnitID else {
      print("[AdMobManager] [InterstitialAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      self.isLoading = true
      
      if let name {
        print("[AdMobManager] [InterstitialAd] Start load! (\(name))")
        LogEventManager.shared.log(event: .adLoadRequest(name))
        TimeManager.shared.start(event: .adLoad(.reuse(.interstitial), name))
      }
      
      let request = GADRequest()
      GADInterstitialAd.load(
        withAdUnitID: adUnitID,
        request: request
      ) { [weak self] (ad, error) in
        guard let self = self else {
          return
        }
        self.isLoading = false
        guard error == nil, let ad = ad else {
          self.retryAttempt += 1
          guard self.retryAttempt == 1 else {
            if let name {
              LogEventManager.shared.log(event: .adLoadTryFail(name, error))
            }
            self.didLoadFail?()
            return
          }
          let delaySec = 5.0
          if let name {
            print("[AdMobManager] [InterstitialAd] Did fail to load. Reload after \(delaySec)s! (\(name)) - (\(String(describing: error)))")
            LogEventManager.shared.log(event: .adLoadFail(name, error))
          }
          DispatchQueue.global().asyncAfter(deadline: .now() + delaySec, execute: self.load)
          return
        }
        if let name {
          print("[AdMobManager] [InterstitialAd] Did load! (\(name))")
          let time = TimeManager.shared.end(event: .adLoad(.reuse(.interstitial), name))
          LogEventManager.shared.log(event: .adLoadSuccess(name, time))
        }
        self.retryAttempt = 0
        self.interstitialAd = ad
        self.interstitialAd?.fullScreenContentDelegate = self
        self.didLoadSuccess?()
        
        ad.paidEventHandler = { adValue in
          if let placement = self.placement {
            LogEventManager.shared.log(event: .adPayRevenue(placement))
            if adValue.value == 0 {
              LogEventManager.shared.log(event: .adNoRevenue(placement))
            }
          }
          let adRevenueParams: [AnyHashable: Any] = [
            kAppsFlyerAdRevenueCountry: "US",
            kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
            kAppsFlyerAdRevenueAdType: "Interstitial"
          ]
          
          AppsFlyerAdRevenue.shared().logAdRevenue(
            monetizationNetwork: "admob",
            mediationNetwork: MediationNetworkType.googleAdMob,
            eventRevenue: adValue.value,
            revenueCurrency: adValue.currencyCode,
            additionalParameters: adRevenueParams)
          
          AppsFlyerLib.shared().logEvent("ad_impression",
                                         withValues: [
                                          AFEventParamRevenue: adValue.value,
                                          AFEventParamCurrency: adValue.currencyCode
                                         ])
        }
      }
    }
  }
}
