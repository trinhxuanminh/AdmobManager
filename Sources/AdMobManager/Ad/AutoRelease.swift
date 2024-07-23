//
//  File.swift
//  
//
//  Created by Trịnh Xuân Minh on 19/06/2024.
//

import Foundation
import Combine
import SwiftJWT

public class AutoRelease {
  public static let shared = AutoRelease()
  
  enum Keys {
    static let cache = "ReleaseCache"
  }
  
  enum State: String {
    case readyForSale = "READY_FOR_SALE"
  }
  
  @Published public private(set) var isRelease: Bool?
  private var nowVersion: Double = 0.0
  private var releaseVersion: Double = 0.0
  private var didCheck = false
  private let timeout = 10.0
  
  public init() {
    fetch()
  }
}

extension AutoRelease {
  func check(appID: String,
             keyID: String,
             issuerID: String,
             privateKey: String
  ) {
    guard 
      let nowVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      let nowVersion = Double(nowVersionString)
    else {
      // Không lấy được version hiện tại.
      change(isRelease: true)
      return
    }
    self.nowVersion = nowVersion
    
    if nowVersion <= releaseVersion {
      // Version hiện tại đã release, đã được cache.
      change(isRelease: true)
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
        guard let self else {
          return
        }
        // Quá thời gian timeout chưa trả về, mặc định trạng thái bật.
        change(isRelease: true)
      }
      Task {
        // Tìm version đang release trên AppStore.
        await load(appID, keyID, issuerID, privateKey)
      }
    }
  }
}

extension AutoRelease {
  private func load(_ appID: String,
                    _ keyID: String,
                    _ issuerID: String,
                    _ privateKey: String
  ) async {
    do {
      guard let privateData = privateKey.data(using: .utf8) else {
        change(isRelease: true)
        return
      }
      let jwtSigner = JWTSigner.es256(privateKey: privateData)
      
      let limitTime = 120.0
      let claims = TokenClaims(iss: issuerID,
                               exp: Date(timeIntervalSinceNow: limitTime),
                               aud: "appstoreconnect-v1")
      let header = Header(kid: keyID)
      var jwt = JWT(header: header, claims: claims)
      
      let token = try jwt.sign(using: jwtSigner)
      
      print("[AdMobManager] [Auto release] token: \(token)")
      
      let endPoint = EndPoint.releaseVersion(appID: appID,
                                             token: token)
      let releaseResponse: ReleaseResponse = try await APIService().request(from: endPoint)
      guard let version = releaseResponse.versions.first(where: { $0.attributes.state == State.readyForSale.rawValue }) else {
        // Hiện tại chưa có version nào release.
        change(isRelease: false)
        return
      }
      let releaseVersionString = version.attributes.version
      guard let releaseVersion = Double(releaseVersionString) else {
        // Không convert được sang dạng số thập phân.
        change(isRelease: true)
        return
      }

      if nowVersion <= releaseVersion {
        // Version hiện tại đã release. Cache version.
        update(releaseVersion)
        change(isRelease: true)
      } else {
        // Version hiện tại chưa release.
        change(isRelease: false)
      }
    } catch let error {
      // Lỗi không load được version release, mặc định trạng thái bật.
      print("[AdMobManager] [Auto release] error: \(error)")
      change(isRelease: true)
    }
  }
  
  private func change(isRelease: Bool) {
    guard !didCheck else {
      return
    }
    self.didCheck = true
    self.isRelease = isRelease
  }
  
  private func fetch() {
    self.releaseVersion = UserDefaults.standard.double(forKey: Keys.cache)
  }
  
  private func update(_ releaseVersion: Double) {
    UserDefaults.standard.set(releaseVersion, forKey: Keys.cache)
    fetch()
  }
}
