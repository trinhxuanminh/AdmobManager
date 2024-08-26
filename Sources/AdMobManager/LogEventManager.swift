//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 31/08/2023.
//

import UIKit
import FirebaseAnalytics

class LogEventManager {
  static let shared = LogEventManager()
  
  private var isWarning = false
  
  func log(event: Event) {
#if DEBUG
    print("[AdMobManager] [LogEventManager]", "[\(isValid(event.name, limit: 40))]", event.name, event.parameters ?? String())
    if !isValid(event.name, limit: 40) {
      showWarning()
    }
#endif
    
#if !DEBUG
    Analytics.logEvent(event.name, parameters: event.parameters)
#endif
  }
  
  func checkFormat(adConfig: AdMobConfig) {
    let maxCharacter = 23
    
    let body: ((AdConfigProtocol) -> Void) = { [weak self] ad in
      guard let self else {
        return
      }
      if !isValid(ad.placement, limit: maxCharacter) || !isValid(ad.name, limit: maxCharacter) {
        showWarning()
        return
      }
    }
    
    adConfig.splashs?.forEach(body)
    adConfig.appOpens?.forEach(body)
    adConfig.interstitials?.forEach(body)
    adConfig.rewardeds?.forEach(body)
    adConfig.rewardedInterstitials?.forEach(body)
    adConfig.banners?.forEach(body)
    adConfig.natives?.forEach(body)
  }
}

extension LogEventManager {
  private func isValid(_ input: String, limit: Int) -> Bool {
    guard input.count <= limit else {
      return false
    }
    let pattern = "^[a-zA-Z0-9_]*$"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: input.utf16.count)
    return regex.firstMatch(in: input, options: [], range: range) != nil
  }
  
  private func showWarning() {
    guard !isWarning else {
      return
    }
    self.isWarning = true
    
    guard let topVC = UIApplication.topStackViewController() else {
      return
    }
    let alert = UIAlertController(title: "Error", message: "Missing event", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
      guard let self else {
        return
      }
      self.isWarning = false
    }))
    topVC.present(alert, animated: true)
  }
}

enum Event {
  case register
  
  case remoteConfigLoadFail
  case remoteConfigTimeout
  case remoteConfigStartLoad
  case remoteConfigSuccess
  case remoteConfigErrorWithTimeout
  
  case cmpCheckConsent
  case cmpNotRequestConsent
  case cmpRequestConsent
  case cmpConsentInformationError
  case cmpConsentFormError
  case cmpAgreeConsent
  case cmpRejectConsent
  case cmpAutoAgreeConsent
  case cmpAutoAgreeConsentGDPR
  
  case connectedAppsFlyer
  case noConnectAppsFlyer
  case agreeTracking
  case noTracking
  
  case adLoadRequest(String)
  case adLoadSuccess(String, Double)
  case adLoadFail(String, Error?)
  case adLoadTryFail(String, Error?)
  case adLoadTimeout(String)
  case adPayRevenue(String)
  case adNoRevenue(String)
  case adShowCheck(String, UIViewController? = nil)
  case adShowRequest(String, UIViewController? = nil)
  case adShowReady(String, UIViewController? = nil)
  case adShowNoReady(String, UIViewController? = nil)
  case adShowSuccess(String, UIViewController? = nil)
  case adShowFail(String, Error?, UIViewController? = nil)
  case adShowHide(String, UIViewController? = nil)
  case adShowClick(String, UIViewController? = nil)
  case adEarnReward(String, UIViewController? = nil)
  
  var name: String {
    switch self {
    case .remoteConfigLoadFail:
      return "RemoteConfig_First_Load_Fail"
    case .remoteConfigTimeout:
      return "RemoteConfig_First_Load_Timeout"
    case .remoteConfigErrorWithTimeout:
      return "RemoteConfig_First_Load_Error_With_Timeout"
    case .register:
      return "Register"
    case .remoteConfigStartLoad:
      return "RemoteConfig_Start_Load"
    case .remoteConfigSuccess:
      return "remoteConfig_Success"
      
    case .cmpCheckConsent:
      return "CMP_Check_Consent"
    case .cmpNotRequestConsent:
      return "CMP_Not_Request_Consent"
    case .cmpRequestConsent:
      return "CMP_Request_Consent"
    case .cmpConsentInformationError:
      return "CMP_Consent_Information_Error"
    case .cmpConsentFormError:
      return "CMP_Consent_Form_Error"
    case .cmpAgreeConsent:
      return "CMP_Agree_Consent"
    case .cmpRejectConsent:
      return "CMP_Reject_Consent"
    case .cmpAutoAgreeConsent:
      return "CMP_Auto_Agree_Consent"
    case .cmpAutoAgreeConsentGDPR:
      return "CMP_Auto_Agree_Consent_GDPR"
      
    case .connectedAppsFlyer:
      return "Connected_AppsFlyer"
    case .noConnectAppsFlyer:
      return "NoConnect_AppsFlyer"
    case .agreeTracking:
      return "Agree_Tracking"
    case .noTracking:
      return "No_Tracking"
      
    case .adLoadRequest(let id):
      return "AM_\(id)_Load_Request"
    case .adLoadSuccess(let id, _):
      return "AM_\(id)_Load_Success"
    case .adLoadFail(let id, _):
      return "AM_\(id)_Load_Fail"
    case .adLoadTryFail(let id, _):
      return "AM_\(id)_Load_TryFail"
    case .adLoadTimeout(let id):
      return "AM_\(id)_Load_Timeout"
    case .adPayRevenue(let id):
      return "AM_\(id)_Pay_Revenue"
    case .adNoRevenue(let id):
      return "AM_\(id)_No_Revenue"
    case .adShowCheck(let id, _):
      return "AM_\(id)_Show_Check"
    case .adShowRequest(let id, _):
      return "AM_\(id)_Show_Request"
    case .adShowReady(let id, _):
      return "AM_\(id)_Show_Ready"
    case .adShowNoReady(let id, _):
      return "AM_\(id)_Show_NoReady"
    case .adShowSuccess(let id, _):
      return "AM_\(id)_Show_Success"
    case .adShowFail(let id, _, _):
      return "AM_\(id)_Show_Fail"
    case .adShowHide(let id, _):
      return "AM_\(id)_Show_Hide"
    case .adShowClick(let id, _):
      return "AM_\(id)_Show_Click"
    case .adEarnReward(let id, _):
      return "AM_\(id)_Earn_Reward"
    }
  }
  
  var parameters: [String: Any]? {
    switch self {
    case .adLoadSuccess(_, let time):
      return ["time": time]
    case .adLoadFail(_, let error), .adLoadTryFail(_, let error):
      return ["error_code": (error as? NSError)?.code ?? "-1"]
    case .adShowCheck(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowRequest(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowReady(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowNoReady(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowSuccess(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowHide(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowClick(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adEarnReward(_, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return ["screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen()]
    case .adShowFail(_, let error, let viewController):
      guard let topVC = UIApplication.topStackViewController() else {
        return nil
      }
      return [
        "screen": (viewController ?? AdMobManager.shared.rootViewController ?? topVC).getScreen(),
        "error_code": (error as? NSError)?.code ?? "-1"
      ]
    default:
      return nil
    }
  }
}
