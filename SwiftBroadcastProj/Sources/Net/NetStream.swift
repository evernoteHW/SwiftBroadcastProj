import Foundation
import AVFoundation
import UIKit

protocol NetStreamDrawable: class {
    var orientation:AVCaptureVideoOrientation { get set }
    var position:AVCaptureDevicePosition { get set }

    func draw(image:CIImage)
    func render(image: CIImage, to toCVPixelBuffer: CVPixelBuffer)
}

// MARK: -
open class NetStream: NSObject {
    var mixer:AVMixer = AVMixer()
    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.Stream.lock", attributes: []
    )

    deinit {
        #if os(iOS)
        syncOrientation = false
        #endif
    }

    open var torch:Bool {
        get {
            var torch:Bool = false
            lockQueue.sync {
                torch = self.mixer.videoIO.torch
            }
            return torch
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.torch = newValue
            }
        }
    }

    #if os(iOS)
    open var orientation:AVCaptureVideoOrientation {
        get {
            var orientation:AVCaptureVideoOrientation!
            DispatchQueue.main.sync {
                orientation = self.mixer.videoIO.orientation
            }
            return orientation
        }
        set {
            DispatchQueue.main.async {
                self.mixer.videoIO.orientation = newValue
            }
        }
    }

    open var syncOrientation:Bool = false {
        didSet {
            guard syncOrientation != oldValue else {
                return
            }
            if (syncOrientation) {
                NotificationCenter.default.addObserver(self, selector: #selector(NetStream.on(uiDeviceOrientationDidChange:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            }
        }
    }
    #endif

    open var audioSettings:[String:Any] {
        get {
            var audioSettings:[String:Any]!
            lockQueue.sync {
                audioSettings = self.mixer.audioIO.encoder.dictionaryWithValues(forKeys: AACEncoder.supportedSettingsKeys)
            }
            return  audioSettings
        }
        set {
            lockQueue.async {
                self.mixer.audioIO.encoder.setValuesForKeys(newValue)
            }
        }
    }

    open var videoSettings:[String:Any] {
        get {
            var videoSettings:[String:Any]!
            lockQueue.sync {
                videoSettings = self.mixer.videoIO.encoder.dictionaryWithValues(forKeys: AVCEncoder.supportedSettingsKeys)
            }
            return videoSettings
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.encoder.setValuesForKeys(newValue)
            }
        }
    }

    open var captureSettings:[String:Any] {
        get {
            var captureSettings:[String:Any]!
            lockQueue.sync {
                captureSettings = self.mixer.dictionaryWithValues(forKeys: AVMixer.supportedSettingsKeys)
            }
            return captureSettings
        }
        set {
            lockQueue.async {
                self.mixer.setValuesForKeys(newValue)
            }
        }
    }

    open var recorderSettings:[String:[String:Any]] {
        get {
            var recorderSettings:[String:[String:Any]]!
            lockQueue.sync {
                recorderSettings = self.mixer.recorder.outputSettings
            }
            return recorderSettings
        }
        set {
            lockQueue.async {
                self.mixer.recorder.outputSettings = newValue
            }
        }
    }

    open var recorderDelegate:AVMixerRecorderDelegate? {
        get {
            var recorderDelegate:AVMixerRecorderDelegate?
            lockQueue.sync {
                recorderDelegate = self.mixer.recorder.delegate
            }
            return recorderDelegate
        }
        set {
            lockQueue.async {
                self.mixer.recorder.delegate = newValue
            }
        }
    }

    open func attachCamera(_ camera:AVCaptureDevice?) {
        DispatchQueue.main.async {
            self.mixer.videoIO.attachCamera(camera)
            self.mixer.startRunning()
        }
    }

    open func attachAudio(_ audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool = true) {
        lockQueue.async {
            self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
            )
        }
    }

    #if os(macOS)
    public func attachScreen(_ screen:AVCaptureScreenInput?) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen)
        }
    }
    #else
    open func attachScreen(_ screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }
    open func ramp(toVideoZoomFactor:CGFloat, withRate:Float) {
        lockQueue.async {
            self.mixer.videoIO.ramp(toVideoZoomFactor: toVideoZoomFactor, withRate: withRate)
        }
    }
    #endif

    open func registerEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.registerEffect(effect)
    }

    open func unregisterEffect(video effect:VisualEffect) -> Bool {
        return mixer.videoIO.unregisterEffect(effect)
    }

    open func setPointOfInterest(_ focus:CGPoint, exposure:CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }

    #if os(iOS)
    @objc private func on(uiDeviceOrientationDidChange:Notification) {
        var deviceOrientation:UIDeviceOrientation = .unknown
        if let device:UIDevice = uiDeviceOrientationDidChange.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: deviceOrientation) {
            self.orientation = orientation
        }
    }
    #endif
}
