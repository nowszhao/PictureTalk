import SwiftUI

struct WordCard: View {
    let word: UniqueWord
    @ObservedObject private var wordManager = WordManager.shared
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧单词信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(word.word)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    if let status = word.learningStatus {
                        LearningStatusBadge(status: status)
                    }
                }
                .onTapGesture {
                    onTap()
                }
                
                Text(word.phoneticsymbols)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(word.explanation)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 右侧信息
            VStack(alignment: .trailing, spacing: 4) {
                Button(action: {
                    wordManager.toggleFavorite(word)
                }) {
                    Image(systemName: word.isFavorite ? "star.fill" : "star")
                        .foregroundColor(word.isFavorite ? .yellow : .gray)
                }
                
                Text("\(word.scenes.count) 图")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
}

struct LearningStatusBadge: View {
    let status: LearningWord.WordStatus
    
    var body: some View {
        Text(status.description)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(4)
    }
} 
