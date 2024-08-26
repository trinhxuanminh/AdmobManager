//
//  SplashAd.swift
//  
//
//  Created by Trịnh Xuân Minh on 06/09/2023.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue

class SplashAd: NSObject, AdProtocol {
  private var splashAd: GADInterstitialAd?
  private var adUnitID: String?
  private var placement: String?
  private var name: String?
  private var presentState = false
  private var isLoading = false
  private var timeout: Double?
  private var time = 0.0
  private var timer: Timer?
  private var timeInterval = 0.1
  private var didLoadFail: Handler?
  private var didLoadSuccess: Handler?
  private var didFail: Handler?
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
  
  func config(timeout: Double) {
    self.timeout = timeout
  }
  
  func isPresent() -> Bool {
    return presentState
  }
  
  func isExist() -> Bool {
    return splashAd != nil
  }
  
  func show(placement: String,
            rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?
  ) {
    guard !presentState else {
      print("[AdMobManager] [SplashAd] Display failure - ads are being displayed! (\(String(describing: adUnitID)))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowRequest(placement))
    guard isExist() else {
      print("[AdMobManager] [SplashAd] Display failure - not ready to show! (\(String(describing: adUnitID)))")
      didFail?()
      return
    }
    LogEventManager.shared.log(event: .adShowReady(placement))
    print("[AdMobManager] [SplashAd] Requested to show! (\(String(describing: adUnitID)))")
    self.placement = placement
    self.didFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    splashAd?.present(fromRootViewController: rootViewController)
  }
}

extension SplashAd: GADFullScreenContentDelegate {
  func ad(_ ad: GADFullScreenPresentingAd,
          didFailToPresentFullScreenContentWithError error: Error
  ) {
    print("[AdMobManager] [SplashAd] Did fail to show content! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowFail(placement, error))
    }
    didFail?()
    self.splashAd = nil
  }
  
  func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [SplashAd] Will display! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowSuccess(placement))
    }
    willPresent?()
    self.presentState = true
  }
  
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [SplashAd] Did hide! (\(String(describing: adUnitID)))")
    if let placement {
      LogEventManager.shared.log(event: .adShowHide(placement))
    }
    didHide?()
    self.presentState = false
    self.splashAd = nil
  }
}

extension SplashAd {
  private func load() {
    guard !isLoading else {
      return
    }
    
    guard let adUnitID = adUnitID else {
      print("[AdMobManager] [SplashAd] Failed to load - not initialized yet! Please install ID.")
      didLoadFail?()
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      self.isLoading = true
      self.fire()
      print("[AdMobManager] [SplashAd] Start load! (\(String(describing: adUnitID)))")
      if let name {
        LogEventManager.shared.log(event: .adLoadRequest(name))
        TimeManager.shared.start(event: .adLoad(.reuse(.splash), name))
      }
      
      let request = GADRequest()
      GADInterstitialAd.load(
        withAdUnitID: adUnitID,
        request: request
      ) { [weak self] (ad, error) in
        guard let self = self else {
          return
        }
        guard let timeout = self.timeout, self.time < timeout else {
          return
        }
        self.invalidate()
        guard error == nil, let ad = ad else {
          print("[AdMobManager] [SplashAd] Load fail (\(String(describing: adUnitID))) - \(String(describing: error))!")
          if let name {
            LogEventManager.shared.log(event: .adLoadFail(name, error))
          }
          self.didLoadFail?()
          return
        }
        print("[AdMobManager] [SplashAd] Did load! (\(String(describing: adUnitID)))")
        if let name {
          let time = TimeManager.shared.end(event: .adLoad(.reuse(.splash), name))
          LogEventManager.shared.log(event: .adLoadSuccess(name, time))
        }
        self.splashAd = ad
        self.splashAd?.fullScreenContentDelegate = self
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
            kAppsFlyerAdRevenueAdType: "Interstitial_Splash"
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
  
  private func fire() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      self.timer = Timer.scheduledTimer(timeInterval: self.timeInterval,
                                        target: self,
                                        selector: #selector(self.isReady),
                                        userInfo: nil,
                                        repeats: true)
    }
  }
  
  private func invalidate() {
    self.timer?.invalidate()
    self.timer = nil
  }
  
  @objc private func isReady() {
    self.time += timeInterval
    
    if let timeout = timeout, time < timeout {
      return
    }
    invalidate()
    if let name {
      LogEventManager.shared.log(event: .adLoadTimeout(name))
    }
    didLoadFail?()
  }
}
