//
//  QRScanner.swift
//  QRScanner
//
//  Created by Samet Çağrı Aktepe on 18.03.2024.
//

import AVFoundation
import Contacts
import CoreLocation
import MapKit
import NetworkExtension
import SwiftUI

class QRScannerController: UIViewController {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?

    var delegate: AVCaptureMetadataOutputObjectsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get the back-facing camera for capturing videos
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get the camera device")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            videoInput = try AVCaptureDeviceInput(device: captureDevice)

        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }

        // Set the input device on the capture session.
        captureSession.addInput(videoInput)

        // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)

        // Set delegate and use the default dispatch queue to execute the call back
        captureMetadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [.qr]

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)

        // Start video capture.
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
}

struct QRScanner: UIViewControllerRepresentable {
    @Binding var result: String

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.delegate = context.coordinator

        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        @Binding var scanResult: String

        init(_ scanResult: Binding<String>) {
            _scanResult = scanResult
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            // Check if the metadataObjects array is not nil and it contains at least one object.
            if metadataObjects.count == 0 {
                scanResult = "No QR code detected"
                return
            }

            // Get the metadata object.
            let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

            if metadataObj.type == AVMetadataObject.ObjectType.qr,
               let result = metadataObj.stringValue {
                scanResult = result

                // handle QR Code
                handleQRCode(result)
            }
        }

        /*
         text
         URL ✅
         Contact
         location ✅
         wifi
         sms ✅
         email ✅
         call ✅
         event
         */

        func handleQRCode(_ code: String) {
            let scannedCode = code.lowercased()
            // TODO: IMPLEMENT
            if scannedCode.hasPrefix("http") || scannedCode.hasPrefix("www") || scannedCode.hasSuffix(".com") {
                handleURL(code)
            } else if scannedCode.hasPrefix("geo") {
                handleLocation(code)
            } else if scannedCode.hasPrefix("begin:vcard") {
                handleContact(code)
            } else if scannedCode.hasPrefix("wifi") {
                handleWifi(code)
            } else if scannedCode.hasPrefix("smsto") {
                handleSMS(code)
            } else if scannedCode.hasPrefix("mailto") {
                handleEmail(code)
            }
            // if scannedCodes containts only numbers and +
            else if scannedCode.hasPrefix("tel") || scannedCode.hasPrefix("+") || scannedCode.allSatisfy({ $0.isNumber }) {
                // TODO: FIX
                handleCall(code)
            } else if scannedCode.hasPrefix("begin:vevent") {
                print("THIS IS AN EVENT")
            } else {
                print("THIS IS AN TEXT")
            }
        }

        func handleURL(_ url: String) {
            // MARK: ✅

            // if url has no prefix add http:// give it
            if !url.hasPrefix("http") {
                let formattedURL = "http://\(url)"
                print(formattedURL)
            }

            // open it
            if let urlToOpen = URL(string: url) {
                UIApplication.shared.open(urlToOpen)
            }
        }

        func handleLocation(_ location: String) {
            // MARK: ✅

            let locationArray = location.components(separatedBy: ",")
            // delete geo from locationArray[0]
            let latitude = locationArray[0].replacingOccurrences(of: "geo:", with: "")
            let longitude = locationArray[1]

            if let url = URL(string: "http://maps.apple.com/?q=\(latitude),\(longitude)") {
                UIApplication.shared.open(url)
            }
        }

        func handleWifi(_ wifi: String) {
            // TODO: connect wifi using wifi qr code
            // connect to wifi with given string format is WIFI:S:<SSID>;T:<WEP|WPA|blank>;P:<PASSWORD>;H:<true|false|blank>;
            let wifiCode = wifi.replacingOccurrences(of: "WIFI:", with: "")
            let components = wifiCode.components(separatedBy: ";")
            var ssid: String?
            var password: String?
            var securityType: String?
            
            for component in components {
                let keyValuePair = component.components(separatedBy: ":")
                                
                if keyValuePair.count == 2 {
                    let key = keyValuePair[0]
                    let value = keyValuePair[1]
        
                    switch key {
                    case "S":
                        ssid = value
                    case "P":
                        password = value
                    case "T":
                        securityType = value
                    default:
                        break
                    }
                    
                }
            }

            if let ssid = ssid, let password = password {
                let configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: securityType == "WEP" ? true : false)
                
                NEHotspotConfigurationManager.shared.apply(configuration) { error in
                    if let error = error {
                        print("Error: \(error.localizedDescription)")
                    } else {
                        print("Connected to \(ssid)")
                    }
                }
            }
        }

        func handleContact(_ contact: String) {
            // TODO: implement
        }

        func handleCall(_ call: String) {
            // MARK: ✅

            if let url = URL(string: "tel://\(call)") {
                UIApplication.shared.open(url)
            }
        }

        func handleSMS(_ sms: String) {
            // MARK: ✅

            let smsArray = sms.components(separatedBy: ":")
            let number = smsArray[1]
            let message = smsArray[2]

            if let url = URL(string: "sms:\(number)&body=\(message)") {
                UIApplication.shared.open(url)
            }
        }

        func handleEmail(_ email: String) {
            // format is mailto:<EMAIL>?subject=<SUBJECT>&body=<TEXT> parse it to variables
            // TODO: Implement other email formats

            if let url = URL(string: email) {
                UIApplication.shared.open(url)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($result)
    }
}
