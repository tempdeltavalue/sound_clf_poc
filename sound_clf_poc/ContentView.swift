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
    
    // float model
    var floatModel: test_model2?

    init() {
        let config = MLModelConfiguration()
//        do {
//            soundClfModel = try CreateMLModel(configuration: config)
//        } catch {
//            print("Model init error info: \(error)")
//        }
        
//        soundClfRequest = makeRequest()
        
        
        floatModel = try! test_model2(configuration: config)
    
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
        split_and_infer()
    }
    
    func split_and_infer() {
        if let url = Bundle.main.url(forResource: "1_min", withExtension: "wav") {
            let file = try! AVAudioFile(forReading: url)
            if let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: file.fileFormat.sampleRate,
                                          channels: 1,
                                          interleaved: false) {
                
                //  buffer byte capacity cannot be represented by an uint32_t
                
                let audioFrameCount = AVAudioFrameCount(file.fileFormat.sampleRate * 100)  // file.length

                if let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: audioFrameCount) {
                    try! file.read(into: buf)
                    
                    // this makes a copy,
                    let floatArray = Array(UnsafeBufferPointer(start: buf.floatChannelData![0], count:Int(buf.frameLength)))

                    // raw inference
                    
                    
                    let batch_size: Int = 10
                    let crop_len: Int = 44100
                    
                    var crop_arr: [[Float]] = floatArray.chunks(crop_len)
                    crop_arr = Array(crop_arr[...21])  // take first 20 seconds Convert slice to arr
                    
                    
                    var batch_input = [test_model2Input]()
                    
                    var start = CFAbsoluteTimeGetCurrent()

                    for one_sec in crop_arr {
                        do {
                            
                            if  batch_input.count == batch_size {
                                // Make inference
                                let prediction = try floatModel?.predictions(inputs: batch_input)
                                
                                guard let prediction = prediction else { return }
                                
                                let end = CFAbsoluteTimeGetCurrent()
                                let duration = end - start
                                

                                print("\n Batch prediction inf time:", duration)
                                for pred in prediction {
                                    print(pred.Identity)
                                }
                                
                                batch_input.removeAll()
                                
                                start = CFAbsoluteTimeGetCurrent()

                            } else {
                                let input_placeholder = try MLMultiArray(shape: [1, 44100, 1], dataType: .float64)

                                // Accumulate batch
                                //Looks seely
                                //https://stackoverflow.com/questions/67836718/how-to-initialise-a-multi-dimensional-mlmultiarray
                                for row in 0..<crop_len {
                                    input_placeholder[[0, row, 1] as [NSNumber]] = (one_sec[row]) as NSNumber
                                }
                                
                                let modelInput = test_model2Input(input_4: input_placeholder)
                                batch_input.append(modelInput)
                            }
                        } catch {
                            print("Error!: ", error.localizedDescription)
                        }
                    
                        

                    }
                }
            }
        }
    }

    
    // https://stackoverflow.com/questions/42178958/write-array-of-floats-to-a-wav-audio-file-in-swift
    func saveWav(_ buff: [Float]) {
        let SAMPLE_RATE =  44100
        let fileManager = FileManager.default

        let documentDirectory = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
        try! FileManager.default.createDirectory(atPath: documentDirectory.path, withIntermediateDirectories: true, attributes: nil)
        let url = documentDirectory.appendingPathComponent("out2.wav")
        

        let outputFormatSettings = [
            AVFormatIDKey:kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey:32,
            AVLinearPCMIsFloatKey: true,
            //  AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: SAMPLE_RATE,
            AVNumberOfChannelsKey: 1
            ] as [String : Any]

        let audioFile = try? AVAudioFile(forWriting: url, settings: outputFormatSettings, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: true)

        let bufferFormat = AVAudioFormat(settings: outputFormatSettings)!

        let outputBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(buff.count))!

        // Extra step
        for i in 0..<buff.count {
            outputBuffer.floatChannelData!.pointee[i] = Float( buff[i] )
        }
        //
        
        outputBuffer.frameLength = AVAudioFrameCount( buff.count )

        do{
            try audioFile?.write(from: outputBuffer)
            startClassification(audioFileURL: url)


        } catch let error as NSError {
            print("error:", error.localizedDescription)
        }
    }
    
    
    func startClassification(audioFileURL: URL = URL(fileURLWithPath: Bundle.main.path(forResource: "out2.wav", ofType: nil)!)) {
        
        print("Audio file url for prediction", audioFileURL.absoluteString)
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





// https://gist.github.com/ericdke/fa262bdece59ff786fcb
extension Array {
    func chunks(_ chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
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
