//
//  ContentView.swift
//  sound_clf_poc
//
//  Created by tempdeltavalue on 30.06.2023.
//

import SwiftUI
import SoundAnalysis


struct ContentView: View {
    var soundClfModel: CreateMLModel?
    var soundClfRequest: SNClassifySoundRequest?

    init() {
        let config = MLModelConfiguration()
        do {
            soundClfModel = try CreateMLModel(configuration: config)
        } catch {
            print("Model init error info: \(error)")
        }
        
        soundClfRequest = makeRequest()
    }
    
    var body: some View {
        VStack {
            Button(action: clfButtonTapped) {
                Text("Classify")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    func clfButtonTapped() {
        let path = Bundle.main.path(forResource: "8_h.wav", ofType: nil)!
        let file = try! AVAudioFile(forReading: URL(string: path)!)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)!

        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
        try! file.read(into: buf!)

        // this makes a copy, you might not want that
        let floatArray = Array(UnsafeBufferPointer(start: buf!.floatChannelData![0], count:Int(buf!.frameLength)))

        print("floatArray \(floatArray)\n")
        
    }
    

    
    
    
    func startClassification() {
        let path = Bundle.main.path(forResource: "1_0.wav", ofType: nil)!
        let audioFileURL = URL(fileURLWithPath: path)
        
        let resultsObserver = ResultsObserver()
        
        guard let soundClfRequest = soundClfRequest else {
            print("soundClfRequest isn't initialized")

            return
        
        }
        do {
            let audioFileAnalyzer = try SNAudioFileAnalyzer(url: audioFileURL)
            try audioFileAnalyzer.add(soundClfRequest, withObserver: resultsObserver)
            
            audioFileAnalyzer.analyze()

        } catch {
            print(error)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// Result observer

class ResultsObserver: NSObject, SNResultsObserving {

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else {
            return
        }
        
        print(classificationResult)

    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("result did fail with error", error)
    }
    
    func requestDidComplete(_ request: SNRequest) {
        
    }
}


private extension ContentView {
    func makeRequest() -> SNClassifySoundRequest? {
        guard let model = soundClfModel else { return nil }
        
        do {
            let customRequest = try SNClassifySoundRequest(mlModel: model.model)
            return customRequest
        } catch {
            print("Request init error", error)
            return nil
        }
    }


}



// AVFoundation audio splitting
// https://medium.com/macoclock/splitting-audio-with-swift-ba765281c50
// How to get audio without storing
//func startSplitting() {
//    let path = Bundle.main.path(forResource: "8_h.wav", ofType: nil)!
//    let audioFileURL = URL(fileURLWithPath: path)
//    // Get the file as an AVAsset
//    let asset: AVAsset = AVAsset(url: audioFileURL)
//
//    // Get the length of the audio file asset
//    let duration = CMTimeGetSeconds(asset.duration)
//    // Determine how many segments we want
//    let numOfSegments = 9600
//    // For each segment, we need to split it up
//    for index in 0...numOfSegments {
//        splitAudio(asset: asset, segment: index)
//    }
//}
//
//func splitAudio(asset: AVAsset, segment: Int) {
//    // Create a new AVAssetExportSession
//    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
//    // Set the output file type to m4a
//    exporter.outputFileType = AVFileType.m4a
//    // Create our time range for exporting
//    let startTime = CMTimeMake(value: Int64(5 * 60 * segment), timescale: 1)
//    let endTime = CMTimeMake(value: Int64(5 * 60 * (segment+1)), timescale: 1)
//    // Set the time range for our export session
//    exporter.timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
//    // Set the output file path
//    exporter.outputURL = URL(string: "file:///Users/campionfellin/Desktop/audio-\(segment).m4a")
//    // Do the actual exporting
//    exporter.exportAsynchronously(completionHandler: {
//        switch exporter.status {
//            case AVAssetExportSession.Status.failed:
//                print("Export failed.")
//            default:
//                print("Export complete.")
//        }
//    })
//    return
//}
