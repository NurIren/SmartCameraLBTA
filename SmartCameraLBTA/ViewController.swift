//
//  ViewController.swift
//  SmartCameraLBTA
//
//  Created by Brian Voong on 7/12/17.
//  Copyright © 2017 Lets Build That App. All rights reserved.
//

import UIKit
import AVKit
import Vision
import CoreBluetooth

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, CBCentralManagerDelegate,CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var consoleMsg = ""
        switch(central.state) {
        case .poweredOff:
            consoleMsg = "BLE is powered off"
        case .unknown:
             consoleMsg = "BLE is powered unknown"
        case .resetting:
             consoleMsg = "BLE is powered resetting"
        case .unsupported:
             consoleMsg = "BLE is powered unsupported"
        case .unauthorized:
             consoleMsg = "BLE is powered unauthorized"
        case .poweredOn:
             consoleMsg = "BLE is powered poweredOn"
        }
        print(consoleMsg)
    }
    var centralManager: CBCentralManager!
    var globalOutput: String?
    var peripheral: CBPeripheral!
    let uuid = CBUUID(string: "b57a7299-0677-4dc6-b4b0-c10f107f0f6d")
    var characteristics: [CBCharacteristic]?
    var fileName = "/Users/nur/Documents/Arduino/steelhacks/help.txt";
    
    @IBAction func passInfoButton(_ sender: Any) {
        //let text = "some text" //just a text
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent(fileName)
            //print(fileURL)
            
            //writing
            do {
                try globalOutput?.write(fileName)
                print(globalOutput);
            }
            catch {
                print("not written")
            }
        }
        print("written")
    }
    
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("peripheral: \(peripheral)")
        
        guard let localName = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString else {
            print("could not retrieve local name")
            return
        }
        
        if localName.length > 0 {
            print("found the device")
            centralManager.stopScan()
            self.peripheral = peripheral
            centralManager.connect(peripheral, options: nil)
            print("connected with peripheral")
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("discovered services")
        
        
        for service in peripheral.services! {
            let thisService = service as CBService
            characteristics = thisService.characteristics
            peripheral.discoverCharacteristics(nil, for: thisService)
            print("discovered characteristics")
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            
            self.peripheral.setNotifyValue(true, for: thisCharacteristic)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print(characteristic)
        let array = [UInt8](characteristic.value!)
        print("array: " ,array)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //setting up bluetooth
       let services = [uuid]
        centralManager = CBCentralManager(delegate: self, queue: nil)
        centralManager.scanForPeripherals(withServices: services, options: nil)
        //peripheral(centralManager, didDiscoverServices: nil)
        
        
        
        // here is where we start up the camera
        // for more details visit: https://www.letsbuildthatapp.com/course_video?id=1252
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        
//        VNImageRequestHandler(cgImage: <#T##CGImage#>, options: [:]).perform(<#T##requests: [VNRequest]##[VNRequest]#>)
        
        setupIdentifierConfidenceLabel()
    }
  
    
    fileprivate func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        identifierLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("Camera was able to capture a frame:", Date())
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // !!!Important
        // make sure to go download the models at https://developer.apple.com/machine-learning/ scroll to the bottom 
        guard let model = try? VNCoreMLModel(for: trashnet_v1().model) else { return }
        let request = VNCoreMLRequest(model: model) { (finishedReq, err) in
            
            //perhaps check the err
            
//            print(finishedReq.results)
            
            guard let results = finishedReq.results as? [VNClassificationObservation] else { return }
            
            guard let firstObservation = results.first else { return }
            
            print(firstObservation.identifier, firstObservation.confidence)
            
            DispatchQueue.main.async {
                self.identifierLabel.text = "\(firstObservation.identifier) \(firstObservation.confidence * 100)"
                self.globalOutput = firstObservation.identifier;
                
            }
            
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }

}

