//
//  Size13NativeAdView.swift
//  AdMobManager
//
//  Created by Trịnh Xuân Minh on 27/03/2022.
//

import UIKit
import GoogleMobileAds
import SnapKit
import NVActivityIndicatorView

/// This class returns a UIView displaying NativeAd.
/// ```
/// import AdMobManager
/// ```
/// Can be instantiated programmatically or Interface Builder. Use as UIView. Ad display is automatic.
/// - Warning: NativeAd will not be displayed without adding ID.
@IBDesignable public class Size13NativeAdView: BaseView, GADVideoControllerDelegate {
  @IBOutlet var contentView: UIView!
  @IBOutlet weak var callToActionButton: UIButton!
  @IBOutlet weak var bodyLabel: UILabel!
  @IBOutlet weak var headlineLabel: UILabel!
  @IBOutlet weak var adLabel: UILabel!
  @IBOutlet weak var nativeAdView: GADNativeAdView!
  @IBOutlet weak var mediaView: GADMediaView!
  private lazy var loadingView: NVActivityIndicatorView = {
    let loadingView = NVActivityIndicatorView(frame: .zero)
    loadingView.type = .ballPulse
    loadingView.padding = 30.0
    return loadingView
  }()
  
  private var nativeAd: NativeAd?
  private var didStartAnimation = false
  
  public override func removeFromSuperview() {
    self.nativeAd = nil
    super.removeFromSuperview()
  }
  
  public override func draw(_ rect: CGRect) {
    super.draw(rect)
    guard !didStartAnimation else {
      return
    }
    self.didStartAnimation = true
    startAnimation()
  }
  
  override func addComponents() {
    Bundle.module.loadNibNamed(String(describing: Size13NativeAdView.self),
                               owner: self,
                               options: nil)
    addSubview(contentView)
    addSubview(loadingView)
  }
  
  override func setConstraints() {
    contentView.frame = bounds
    contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    loadingView.snp.makeConstraints { make in
      make.center.equalToSuperview()
      make.width.height.equalTo(20)
    }
  }
  
  override func setProperties() {
    changeLoading(color: UIColor(rgb: 0x000000))
    
    mediaView.clipsToBounds = true
    mediaView.layer.cornerRadius = 8.0
    
    callToActionButton.layer.cornerRadius = 8.0
    callToActionButton.clipsToBounds = true
    
    adLabel.layer.cornerRadius = 4.0
    adLabel.clipsToBounds = true
    adLabel.layer.borderWidth = 1.0
  }
  
  override func setColor() {
    adLabel.backgroundColor = .clear
    adLabel.textColor = UIColor(rgb: 0x39BA19)
    adLabel.layer.borderColor = UIColor(rgb: 0x39BA19).cgColor
    
    headlineLabel.textColor = UIColor(rgb: 0x000000)
    
    bodyLabel.textColor = UIColor(rgb: 0x27303E)
    
    callToActionButton.setTitleColor(UIColor(rgb: 0xFFFFFF), for: .normal)
    callToActionButton.backgroundColor = UIColor(rgb: 0x00A9A8)
  }
  
  /// This function returns the minimum recommended height.
  public class func adHeightMinimum(width: CGFloat) -> CGFloat {
    let mediaHeight = (width - 20) / 16 * 9
    return (mediaHeight < 120 ? 120 : mediaHeight) + 93
  }
  
  public func register(id: String) {
    if let nativeAd = nativeAd {
      binding(ad: nativeAd.getAd())
      return
    }
    let nativeAd = NativeAd()
    nativeAd.setAdUnitID(id)
    nativeAd.setBinding { [weak self] in
      guard let self = self else {
        return
      }
      self.binding(ad: nativeAd.getAd())
    }
    self.nativeAd = nativeAd
  }
  
  public func changeColor(
    title: UIColor? = nil,
    ad: UIColor? = nil,
    adBackground: UIColor? = nil,
    body: UIColor? = nil,
    mediaBackground: UIColor? = nil,
    callToAction: UIColor? = nil,
    callToActionBackground: UIColor? = nil
  ) {
    if let title = title {
      headlineLabel.textColor = title
    }
    if let ad = ad {
      adLabel.textColor = ad
      adLabel.layer.borderColor = ad.cgColor
    }
    if let adBackground = adBackground {
      adLabel.backgroundColor = adBackground
    }
    if let body = body {
      bodyLabel.textColor = body
    }
    if let mediaBackground = mediaBackground {
      mediaView.backgroundColor = mediaBackground
    }
    if let callToAction = callToAction {
      callToActionButton.setTitleColor(callToAction, for: .normal)
    }
    if let callToActionBackground = callToActionBackground {
      callToActionButton.backgroundColor = callToActionBackground
    }
  }
  
  public func changeFont(
    title: UIFont? = nil,
    ad: UIFont? = nil,
    body: UIFont? = nil,
    callToAction: UIFont? = nil
  ) {
    if let title = title {
      headlineLabel.font = title
    }
    if let ad = ad {
      adLabel.font = ad
    }
    if let body = body {
      bodyLabel.font = body
    }
    if let callToAction = callToAction {
      callToActionButton.titleLabel?.font = callToAction
    }
  }
  
  public func changeLoading(type: NVActivityIndicatorType? = nil, color: UIColor? = nil) {
    var isAnimating = false
    if loadingView.isAnimating {
      isAnimating = true
      loadingView.stopAnimating()
    }
    if let type = type {
      loadingView.type = type
    }
    if let color = color {
      loadingView.color = color
    }
    guard isAnimating else {
      return
    }
    loadingView.startAnimating()
  }
}

extension Size13NativeAdView {
  private func startAnimation() {
    nativeAdView.isHidden = true
    loadingView.startAnimating()
  }
  
  private func stopAnimation() {
    nativeAdView.isHidden = false
    loadingView.stopAnimating()
  }
  
  private func binding(ad: GADNativeAd?) {
    guard let nativeAd = ad else {
      return
    }
    
    stopAnimation()
    
    nativeAdView.nativeAd = nativeAd
    
    (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
    
    nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
    mediaView.isHidden = false
    let mediaContent = nativeAd.mediaContent
    if mediaContent.hasVideoContent {
      mediaContent.videoController.delegate = self
    }
    
    (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
    nativeAdView.bodyView?.isHidden = nativeAd.body == nil
    
    (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
    nativeAdView.callToActionView?.isUserInteractionEnabled = false
  }
}
