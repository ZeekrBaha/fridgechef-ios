import UIKit

final class RecipesBatchCell: UICollectionViewListCell {
    static let reuseID = "RecipesBatchCell"

    func configure(with batch: RecipeBatch) {
        var content = UIListContentConfiguration.subtitleCell()
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mm a"
        content.text = "\(timeFmt.string(from: batch.createdAt)) · \(batch.recipes.count) recipes"
        content.textProperties.font = Typography.dmSans(16, weight: .medium)
        content.textProperties.color = .ink

        let hasFavorite = batch.recipes.contains(where: \.isFavorite)
        if hasFavorite {
            content.image = UIImage(systemName: "heart.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
            content.imageProperties.tintColor = .terracotta
            content.imageToTextPadding = Spacing.s8
        }

        content.secondaryText = batch.inputIngredients.isEmpty
            ? (batch.source == .user ? "Your recipe" : "")
            : batch.inputIngredients.joined(separator: ", ")
        content.secondaryTextProperties.font = Typography.dmSans(13)
        content.secondaryTextProperties.color = .inkSoft
        contentConfiguration = content

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .paper2
        backgroundConfiguration = bg
    }
}
