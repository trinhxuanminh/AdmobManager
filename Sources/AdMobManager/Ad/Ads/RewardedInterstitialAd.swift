//
//  RewardedInterstitialAd.swift
//  
//
//  Created by Trịnh Xuân Minh on 05/12/2022.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue

class RewardedInterstitialAd: NSObject, AdProtocol {
  private var rewardedInterstitialAd: GADRewardedInterstitialAd?
  private var adUnitID: String?
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
  
  func config(id: String) {
    self.adUnitID = id
    load()
  }
  
  func isPresent() -> Bool {
    return presentState
  }
  
  func isExist() -> Bool {
    return rewardedInterstitialAd != nil
  }
  
  func show(rootViewController: UIViewController,
            didFail: Handler?,
            willPresent: Handler?,
            didEarnReward: Handler?,
            didHide: Handler?
  ) {
    guard isReady() else {
      print("[AdMobManager] [RewardedInterstitialAd] Display failure - not ready to show! (\(String(describing: adUnitID)))")
      didFail?()
      return
    }
    guard !presentState else {
      print("[AdMobManager] [RewardedInterstitialAd] Display failure - ads are being displayed! (\(String(describing: adUnitID)))")
      didFail?()
      return
    }
    print("[AdMobManager] [RewardedInterstitialAd] Requested to show! (\(String(describing: adUnitID)))")
    self.didShowFail = didFail
    self.willPresent = willPresent
    self.didHide = didHide
    self.didEarnReward = didEarnReward
    rewardedInterstitialAd?.present(fromRootViewController: rootViewController, userDidEarnRewardHandler: { [weak self] in
      guard let self else {
        return
      }
      self.didEarnReward?()
    })
  }
}

extension RewardedInterstitialAd: GADFullScreenContentDelegate {
  func ad(_ ad: GADFullScreenPresentingAd,
          didFailToPresentFullScreenContentWithError error: Error
  ) {
    print("[AdMobManager] [RewardedInterstitialAd] Did fail to show content! (\(String(describing: adUnitID)))")
    didShowFail?()
    self.rewardedInterstitialAd = nil
    load()
  }
  
  func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [RewardedInterstitialAd] Will display! (\(String(describing: adUnitID)))")
    willPresent?()
    self.presentState = true
  }
  
  func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
    print("[AdMobManager] [RewardedInterstitialAd] Did hide! (\(String(describing: adUnitID)))")
    didHide?()
    self.rewardedInterstitialAd = nil
    self.presentState = false
    load()
  }
}

extension RewardedInterstitialAd {
  private func isReady() -> Bool {
    if !isExist(), retryAttempt >= 2 {
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
      print("[AdMobManager] [RewardedInterstitialAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      self.isLoading = true
      print("[AdMobManager] [RewardedInterstitialAd] Start load! (\(String(describing: adUnitID)))")
      
      let request = GADRequest()
      GADRewardedInterstitialAd.load(
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
            self.didLoadFail?()
            return
          }
          let delaySec = 5.0
          print("[AdMobManager] [RewardedInterstitialAd] Did fail to load. Reload after \(delaySec)s! (\(String(describing: adUnitID))) - (\(String(describing: error)))")
          DispatchQueue.global().asyncAfter(deadline: .now() + delaySec, execute: self.load)
          return
        }
        print("[AdMobManager] [RewardedInterstitialAd] Did load! (\(String(describing: adUnitID)))")
        self.retryAttempt = 0
        self.rewardedInterstitialAd = ad
        self.rewardedInterstitialAd?.fullScreenContentDelegate = self
        self.didLoadSuccess?()
        
        ad.paidEventHandler = { adValue in
          let adRevenueParams: [AnyHashable: Any] = [
            kAppsFlyerAdRevenueCountry: "US",
            kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
            kAppsFlyerAdRevenueAdType: "RewardedInterstitial"
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
