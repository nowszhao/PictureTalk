import AVFoundation

class AudioService: ObservableObject {
    static let shared = AudioService()
    private var audioPlayer: AVPlayer?
    
    func playWord(_ word: String) {
        let wordurl = "https://dict.youdao.com/dictvoice?audio=\(word.lowercased())&type=2"
        print("wordurl:",wordurl)
        if let url = URL(string: wordurl) {
            let playerItem = AVPlayerItem(url: url)
            audioPlayer = AVPlayer(playerItem: playerItem)
            audioPlayer?.play()
        }
    }
} 
