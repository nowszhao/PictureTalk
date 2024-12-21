import SwiftUI

struct WordCardView: View {
    let item: WordItem
    let imageSize: CGSize
    let existingPositions: [CGRect]
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var playViewModel = WordPlayViewModel()
    
    @State private var cardSize: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var currentPosition: CGPoint
    @State private var isPlayingHighlighted = false
    @State private var isPressed = false
    
    let isHighlighted: Bool
    let isEditMode: Bool
    let onDelete: () -> Void
    
    init(item: WordItem, 
         imageSize: CGSize, 
         existingPositions: [CGRect], 
         isHighlighted: Bool = false,
         playViewModel: WordPlayViewModel,
         isEditMode: Bool,
         onDelete: @escaping () -> Void) {
        self.item = item
        self.imageSize = imageSize
        self.existingPositions = existingPositions
        self.isHighlighted = isHighlighted
        self._currentPosition = State(initialValue: item.position)
        self.playViewModel = playViewModel
        self.isEditMode = isEditMode
        self.onDelete = onDelete
        
        print("WordCard initialized - Word: \(item.word)")
        print("  Initial position: \(item.position)")
        print("  Image size: \(imageSize)")
    }
    
    private var cardPosition: CGPoint {
        let basePosition = calculateBasePosition()
        
        // if isPlayingHighlighted {
        //     return CGPoint(
        //         x: UIScreen.main.bounds.width / 2,
        //         y: UIScreen.main.bounds.height * 0.2
        //     )
        // }
        
        return basePosition
    }
    
    private func calculateBasePosition() -> CGPoint {
        let screenAspectRatio = UIScreen.main.bounds.height / UIScreen.main.bounds.width
        let imageAspectRatio = imageSize.height / imageSize.width
        
        var displayWidth = UIScreen.main.bounds.width
        var displayHeight = UIScreen.main.bounds.height
        
        if imageAspectRatio > screenAspectRatio {
            displayHeight = UIScreen.main.bounds.height
            displayWidth = displayHeight / imageAspectRatio
        } else {
            displayWidth = UIScreen.main.bounds.width
            displayHeight = displayWidth * imageAspectRatio
        }
        
        let xOffset = (UIScreen.main.bounds.width - displayWidth) / 2
        let yOffset = (UIScreen.main.bounds.height - displayHeight) / 2
        
        let x = xOffset + displayWidth * currentPosition.x + dragOffset.width
        let y = yOffset + displayHeight * currentPosition.y + dragOffset.height
        
        return CGPoint(x: x, y: y)
    }
    
    var isCurrentlyPlaying: Bool {
        guard !playViewModel.words.isEmpty,
              playViewModel.currentWordIndex < playViewModel.words.count 
        else {
            return false
        }
        return (isHighlighted && item.word == playViewModel.words[playViewModel.currentWordIndex].word) || isPressed
    }
    
    private var cardHighlightColor: Color {
        if isCurrentlyPlaying || isPressed {
            return .orange
        }
        return .yellow.opacity(0.9)
    }
    
    private var cardScale: CGFloat {
        if isCurrentlyPlaying || isPressed || isDragging {
            return 1.05
        }
        return 1.0
    }
    
    private var shadowRadius: CGFloat {
        if isCurrentlyPlaying || isPressed || isDragging {
            return 10
        }
        return 5
    }
    
    private var shadowOpacity: Double {
        if isCurrentlyPlaying || isPressed || isDragging {
            return 0.3
        }
        return 0.15
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !isDragging && !isPlayingHighlighted {
                    Path { path in
                        let startX = item.position.x * geometry.size.width
                        let startY = item.position.y * geometry.size.height
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: cardPosition)
                    }
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                }
                
                VStack(spacing: 6) {
                    Text(item.word)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(item.phoneticsymbols)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
                    
                    Text(item.explanation)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardHighlightColor)
                        .shadow(
                            color: Color.black.opacity(shadowOpacity),
                            radius: shadowRadius,
                            x: 0,
                            y: 2
                        )
                )
                .overlay(
                    Group {
                        if isEditMode {
                            Button(action: onDelete) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.white))
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    , alignment: .topTrailing
                )
                .scaleEffect(cardScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentlyPlaying)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            self.cardSize = proxy.size
                        }
                    }
                )
                .position(cardPosition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(isCurrentlyPlaying || isPressed ? 999 : 0)
            .onAppear {
                print("WordCard appeared - Word: \(item.word)")
                print("  Geometry size: \(geometry.size)")
                print("  Current position: \(currentPosition)")
            }
            .gesture(isEditMode ? nil : DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        print("Drag started - Word: \(item.word)")
                        print("  Initial position: \(currentPosition)")
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let screenAspectRatio = UIScreen.main.bounds.height / UIScreen.main.bounds.width
                    let imageAspectRatio = imageSize.height / imageSize.width
                    
                    var displayWidth = UIScreen.main.bounds.width
                    var displayHeight = UIScreen.main.bounds.height
                    
                    if imageAspectRatio > screenAspectRatio {
                        displayHeight = UIScreen.main.bounds.height
                        displayWidth = displayHeight / imageAspectRatio
                    } else {
                        displayWidth = UIScreen.main.bounds.width
                        displayHeight = displayWidth * imageAspectRatio
                    }
                    
                    let xOffset = (UIScreen.main.bounds.width - displayWidth) / 2
                    let yOffset = (UIScreen.main.bounds.height - displayHeight) / 2
                    
                    let currentScreenX = xOffset + (currentPosition.x * displayWidth)
                    let currentScreenY = yOffset + (currentPosition.y * displayHeight)
                    
                    let newScreenX = currentScreenX + value.translation.width
                    let newScreenY = currentScreenY + value.translation.height
                    
                    let newX = (newScreenX - xOffset) / displayWidth
                    let newY = (newScreenY - yOffset) / displayHeight
                    
                    let finalX = max(0.0, min(newX, 1.0))
                    let finalY = max(0.0, min(newY, 1.0))
                    let finalPosition = CGPoint(x: finalX, y: finalY)
                    
                    print("Drag ended - Word: \(item.word)")
                    print("  Final position: \(finalPosition)")
                    print("  Translation: \(value.translation)")
                    
                    dataManager.updateWordPosition(word: item.word, position: finalPosition)
                    
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 100,
                        damping: 10,
                        initialVelocity: 0
                    )) {
                        currentPosition = finalPosition
                        dragOffset = .zero
                        isDragging = false
                    }
                }
            )
            .onChange(of: item.position) { newPosition in
                print("Position changed - Word: \(item.word)")
                print("  Old position: \(currentPosition)")
                print("  New position: \(newPosition)")
                
                if !isDragging {
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 100,
                        damping: 10,
                        initialVelocity: 0
                    )) {
                        currentPosition = newPosition
                    }
                }
            }
            .animation(nil, value: dragOffset)
            .onTapGesture {
                if !isEditMode {
                    AudioService.shared.playWord(item.word)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isPressed = false
                        }
                    }
                }
            }
            .onChange(of: isHighlighted) { newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPlayingHighlighted = newValue
                }
            }
        }
    }
}


