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
  private let timeout = 15.0
  private var appID: String!
  private var keyID: String!
  private var issuerID: String!
  private var privateKey: String!
  
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
    self.appID = appID
    self.keyID = keyID
    self.issuerID = issuerID
    self.privateKey = privateKey
    
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
        // Check version đang release trên Itunes.
        let isItunesRelease = await isItunesRelease()
        if isItunesRelease {
          change(isRelease: isItunesRelease)
        } else {
          // Check version đang release trên AppStoreConnect khi dữ liệu itunes chưa kịp cập nhật.
          let isAppStoreConnectRelease = await isAppStoreConnectRelease()
          change(isRelease: isAppStoreConnectRelease)
        }
      }
    }
  }
}

extension AutoRelease {
  private func isItunesRelease() async -> Bool {
    do {
      guard let bundleId = Bundle.main.bundleIdentifier else {
        // Không lấy được bundleId.
        return true
      }
      
      let regionCodeClean: String
      if let regionCode = Locale.current.regionCode,
         let cleanPath = regionCode.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        regionCodeClean = cleanPath
      } else {
        regionCodeClean = "us"
      }
      
      let endPoint = EndPoint.itunesVersion(regionCode: regionCodeClean, bundleId: bundleId)
      let itunesResponse: ItunesResponse = try await APIService().request(from: endPoint)
      guard let result = itunesResponse.results.first else {
        // Hiện tại chưa có version nào release.
        return false
      }
      let releaseVersionString = result.version
      guard let releaseVersion = Double(releaseVersionString) else {
        // Không convert được sang dạng số thập phân.
        return true
      }

      if nowVersion <= releaseVersion {
        // Version hiện tại đã release. Cache version.
        update(releaseVersion)
        return true
      } else {
        // Version hiện tại chưa release.
        return false
      }
    } catch let error {
      // Lỗi không load được version release, mặc định trạng thái bật.
      print("[AdMobManager] [Auto release] error: \(error)")
      return true
    }
  }
  
  private func isAppStoreConnectRelease() async -> Bool {
    do {
      guard let privateData = privateKey.data(using: .utf8) else {
        return true
      }
      let jwtSigner = JWTSigner.es256(privateKey: privateData)
      
      let limitTime = 300.0
      let claims = TokenClaims(iss: issuerID,
                               exp: Date(timeIntervalSinceNow: limitTime),
                               aud: "appstoreconnect-v1")
      let header = Header(kid: keyID)
      var jwt = JWT(header: header, claims: claims)
      
      let token = try jwt.sign(using: jwtSigner)
      
      let endPoint = EndPoint.appStoreConnectVersion(appID: appID, token: token)
      let appStoreConnectResponse: AppStoreConnectResponse = try await APIService().request(from: endPoint)
      guard let version = appStoreConnectResponse.versions.first(where: { $0.attributes.state == State.readyForSale.rawValue }) else {
        // Hiện tại chưa có version nào release.
        return false
      }
      let releaseVersionString = version.attributes.version
      guard let releaseVersion = Double(releaseVersionString) else {
        // Không convert được sang dạng số thập phân.
        return true
      }

      if nowVersion <= releaseVersion {
        // Version hiện tại đã release. Cache version.
        update(releaseVersion)
        return true
      } else {
        // Version hiện tại chưa release.
        return false
      }
    } catch let error {
      // Lỗi không load được version release, mặc định trạng thái bật.
      print("[AdMobManager] [Auto release] error: \(error)")
      return true
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
