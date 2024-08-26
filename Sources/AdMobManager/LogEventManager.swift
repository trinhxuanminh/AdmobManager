//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 31/08/2023.
//

import Foundation
import FirebaseAnalytics

class LogEventManager {
  static let shared = LogEventManager()
  
  func log(event: Event) {
    Analytics.logEvent(event.name, parameters: event.parameters)
    print("[AdMobManager] [LogEventManager]", "[\(isValid(event.name))]", event.name, event.parameters ?? String())
  }
  
  private func isValid(_ input: String) -> Bool {
    guard input.count <= 40 else {
      return false
    }
    let pattern = "^[a-zA-Z0-9_]*$"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: input.utf16.count)
    return regex.firstMatch(in: input, options: [], range: range) != nil
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
  case adLoadFail(String)
  case adLoadTryFail(String)
  case adLoadTimeout(String)
  case adShowCheck(String, String?)
  case adShowRequest(String, String?)
  case adShowReady(String, String?)
  case adShowNoReady(String, String?)
  case adShowSuccess(String, String?)
  case adShowFail(String, String?)
  case adShowHide(String, String?)
  case adShowClick(String, String?)
  case adEarnReward(String, String?)
  case adPayRevenue(String, String?)
  case adNoRevenue(String, String?)
  
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
      
    case .adLoadRequest(let name):
      return "AM_\(name)_Load_Request"
    case .adLoadSuccess(let name, _):
      return "AM_\(name)_Load_Success"
    case .adLoadFail(let name):
      return "AM_\(name)_Load_Fail"
    case .adLoadTryFail(let name):
      return "AM_\(name)_Load_TryFail"
    case .adLoadTimeout(let name):
      return "AM_\(name)_Load_Timeout"
    case .adShowCheck(let placementID, _):
      return "AM_\(placementID)_Show_Check"
    case .adShowRequest(let placementID, _):
      return "AM_\(placementID)_Show_Request"
    case .adShowReady(let placementID, _):
      return "AM_\(placementID)_Show_Ready"
    case .adShowNoReady(let placementID, _):
      return "AM_\(placementID)_Show_NoReady"
    case .adShowSuccess(let placementID, _):
      return "AM_\(placementID)_Show_Success"
    case .adShowFail(let placementID, _):
      return "AM_\(placementID)_Show_Fail"
    case .adShowHide(let placementID, _):
      return "AM_\(placementID)_Show_Hide"
    case .adShowClick(let placementID, _):
      return "AM_\(placementID)_Show_Click"
    case .adEarnReward(let placementID, _):
      return "AM_\(placementID)_Earn_Reward"
    case .adPayRevenue(let placementID, _):
      return "AM_\(placementID)_Pay_Revenue"
    case .adNoRevenue(let placementID, _):
      return "AM_\(placementID)_No_Revenue"
    }
  }
  
  var parameters: [String: Any]? {
    switch self {
    case .adLoadSuccess(_, let time):
      return ["time": time]
    case .adShowCheck(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowRequest(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowReady(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowNoReady(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowSuccess(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowFail(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowHide(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adShowClick(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adEarnReward(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adPayRevenue(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    case .adNoRevenue(_, let screen):
      guard let screen else {
        return nil
      }
      return ["screen": screen]
    default:
      return nil
    }
  }
}
