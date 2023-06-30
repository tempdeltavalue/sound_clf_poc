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
