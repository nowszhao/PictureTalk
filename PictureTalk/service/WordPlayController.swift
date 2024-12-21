import SwiftUI
import AVFoundation

struct WordPlayButton: View {
    let words: [WordItem]
    let sceneId: String
    @StateObject private var viewModel = WordPlayViewModel()
    
    var body: some View {
        Button(action: {
            if viewModel.isPlaying {
                viewModel.stopPlaying()
            } else {
                viewModel.startPlaying(words: words, sceneId: sceneId)
            }
        }) {
            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .shadow(radius: 3)
        }
    }
} 
