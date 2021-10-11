/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller that displays the details of the selected recipe.
*/

import UIKit
import Combine

class RecipeDetailViewController: UIViewController {

    @IBOutlet var recipeTitle: UILabel!
    @IBOutlet var recipeSubtitle: UILabel!
    @IBOutlet var recipeImageView: UIImageView!
    @IBOutlet var recipeIngredients: UITextView!
    @IBOutlet var recipeDirections: UITextView!
    @IBOutlet var favoriteButton: UIBarButtonItem!
    @IBOutlet var contentStackView: UIStackView!

    private var recipeId: Recipe.ID?
    private var recipeDidChangeSubscriber: Cancellable?

    func showDetail(with recipe: Recipe) {
        recipeId = recipe.id
        recipeTitle.text = recipe.title
        recipeSubtitle.text = recipe.subtitle
        recipeImageView.image = recipe.fullImage
        recipeIngredients.attributedText = makeAttributedString(text: recipe.ingredients, paragraphStyle: ingredientsParagraphStyle)
        recipeDirections.attributedText = makeAttributedString(text: recipe.directions, paragraphStyle: directionsParagraphStyle)

        favoriteButton.image = recipe.isFavorite ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        
        contentStackView.alpha = 1.0
    }
    
    func hideDetail(animated: Bool = true) {
        recipeId = nil
        if animated {
            UIViewPropertyAnimator.runningPropertyAnimator(
                withDuration: 0.2,
                delay: 0.0,
                options: .curveEaseIn,
                animations: {
                    self.contentStackView.alpha = 0.0
                },
                completion: nil
            )
        } else {
            contentStackView.alpha = 0.0
        }
    }

    private lazy var ingredientsParagraphStyle: NSParagraphStyle = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.75
        return paragraphStyle
    }()
    
    private lazy var directionsParagraphStyle: NSParagraphStyle = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 12
        return paragraphStyle
    }()

    private func makeAttributedString(text: String, paragraphStyle: NSParagraphStyle) -> NSAttributedString {
        let attributes = [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
            NSAttributedString.Key.foregroundColor: UIColor.label
        ]
        return  NSMutableAttributedString(string: text, attributes: attributes)
    }

    private var recipeSplitViewController: RecipeSplitViewController {
        self.splitViewController as! RecipeSplitViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hideDetail(animated: false)

        recipeDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .recipeDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.recipeId] }
            .sink { [weak self] id in
                guard
                    let recipeId = self?.recipeId,
                    recipeId == id as? Recipe.ID
                else { return }
                if let recipe = dataStore.recipe(with: recipeId) {
                    self?.showDetail(with: recipe)
                }
            }
    }

}

extension RecipeDetailViewController {

    @IBAction func deleteRecipe(_ sender: Any) {
        guard
            let id = recipeSplitViewController.selectedRecipeId,
            let recipe = dataStore.recipe(with: id)
        else { return }
        
        let alert = Alert.confirmDelete(of: recipe) { [weak self] didDelete in
            if didDelete {
                if let selectedRecipeId = self?.recipeSplitViewController.selectedRecipeId,
                   recipe.id == selectedRecipeId {
                    self?.recipeSplitViewController.selectedRecipeId = nil
                }
            }
        }
        
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.barButtonItem = sender as? UIBarButtonItem
        }
        
        present(alert, animated: true, completion: nil)
    }

    @IBAction func toggleIsFavorite(_ sender: Any) {
        guard
            let id = recipeSplitViewController.selectedRecipeId,
            var recipeToUpdate = dataStore.recipe(with: id)
        else { return }
        
        recipeToUpdate.isFavorite.toggle()
        dataStore.update(recipeToUpdate)
        
        // Update the display.
        showDetail(with: recipeToUpdate)
    }
    
}
