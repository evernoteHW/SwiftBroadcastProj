//
//  ViewController.swift
//  SwiftBroadcastProj
//
//  Created by WeiHu on 2016/12/1.
//  Copyright © 2016年 WeiHu. All rights reserved.
//

import UIKit
import AVFoundation

struct Preference {
    static let defaultInstance:Preference = Preference()
    
    var uri:String? = "rtmp://10.14.219.31/live"
    var streamName:String? = "TMD"
}

class ViewController: UIViewController {

    var rtmpConnection:RTMPConnection = RTMPConnection()
    var rtmpStream:RTMPStream!
    var sharedObject:RTMPSharedObject!
    var currentEffect:VisualEffect? = nil
    var httpService:HTTPService!
    var httpStream:HTTPStream!
    
    let touchView: UIView! = UIView()
    let lfView:GLLFView = GLLFView(frame: CGRect.zero)
    
    var currentFPSLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()
    
    var publishButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blue
        button.setTitle("●", for: UIControlState())
        button.layer.masksToBounds = true
        return button
    }()
    
    var pauseButton:UIButton = {
        let button:UIButton = UIButton()
        button.backgroundColor = UIColor.blue
        button.setTitle("P", for: UIControlState())
        button.layer.masksToBounds = true
        return button
    }()
    
    
    var videoBitrateLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()
    
    var videoBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 32
        slider.maximumValue = 1024
        return slider
    }()
    
    var audioBitrateLabel:UILabel = {
        let label:UILabel = UILabel()
        label.textColor = UIColor.white
        return label
    }()
    
    var zoomSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 0.0
        slider.maximumValue = 5.0
        return slider
    }()
    
    var audioBitrateSlider:UISlider = {
        let slider:UISlider = UISlider()
        slider.minimumValue = 16
        slider.maximumValue = 120
        return slider
    }()
    
    var fpsControl:UISegmentedControl = {
        let segment:UISegmentedControl = UISegmentedControl(items: ["15.0", "30.0", "60.0"])
        segment.tintColor = UIColor.white
        return segment
    }()
    
    var effectSegmentControl:UISegmentedControl = {
        let segment:UISegmentedControl = UISegmentedControl(items: ["None", "Monochrome", "Pronama"])
        segment.tintColor = UIColor.white
        return segment
    }()
    
    var currentPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.back
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sampleRate:Double = 44_100
        
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(sampleRate)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeVideoChat)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
        
        currentFPSLabel.text = "FPS"
        
        zoomSlider.addTarget(self, action: #selector(ViewController.onSliderValueChanged(_:)), for: .valueChanged)
        videoBitrateSlider.addTarget(self, action: #selector(ViewController.onSliderValueChanged(_:)), for: .valueChanged)
        audioBitrateSlider.addTarget(self, action: #selector(ViewController.onSliderValueChanged(_:)), for: .valueChanged)
        fpsControl.addTarget(self, action: #selector(ViewController.onFPSValueChanged(_:)), for: .valueChanged)
        effectSegmentControl.addTarget(self, action: #selector(ViewController.onEffectValueChanged(_:)), for: .valueChanged)
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Torch", style: .plain, target: self, action: #selector(ViewController.toggleTorch(_:))),
            UIBarButtonItem(title: "Camera", style: .plain, target: self, action: #selector(ViewController.rotateCamera(_:)))
        ]
        
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.attachAudio(AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio), automaticallyConfiguresApplicationAudioSession: false)
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back))
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: NSKeyValueObservingOptions.new, context: nil)
        
        rtmpStream.captureSettings = [
            "sessionPreset": AVCaptureSessionPreset1280x720,
            "continuousAutofocus": true,
            "continuousExposure": true,
        ]
        
        rtmpStream.videoSettings = [
            "width": 720,
            "height": 1280,
        ]
        
        publishButton.addTarget(self, action: #selector(ViewController.on(publish:)), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(ViewController.on(pause:)), for: .touchUpInside)
        
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.tapScreen(_:)))
        touchView.addGestureRecognizer(tapGesture)
        touchView.frame = view.frame
        touchView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        videoBitrateSlider.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        audioBitrateSlider.value = Float(RTMPStream.defaultAudioBitrate) / 1024
        
        lfView.attachStream(rtmpStream)
        
        view.addSubview(lfView)
        view.addSubview(touchView)
        view.addSubview(videoBitrateLabel)
        view.addSubview(videoBitrateSlider)
        view.addSubview(audioBitrateLabel)
        view.addSubview(audioBitrateSlider)
        view.addSubview(zoomSlider)
        view.addSubview(fpsControl)
        view.addSubview(currentFPSLabel)
        view.addSubview(effectSegmentControl)
        view.addSubview(pauseButton)
        view.addSubview(publishButton)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let navigationHeight:CGFloat = 66
        lfView.frame = view.bounds
        fpsControl.frame = CGRect(x: view.bounds.width - 200 - 10 , y: navigationHeight + 40, width: 200, height: 30)
        effectSegmentControl.frame = CGRect(x: view.bounds.width - 200 - 10 , y: navigationHeight, width: 200, height: 30)
        pauseButton.frame = CGRect(x: view.bounds.width - 44 - 20, y: view.bounds.height - 44 * 2 - 20 * 2, width: 44, height: 44)
        publishButton.frame = CGRect(x: view.bounds.width - 44 - 20, y: view.bounds.height - 44 - 20, width: 44, height: 44)
        currentFPSLabel.frame = CGRect(x: 10, y: 10, width: 40, height: 40)
        zoomSlider.frame = CGRect(x: 20, y: view.frame.height - 44 * 3 - 22, width: view.frame.width - 44 - 60, height: 44)
        videoBitrateLabel.text = "video \(Int(videoBitrateSlider.value))/kbps"
        videoBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 * 2 - 22, width: 150, height: 44)
        videoBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44 * 2, width: view.frame.width - 44 - 60, height: 44)
        audioBitrateLabel.text = "audio \(Int(audioBitrateSlider.value))/kbps"
        audioBitrateLabel.frame = CGRect(x: view.frame.width - 150 - 60, y: view.frame.height - 44 - 22, width: 150, height: 44)
        audioBitrateSlider.frame = CGRect(x: 20, y: view.frame.height - 44, width: view.frame.width - 44 - 60, height: 44)
    }
    
    func rotateCamera(_ sender:UIBarButtonItem) {
        let position:AVCaptureDevicePosition = currentPosition == .back ? .front : .back
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position))
        currentPosition = position
    }
    
    func toggleTorch(_ sender:UIBarButtonItem) {
        rtmpStream.torch = !rtmpStream.torch
    }
    
    func showPreference(_ sender:UIBarButtonItem) {
//        let preference:PreferenceController = PreferenceController()
//        preference.view.backgroundColor = UIColor(colorLiteralRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.25)
//        preference.view.frame = view.frame
//        preference.modalPresentationStyle = .overCurrentContext
//        preference.modalTransitionStyle = .crossDissolve
//        present(preference, animated: true, completion: nil)
    }
    
    func onSliderValueChanged(_ slider:UISlider) {
        if (slider == audioBitrateSlider) {
            audioBitrateLabel.text = "audio \(Int(slider.value))/kbps"
            rtmpStream.audioSettings["bitrate"] = slider.value * 1024
        }
        if (slider == videoBitrateSlider) {
            videoBitrateLabel.text = "video \(Int(slider.value))/kbsp"
            rtmpStream.videoSettings["bitrate"] = slider.value * 1024
        }
        if (slider == zoomSlider) {
            rtmpStream.ramp(toVideoZoomFactor: CGFloat(slider.value), withRate: 5.0)
        }
    }
    
    func on(pause:UIButton) {
        print("pause")
        rtmpStream.togglePause()
    }
    
    func on(publish:UIButton) {
        if (publish.isSelected) {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector:#selector(ViewController.rtmpStatusHandler(_:)), observer: self)
            publish.setTitle("●", for: UIControlState())
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector:#selector(ViewController.rtmpStatusHandler(_:)), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            publish.setTitle("■", for: UIControlState())
        }
        publish.isSelected = !publish.isSelected
    }
    
    func rtmpStatusHandler(_ notification:Notification) {
        let e:Event = Event.from(notification)
        if let data:ASObject = e.data as? ASObject , let code:String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                rtmpStream!.publish(Preference.defaultInstance.streamName!)
            // sharedObject!.connect(rtmpConnection)
            default:
                break
            }
        }
    }
    
    func tapScreen(_ gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view , gesture.state == .ended {
            let touchPoint: CGPoint = gesture.location(in: gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                                                   y: touchPoint.y/gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }
    
    func onFPSValueChanged(_ segment:UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            rtmpStream.captureSettings["fps"] = 15.0
        case 1:
            rtmpStream.captureSettings["fps"] = 30.0
        case 2:
            rtmpStream.captureSettings["fps"] = 60.0
        default:
            break
        }
    }
    
    func onEffectValueChanged(_ segment:UISegmentedControl) {
        if let currentEffect:VisualEffect = currentEffect {
            let _:Bool = rtmpStream.unregisterEffect(video: currentEffect)
        }
        switch segment.selectedSegmentIndex {
        case 1:
//            currentEffect = MonochromeEffect()
            let _:Bool = rtmpStream.registerEffect(video: currentEffect!)
        case 2:
//            currentEffect = PronamaEffect()
            let _:Bool = rtmpStream.registerEffect(video: currentEffect!)
        default:
            break
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (Thread.isMainThread) {
            currentFPSLabel.text = "\(rtmpStream.currentFPS)"
        }
    }


}

