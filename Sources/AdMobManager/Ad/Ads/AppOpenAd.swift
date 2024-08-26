//
//  AppOpenAd.swift
//  AdMobManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue

class AppOpenAd: NSObject, AdProtocol {
  private var appOpenAd: GADAppOpenAd?
  private var adUnitID: String?
  private var placement: String?
  private var name: String?
  private var presentState = false
  private var isLoading = false
  private var retryAttempt = 0
  private var didLoadFail: Handler?
  private var didLoadSuccess: Handler?
  private var didShowFail: Handler?
  private var willPresent: Handler?
  private var didEarnReward: Handler?
  private var didHide: Handler?
  
  func config(didFail: Handler?, didSuccess: Handler?) {
    self.didLoadFail = didFail
    self.didLoadSuccess = didSuccess
  }
  
  func config(id: String, name: String) {
    self.adUnitID = id
    self.name = name
    load()
  }
  
  func isPresent() -> Bool {
    return presentState
  }
  
  func isExist() -> Bool {
    return appOpenAd != nil
  }
  
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?
  ) {
    guard !presentState else {
      print("[AdMobManager] [AppOpenAd] Display failure - ads are being displayed! (\(String(describing: adUnitID)))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(placement))
    guard isReady() else {
      print("[AdMobManager] [AppOpenAd] Display failure - not ready to show! (\(String(describing: adUnitID)))")
      LogEventManager.shared.log(event: .adShowNoReady(placement))
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowReady(placement))
    print("[AdMobManager] [AppOpenAd] Requested to show! (\(String(describing: adUnitID)))")
    self.placement = placement
    self.didShowFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    appOpenAd?.present(fromRootViewController: rootViewController)
  }
}

extension AppOpenAd: GADFullScreenContentDelegate {
  func ad(_ ad: GADFullScreenPresentingAd,
          didFailToPresentFullScreenContentWithError error: Error
  ) {
    print("[AdMobManager] [AppOpenAd] Did fail to show content! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowFail(placement, error))
    }
    didShowFail?()
    self.appOpenAd = nil
    load()
  }
  
  func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [AppOpenAd] Will display! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(placement))
    }
    willPresent?()
    self.presentState = true
  }
  
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [AppOpenAd] Did hide! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowHide(placement))
    }
    didHide?()
    self.appOpenAd = nil
    self.presentState = false
    load()
  }
}

extension AppOpenAd {
  private func isReady() -> Bool {
    if !isExist(), retryAttempt >= 1 {
      load()
    }
    return isExist()
  }
  
  private func load() {
    guard !isLoading else {
      return
    }
    
    guard !isExist() else {
      return
    }
    
    guard let adUnitID = adUnitID else {
      print("[AdMobManager] [AppOpenAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      self.isLoading = true
      print("[AdMobManager] [AppOpenAd] Start load! (\(String(describing: adUnitID)))")
      
      if let name {
        LogEventManager.shared.log(event: .adLoadRequest(name))
        TimeManager.shared.start(event: .adLoad(.reuse(.appOpen), name))
      }
      let request = GADRequest()
      GADAppOpenAd.load(
        withAdUnitID: adUnitID,
        request: request
      ) { [weak self] (ad, error) in
        guard let self = self else {
          return
        }
        self.isLoading = false
        guard error == nil, let ad = ad else {
          self.retryAttempt += 1
          self.didLoadFail?()
          print("[AdMobManager] [AppOpenAd] Load fail (\(String(describing: adUnitID))) - \(String(describing: error))!")
          if let name {
            LogEventManager.shared.log(event: .adLoadFail(name, error))
          }
          return
        }
        print("[AdMobManager] [AppOpenAd] Did load! (\(String(describing: adUnitID)))")
        if let name {
          let time = TimeManager.shared.end(event: .adLoad(.reuse(.appOpen), name))
          LogEventManager.shared.log(event: .adLoadSuccess(name, time))
        }
        self.retryAttempt = 0
        self.appOpenAd = ad
        self.appOpenAd?.fullScreenContentDelegate = self
        self.didLoadSuccess?()
        
        ad.paidEventHandler = { adValue in
          if let name = self.name {
            LogEventManager.shared.log(event: .adPayRevenue(name))
            if adValue.value == 0 {
              LogEventManager.shared.log(event: .adNoRevenue(name))
            }
          }
          let adRevenueParams: [AnyHashable: Any] = [
            kAppsFlyerAdRevenueCountry: "US",
            kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
            kAppsFlyerAdRevenueAdType: "AppOpen"
          ]
  
          AppsFlyerAdRevenue.shared().logAdRevenue(
            monetizationNetwork: "admob",
            mediationNetwork: MediationNetworkType.googleAdMob,
            eventRevenue: adValue.value,
            revenueCurrency: adValue.currencyCode,
            additionalParameters: adRevenueParams)
        }
      }
    }
  }
}
