import Foundation
import CoreGraphics

struct CardLayoutHelper {
    static func calculateCardPosition(
        for word: WordItem,
        imageSize: CGSize,
        cardSize: CGSize,
        existingPositions: [CGRect]
    ) -> CGPoint {
        let pos = word.position
        let targetX = pos.x * imageSize.width
        let targetY = pos.y * imageSize.height
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        // 确保卡片完全在屏幕内的安全区域
        let safeMargin: CGFloat = 20  // 边缘安全距离
        let minX = cardSize.width/2 + safeMargin
        let maxX = imageSize.width - cardSize.width/2 - safeMargin
        let minY = cardSize.height/2 + safeMargin
        let maxY = imageSize.height - cardSize.height/2 - safeMargin
        
        // 调整初始目标点到安全区域内
        let safeTargetX = min(max(targetX, minX), maxX)
        let safeTargetY = min(max(targetY, minY), maxY)
        let safeTargetPoint = CGPoint(x: safeTargetX, y: safeTargetY)
        
        // 定义搜索方向（螺旋形搜索）
        let searchDirections: [(dx: CGFloat, dy: CGFloat)] = [
            (0, -60),    // 上
            (60, 0),     // 右
            (0, 60),     // 下
            (-60, 0),    // 左
            (40, -40),   // 右上
            (40, 40),    // 右下
            (-40, 40),   // 左下
            (-40, -40),  // 左上
        ]
        
        // 尝试多个位置，直到找到合适的
        for multiplier in 1...3 {  // 最多尝试3圈
            for direction in searchDirections {
                let offset = CGPoint(
                    x: direction.dx * CGFloat(multiplier),
                    y: direction.dy * CGFloat(multiplier)
                )
                
                let candidatePoint = CGPoint(
                    x: safeTargetPoint.x + offset.x,
                    y: safeTargetPoint.y + offset.y
                )
                
                // 确保候选点在安全区域内
                let adjustedPoint = CGPoint(
                    x: min(max(candidatePoint.x, minX), maxX),
                    y: min(max(candidatePoint.y, minY), maxY)
                )
                
                let candidateRect = CGRect(
                    x: adjustedPoint.x - cardSize.width/2,
                    y: adjustedPoint.y - cardSize.height/2,
                    width: cardSize.width,
                    height: cardSize.height
                )
                
                // 检查是否与现有卡片重叠
                if !hasSignificantOverlap(candidateRect, with: existingPositions) {
                    return adjustedPoint
                }
            }
        }
        
        // 如果所有尝试都失败，返回安全的目标点
        return safeTargetPoint
    }
    
    // 检查重叠程度
    private static func hasSignificantOverlap(_ rect: CGRect, with existingRects: [CGRect]) -> Bool {
        for existing in existingRects {
            let intersection = rect.intersection(existing)
            if !intersection.isEmpty {
                // 计算重叠面积占比
                let overlapArea = intersection.width * intersection.height
                let rectArea = rect.width * rect.height
                let overlapRatio = overlapArea / rectArea
                
                // 如果重叠超过25%，认为重叠显著
                if overlapRatio > 0.25 {
                    return true
                }
            }
        }
        return false
    }
} 
