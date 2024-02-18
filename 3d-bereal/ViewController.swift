//
//  ViewController.swift
//  3d-bereal
//
//  Created by Zichen Yuan on 2/17/24.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureMovieFileOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var recordingStartTime: Date?
    
    @IBOutlet weak var but: UIButton!
    
    @IBOutlet weak var camera: UISegmentedControl!
    @IBOutlet weak var preview: UIView!
    var countdownSeconds = 3
    @IBOutlet weak var countDown: UILabel?
    
    @IBOutlet weak var currentTime: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession()
        // Setup the timer to update every second
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimeLabel), userInfo: nil, repeats: true)
        
        preview.layer.cornerRadius = preview.frame.size.width/10
        preview.clipsToBounds = true
        // Make the button circular
        but.layer.cornerRadius = but.frame.size.width / 2
        but.clipsToBounds = true

        // Add a border
        but.layer.borderWidth = 2
        but.layer.borderColor = UIColor.white.cgColor
        
        //camera switch
        
        camera.selectedSegmentIndex = 1 // Assuming back camera is default

        // Add target action
//        camera.addTarget(self, action: #selector(cameraSwitchChanged(_:)), for: .valueChanged)
       
    }
//
//    @objc func cameraSwitchChanged(_ sender: UISegmentedControl) {
//        switchCamera(toFront: sender.selectedSegmentIndex == 0)
//    }
//
    
//    @IBAction func switchCamera(_ sender: UISegmentedControl) {
//        if camera.selectedSegmentIndex == 1{
//            camera.selectedSegmentIndex = 0
//        }
//        else{
//            camera.selectedSegmentIndex = 1
//        }
//    }
    
    
    @objc func updateTimeLabel() {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium // Use .long, .medium, .short for different styles
        currentTime?.text = formatter.string(from: Date())
    }
    
    
    func setupCameraSession() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        // Assuming you're using the rear camera
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else { return }
        
        captureSession.addInput(videoInput)
        
        videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = preview.bounds // Use the bounds of the container view
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add the previewLayer as a sublayer of the container view's layer
        preview.layer.addSublayer(previewLayer)
        
        // Make sure the previewLayer resizes with its superlayer
        previewLayer.frame = preview.layer.bounds
        preview.layer.masksToBounds = true
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    var countdownTimer: Timer?
    func startCountdown() {
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }

    @objc func updateCountdown() {
        if countdownSeconds > 0 {
            print("\(countdownSeconds)...")
            countDown?.text = String(countdownSeconds)
            countdownSeconds -= 1
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            
            // Start recording here
            recordingStartTime = Date() // Capture the current time as the start time
            let outputPath = NSTemporaryDirectory() + "output.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            
            videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
            
            // Stop recording after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.videoOutput.stopRecording()
            }
        }
    }

    
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
//        recordingStartTime = Date() // Capture the current time as the start time
//        let outputPath = NSTemporaryDirectory() + "output.mov"
//        let outputFileURL = URL(fileURLWithPath: outputPath)
//
//        videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
//
//        // Stop recording after 2 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            self.videoOutput.stopRecording()
//        }
        countdownSeconds = 3
        countDown?.text = String(countdownSeconds)
        startCountdown()
    }
    
    // AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        countDown?.text = "filming"
        print("Recording started")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        countDown?.text = "uploading"
        print("Recording finished")
        // Handle the recorded video (save or preview it) here
        
   
        // save the video to the photo library
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        
        // save to firebase
        uploadVideoToFirebaseStorage(videoURL:outputFileURL)
        
    }
    
    
    // This is the selector method called after the video has been saved
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving video: \(error.localizedDescription)")
        } else {
            print("Video saved successfully.")
        }
    }
    
    
    //to firebase
    func uploadVideoToFirebaseStorage(videoURL: URL) {
        guard let startTime = recordingStartTime else {
            print("Recording start time is nil")
            return
        }
        
        // Format the date to a string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let dateString = dateFormatter.string(from: startTime)
        var baseString = String(dateString.dropLast())
        baseString = String(baseString.dropLast())
        let flooredDateString = baseString + "00"
        
        // Use the formatted date as part of the file path
        let storageRef = Storage.storage().reference()
        let videoPath = "videos/\(flooredDateString)/\(UUID().uuidString).mov"
        let videosRef = storageRef.child(videoPath)
        
        // Start the upload process
        videosRef.putFile(from: videoURL, metadata: nil) { metadata, error in
            guard let metadata = metadata else {
                print("Error uploading video: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            print("Video uploaded successfully. Metadata: \(metadata)")
           
            
            // Optionally, get the download URL
            videosRef.downloadURL { url, error in
                guard let downloadURL = url else {
                    print("Error getting download URL: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                print("Download URL: \(downloadURL)")
                
                // Here you can also save the download URL and the timestamp to Firestore or Realtime Database
                self.saveVideoInfoToDatabase(downloadURL: downloadURL, timestamp: startTime)
            }
        }
        countDown?.text = "Done!"
    }
    
    func saveVideoInfoToDatabase(downloadURL: URL, timestamp: Date) {
        let db = Firestore.firestore()
        let videosCollection = db.collection("videos")
        
        videosCollection.addDocument(data: [
            "url": downloadURL.absoluteString,
            "timestamp": timestamp
        ]) { error in
            if let error = error {
                print("Error saving video info to database: \(error.localizedDescription)")
            } else {
                print("Video info saved successfully")
//                self.countDown?.text = "saved"
            }
        }
    }

    
    
    
//    func uploadVideoToFirebaseStorage(videoURL: URL) {
//        let storageRef = Storage.storage().reference()
//        let videosRef = storageRef.child("videos/\(UUID().uuidString).mov")
//        print(videosRef)
//
//        videosRef.putFile(from: videoURL, metadata: nil) { metadata, error in
//            guard let metadata = metadata else {
//                // Handle the error
//                print(error?.localizedDescription ?? "Unknown error")
//                return
//            }
//            // Video uploaded successfully
//            print("Video uploaded: \(metadata.size)")
//
//            // Retrieve download URL if needed
//            videosRef.downloadURL { url, error in
//                guard let downloadURL = url else {
//                    // Handle any error
//                    return
//                }
//                print("Download URL: \(downloadURL)")
//                // Optionally, save the download URL to Firestore or Realtime Database
//            }
//        }
//    }
    
}
