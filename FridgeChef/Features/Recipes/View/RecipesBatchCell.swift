import UIKit

final class RecipesBatchCell: UICollectionViewListCell {
    static let reuseID = "RecipesBatchCell"

    func configure(with batch: RecipeBatch) {
        var content = UIListContentConfiguration.subtitleCell()
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mm a"
        content.text = "\(timeFmt.string(from: batch.createdAt)) · \(batch.recipes.count) recipes"
        content.textProperties.font = Typography.dmSans(16, weight: .medium)
        content.textProperties.color = .ink
        content.secondaryText = batch.inputIngredients.joined(separator: ", ")
        content.secondaryTextProperties.font = Typography.dmSans(13)
        content.secondaryTextProperties.color = .inkSoft
        contentConfiguration = content

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .paper2
        backgroundConfiguration = bg
    }
}
