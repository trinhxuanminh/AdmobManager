//
//  NativeAd.swift
//  AdMobManager
//
//  Created by Trịnh Xuân Minh on 25/03/2022.
//

import UIKit
import GoogleMobileAds
import AppsFlyerAdRevenue
import AppsFlyerLib

class NativeAd: NSObject {
  private var nativeAd: GADNativeAd?
  private var adLoader: GADAdLoader?
  private weak var rootViewController: UIViewController?
  private var adUnitID: String?
  private var ad: Native?
  private var isFullScreen = false
  private var timeout: Double?
  private var state: State = .wait
  private var didReceive: Handler?
  private var didError: Handler?
  
  func config(ad: Native, rootViewController: UIViewController?) {
    self.rootViewController = rootViewController
    guard ad.status else {
      return
    }
    guard adUnitID == nil else {
      return
    }
    self.adUnitID = ad.id
    self.ad = ad
    self.timeout = ad.timeout
    if let isFullScreen = ad.isFullScreen {
      self.isFullScreen = isFullScreen
    }
    self.load()
  }
  
  func getState() -> State {
    return state
  }
  
  func getAd() -> GADNativeAd? {
    return nativeAd
  }
  
  func bind(didReceive: Handler?, didError: Handler?) {
    self.didReceive = didReceive
    self.didError = didError
  }
  
  func isTestMode() -> Bool? {
    print(nativeAd?.responseInfo)
    print(nativeAd?.responseInfo.dictionaryRepresentation)
    guard
      let nativeAd,
      let lineItems = nativeAd.responseInfo.dictionaryRepresentation["Mediation line items"] as? [Any],
      let dictionary = lineItems.first as? [String: Any],
      let adSourceInstanceName = dictionary["Ad Source Instance Name"] as? String
    else {
      return nil
    }
    return adSourceInstanceName.lowercased().contains("test")
  }
}

extension NativeAd: GADNativeAdLoaderDelegate {
  func adLoader(_ adLoader: GADAdLoader,
                didFailToReceiveAdWithError error: Error) {
    guard state == .loading else {
      return
    }
    print("[AdMobManager] [NativeAd] Load fail (\(String(describing: adUnitID))) - \(String(describing: error))!")
    if let placement = ad?.placement {
      LogEventManager.shared.log(event: .adLoadFail(placement, error))
    }
    self.state = .error
    didError?()
  }
  
  func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
    guard state == .loading else {
      return
    }
    print("[AdMobManager] [NativeAd] Did load! (\(String(describing: adUnitID)))")
    if let placement = ad?.placement {
      let time = TimeManager.shared.end(event: .adLoad(.onceUsed(.native), placement))
      LogEventManager.shared.log(event: .adLoadSuccess(placement, time))
    }
    self.state = .receive
    self.nativeAd = nativeAd
    didReceive?()
    
    nativeAd.paidEventHandler = { [weak self] adValue in
      guard let self else {
        return
      }
      if let placement = ad?.placement {
        LogEventManager.shared.log(event: .adPayRevenue(placement, rootViewController))
        if adValue.value == 0 {
          LogEventManager.shared.log(event: .adNoRevenue(placement, rootViewController))
        }
      }
      let adRevenueParams: [AnyHashable: Any] = [
        kAppsFlyerAdRevenueCountry: "US",
        kAppsFlyerAdRevenueAdUnit: adUnitID as Any,
        kAppsFlyerAdRevenueAdType: "Native"
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

extension NativeAd {
  private func load() {
    guard state == .wait else {
      return
    }
    
    guard let adUnitID = adUnitID else {
      print("[AdMobManager] [NativeAd] Failed to load - not initialized yet! Please install ID.")
      return
    }
    
    print("[AdMobManager] [NativeAd] Start load! (\(String(describing: adUnitID)))")
    self.state = .loading
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      var options: [GADAdLoaderOptions]? = nil
      if self.isFullScreen {
        let aspectRatioOption = GADNativeAdMediaAdLoaderOptions()
        aspectRatioOption.mediaAspectRatio = .portrait
        options = [aspectRatioOption]
      }
      if let placement = ad?.placement {
        LogEventManager.shared.log(event: .adLoadRequest(placement))
        TimeManager.shared.start(event: .adLoad(.onceUsed(.native), placement))
      }
      self.adLoader = GADAdLoader(
        adUnitID: adUnitID,
        rootViewController: rootViewController,
        adTypes: [.native],
        options: options)
      self.adLoader?.delegate = self
      self.adLoader?.load(GADRequest())
    }
    
    if let timeout {
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
        guard let self = self else {
          return
        }
        guard state == .loading else {
          return
        }
        print("[AdMobManager] [NativeAd] Load fail (\(String(describing: adUnitID))) - time out!")
        if let placement = ad?.placement {
          LogEventManager.shared.log(event: .adLoadTimeout(placement))
        }
        self.state = .error
        didError?()
      }
    }
  }
}
