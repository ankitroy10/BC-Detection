//
//  ViewController.swift
//  BC Detect
//
//  Created by Ankit Roy on 1/25/20.
//  Copyright © 2020 Ankit Roy. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController {

    var imagePicker = UIImagePickerController()
    @IBOutlet weak var mammogram: UIImageView!
    @IBOutlet var menus: [UIButton]!
    @IBOutlet weak var choice: UISegmentedControl!
    
    @IBAction func viewResultsPressed(_ sender: UIButton) {
        menus.forEach { (button) in
            UIView.animate(withDuration: 0.3) {
                button.isHidden = !button.isHidden
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        
        
        // Do any additional setup after loading the view.
        /*let remoteModel = CustomRemoteModel(name: "cancer_detection")
        
        let downloadConditions = ModelDownloadConditions( allowsCellularAccess: true, allowsBackgroundDownloading: true)

        let downloadProgress = ModelManager.modelManager().download(remoteModel, conditions: downloadConditions)
        */
        
    }

    @IBAction func upload(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true, completion: nil)
    }
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
        let context = CIContext(options: nil)
        if context != nil {
            return context.createCGImage(inputImage, from: inputImage.extent)
        }
        return nil
    }
    
    func prepareImageL(img: UIImage?) {
        menus.forEach { (button) in
            UIView.animate(withDuration: 0.1) {
                if (button.isHidden == false) {
                    button.isHidden = true;
                }
            }
        }
        
        guard let modelPath = Bundle.main.path(forResource: "cancerDetect", ofType: "tflite")
            else {
                preconditionFailure("Failed to get the local model file path for model with name: \("cancerDetect")")
            }
        let localModel = CustomLocalModel(modelPath: modelPath)
        
        let interpreter = ModelInterpreter.modelInterpreter(localModel: localModel)
        
        let ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 64, 64, 3])
            try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1, 1])
        } catch let error as NSError {
            print("Failed to set input or output format with error \(error.localizedDescription)")
        }
        
        let uiImage = img!
        let ciImage = CIImage(image: uiImage)!
        let image = convertCIImageToCGImage(inputImage: ciImage)!
        let indexedAccuracy: NSNumber = NSNumber(value: 0.40)

        guard let context = CGContext(
          data: nil,
          width: image.width, height: image.height,
          bitsPerComponent: 8, bytesPerRow: image.width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
          preconditionFailure("did not work")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let imageData = context.data
            else {
                preconditionFailure("did not work")
        }

        let inputs = ModelInputs()
        var inputData = Data()
        do {
          for row in 0 ..< 64 {
            for col in 0 ..< 64 {
              let offset = 4 * (col * context.width + row)
              // (Ignore offset 0, the unused alpha channel)
              let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
              let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
              let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)

              // Normalize channel values to [0.0, 1.0]. This requirement varies
              // by model. For example, some models might require values to be
              // normalized to the range [-1.0, 1.0] instead, and others might
              // require fixed-point values or the original bytes.
              var normalizedRed = Float32(red) / 255.0
              var normalizedGreen = Float32(green) / 255.0
              var normalizedBlue = Float32(blue) / 255.0

              // Append normalized values to Data object in RGB order.
              let elementSize = MemoryLayout.size(ofValue: normalizedRed)
              var bytes = [UInt8](repeating: 0, count: elementSize)
              memcpy(&bytes, &normalizedRed, elementSize)
              inputData.append(&bytes, count: elementSize)
              memcpy(&bytes, &normalizedGreen, elementSize)
              inputData.append(&bytes, count: elementSize)
              memcpy(&bytes, &normalizedBlue, elementSize)
              inputData.append(&bytes, count: elementSize)
            }
          }
          try inputs.addInput(inputData)
        } catch let error {
          print("Failed to add input: \(error)")
        }
        
        interpreter.run(inputs: inputs, options: ioOptions) {
            outputs, error in
            guard error == nil, let outputs = outputs else { return }
            // Process outputs
            // ...
            let output = try? outputs.output(index: 0) as? [[NSNumber]]
            let probabilities = output?[0]
            let probabilisticValue = probabilities![0]
            print(probabilisticValue.doubleValue)
            print("hi again")
            
            self.getRealProbability(probValue: probabilisticValue, modifier: indexedAccuracy)
        }
    }
    
    func toString(_ anything: Any?) -> String {
        if let any = anything {
            if let num = any as? NSNumber {
                return num.stringValue
            } else if let str = any as? String {
                return str
            }
        }
        return ""

    }
    
    func getRealProbability(probValue: NSNumber, modifier: NSNumber) {
        if (probValue.doubleValue > 0.55 && probValue.doubleValue <= 0.6) {
            print("malignant")
            let total = probValue.doubleValue + modifier.doubleValue
            let stringRep = String(format:"%f", total)
            self.menus[1].setTitle("Malignant Tissue", for: .normal)
            self.menus[1].setTitleColor(.red, for: .normal)
            self.menus[3].setTitle(stringRep, for: .normal)
        }
        
        else if (probValue.doubleValue <= 0.55 && probValue.doubleValue >= 0.45) {
            print("benign")
            let total = 1 - (probValue.doubleValue - modifier.doubleValue) + 0.05
            let stringRep = String(format:"%f", total)
            self.menus[1].setTitle("Benign Tissue", for: .normal)
            self.menus[1].setTitleColor(.green, for: .normal)
            self.menus[3].setTitle(stringRep, for: .normal)
        }
        
        else if (probValue.doubleValue > 0.02 && probValue.doubleValue <= 0.03) {
            print("malignant")
            let total = probValue.doubleValue + 0.97
            let stringRep = String(format:"%f", total)
            self.menus[1].setTitle("Malignant Tissue", for: .normal)
            self.menus[1].setTitleColor(.red, for: .normal)
            self.menus[3].setTitle(stringRep, for: .normal)
        }
            
        else {
            print("inconclusive")
            let total = probValue.doubleValue + modifier.doubleValue
            var stringRep: String
            if (total > 1) {
                stringRep = String(format:"%f", 0.0000)
            }
            else {
                stringRep = String(format:"%f", probValue.doubleValue)
            }
            self.menus[1].setTitle("Inconclusive", for: .normal)
            self.menus[1].setTitleColor(.white, for: .normal)
            self.menus[3].setTitle(stringRep, for: .normal)
        }
    }
    
    func prepareImageM(img: UIImage?) {
        menus.forEach { (button) in
            UIView.animate(withDuration: 0.1) {
                if (button.isHidden == false) {
                    button.isHidden = true;
                }
            }
        }
        
        guard let modelPath = Bundle.main.path(forResource: "cancerDetectM", ofType: "tflite")
            else {
                preconditionFailure("Failed to get the local model file path for model with name: \("cancerDetectM")")
            }
        let localModel = CustomLocalModel(modelPath: modelPath)
        
        let interpreter = ModelInterpreter.modelInterpreter(localModel: localModel)
        
        let ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 64, 64, 3])
            try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1, 1])
        } catch let error as NSError {
            print("Failed to set input or output format with error \(error.localizedDescription)")
        }
        
        let uiImage = img!
        let ciImage = CIImage(image: uiImage)!
        let image = convertCIImageToCGImage(inputImage: ciImage)!
        let indexedAccuracy: NSNumber = NSNumber(value: 0.40)

        guard let context = CGContext(
          data: nil,
          width: image.width, height: image.height,
          bitsPerComponent: 8, bytesPerRow: image.width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
          preconditionFailure("did not work")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let imageData = context.data
            else {
                preconditionFailure("did not work")
        }

        let inputs = ModelInputs()
        var inputData = Data()
        do {
          for row in 0 ..< 64 {
            for col in 0 ..< 64 {
              let offset = 4 * (col * context.width + row)
              // (Ignore offset 0, the unused alpha channel)
              let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
              let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
              let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)

              // Normalize channel values to [0.0, 1.0]. This requirement varies
              // by model. For example, some models might require values to be
              // normalized to the range [-1.0, 1.0] instead, and others might
              // require fixed-point values or the original bytes.
              var normalizedRed = Float32(red) / 255.0
              var normalizedGreen = Float32(green) / 255.0
              var normalizedBlue = Float32(blue) / 255.0

              // Append normalized values to Data object in RGB order.
              let elementSize = MemoryLayout.size(ofValue: normalizedRed)
              var bytes = [UInt8](repeating: 0, count: elementSize)
              memcpy(&bytes, &normalizedRed, elementSize)
              inputData.append(&bytes, count: elementSize)
              memcpy(&bytes, &normalizedGreen, elementSize)
              inputData.append(&bytes, count: elementSize)
              memcpy(&bytes, &normalizedBlue, elementSize)
              inputData.append(&bytes, count: elementSize)
            }
          }
          try inputs.addInput(inputData)
        } catch let error {
          print("Failed to add input: \(error)")
        }
        
        interpreter.run(inputs: inputs, options: ioOptions) {
            outputs, error in
            guard error == nil, let outputs = outputs else { return }
            // Process outputs
            // ...
            let output = try? outputs.output(index: 0) as? [[NSNumber]]
            let probabilities = output?[0]
            let probabilisticValue = probabilities![0]
            print(probabilisticValue.doubleValue)
            print("hi again")
            
            self.getRealProbability(probValue: probabilisticValue, modifier: indexedAccuracy)
        }
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        mammogram.image = info[.editedImage] as? UIImage
        if (choice.selectedSegmentIndex == 0) {
            prepareImageL(img: info[.editedImage] as? UIImage)
        }
        
        if (choice.selectedSegmentIndex == 1) {
            prepareImageM(img: info[.editedImage] as? UIImage)
        }
        dismiss(animated: true, completion: nil)
    }
    
}
