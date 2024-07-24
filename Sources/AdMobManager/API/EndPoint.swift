//
//  EndPoint.swift
//  Base_MVVM_Combine
//
//  Created by Trịnh Xuân Minh on 02/02/2024.
//

import Foundation

enum EndPoint {
  case itunesVersion(regionCode: String, bundleId: String)
  case appStoreConnectVersion(appID: String, token: String)
  
  var domain: String {
    switch self {
    case .itunesVersion:
      return "https://itunes.apple.com"
    case .appStoreConnectVersion:
      return "https://api.appstoreconnect.apple.com"
    }
  }
  
  var path: String? {
    switch self {
    case .itunesVersion(let regionCode, _):
      return "/\(regionCode)/lookup"
    case .appStoreConnectVersion(let appID, _):
      return "/v1/apps/\(appID)/appStoreVersions"
    }
  }
  
  var method: String {
    switch self {
    default:
      return "GET"
    }
  }
  
  var params: [String: String?] {
    var params: [String: String?] = [:]
    switch self {
    case .itunesVersion(_, let bundleId):      
      params["bundleId"] = bundleId
    case .appStoreConnectVersion:
      params["limit"] = "10"
    }
    return params
  }
  
  var headers: [String: String?] {
    var headers: [String: String?] = [
      "Content-Type": "application/json"
    ]
    switch self {
    case .appStoreConnectVersion(_, let token):
      headers["Authorization"] = "Bearer \(token)"
    default:
      break
    }
    return headers
  }
}

extension EndPoint {
  func request(body: Data?) -> URLRequest? {
    guard
      let url = URL(string: domain),
      var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
    else {
      return nil
    }
    if let path {
      urlComponents.path = path
    }
    urlComponents.queryItems = params.map({
      return URLQueryItem(name: $0, value: $1)
    })
    
    guard let urlRequest = urlComponents.url else {
      return nil
    }
    var request = URLRequest(url: urlRequest)
    request.httpMethod = method
    
    headers.forEach {
      request.setValue($1, forHTTPHeaderField: $0)
    }
    
    if let body {
      request.httpBody = body
    }
    
    return request
  }
}
