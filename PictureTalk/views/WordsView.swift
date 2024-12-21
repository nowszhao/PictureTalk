import SwiftUI

struct WordsView: View {
    @StateObject private var wordManager = WordManager.shared
    @State private var searchText = ""
    @State private var selectedWord: UniqueWord?
    @State private var showingWordDetail = false
    @State private var showingFilterSheet = false
    @FocusState private var isSearchFocused: Bool
    
    // 过滤状态
    @State private var showFavoritesOnly = false
    @State private var selectedStatus: LearningWord.WordStatus?
    
    var filteredWords: [UniqueWord] {
        var words = wordManager.allWords
        
        // 应用收藏过滤
        if showFavoritesOnly {
            words = words.filter { $0.isFavorite }
        }
        
        // 应用搜索过滤
        if !searchText.isEmpty {
            words = words.filter { $0.word.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 应用状态过滤
        if let status = selectedStatus {
            words = words.filter { $0.learningStatus == status }
        }
        
        return words
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 60)
            
            // 搜索栏
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索单词", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            isSearchFocused = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // 过滤按钮
                Button(action: {
                    showingFilterSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("筛选")
                    }
                    .foregroundColor(hasActiveFilters ? .blue : .primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 单词列表
            List {
                ForEach(filteredWords) { word in
                    WordCard(word: word) {
                        selectedWord = word
                        showingWordDetail = true
                        isSearchFocused = false
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingWordDetail) {
            if let word = selectedWord {
                WordDetailView(word: word)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(
                showFavoritesOnly: $showFavoritesOnly,
                selectedStatus: $selectedStatus
            )
        }
    }
    
    // 检查是否有激活的过滤器
    private var hasActiveFilters: Bool {
        showFavoritesOnly || selectedStatus != nil
    }
}

// 过滤器抽屉视图
struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showFavoritesOnly: Bool
    @Binding var selectedStatus: LearningWord.WordStatus?
    
    var body: some View {
        NavigationView {
            List {
                // 收藏过滤
                Section("收藏") {
                    Toggle("仅显示收藏单词", isOn: $showFavoritesOnly)
                }
                
                // 学习状态过滤
                Section("学习状态") {
                    Button(action: {
                        selectedStatus = nil
                    }) {
                        HStack {
                            Text("全部")
                            Spacer()
                            if selectedStatus == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    ForEach(LearningWord.WordStatus.allCases, id: \.self) { status in
                        Button(action: {
                            selectedStatus = status
                        }) {
                            HStack {
                                Text(status.description)
                                Spacer()
                                if selectedStatus == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        showFavoritesOnly = false
                        selectedStatus = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}