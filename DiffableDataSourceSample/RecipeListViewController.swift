/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller that displays a list of recipes.
*/

import UIKit
import Combine

/// - Tag: RecipeListViewController
class RecipeListViewController: UICollectionViewController {
    
    /// - Tag: RecipeListSection
    private enum RecipeListSection: Int {
        case main
    }
    
    /// - Tag: recipeListDataSource
    private var recipeListDataSource: UICollectionViewDiffableDataSource<RecipeListSection, Recipe.ID>!
    private var allRecipesSubscriber: AnyCancellable?
    private var recipeDidChangeSubscriber: Cancellable?
    
    private var recipeSplitViewController: RecipeSplitViewController {
        self.splitViewController as! RecipeSplitViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = false

        configureCollectionView()
        configureDataSource()
        loadRecipeData()
        
        /// - Tag: allRecipesSubscriber
        allRecipesSubscriber = dataStore.$allRecipes
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshRecipeData()
                self?.selectRecipeIfNeeded()
            }
        
        /// - Tag: recipeDidChangeSubscriber
        recipeDidChangeSubscriber = NotificationCenter.default
            .publisher(for: .recipeDidChange)
            .receive(on: RunLoop.main)
            .map { $0.userInfo?[NotificationKeys.recipeId] }
            .sink { [weak self] id in
                guard let recipeId = id as? Recipe.ID else { return }
                self?.recipeDidChange(recipeId)
            }
    }
    
    /// - Tag: recipeDidChange
    private func recipeDidChange(_ recipeId: Recipe.ID) {
        guard recipeListDataSource.indexPath(for: recipeId) != nil else { return }
        
        var snapshot = recipeListDataSource.snapshot()
        snapshot.reconfigureItems([recipeId])
        recipeListDataSource.apply(snapshot, animatingDifferences: true)
    }
    
    func showRecipes() {
        loadRecipeData()
        selectRecipeIfNeeded()
    }
    
    /// - Tag: loadRecipeData
    private func loadRecipeData() {
        guard let recipeIds = recipeSplitViewController.selectedRecipes?.recipeIds() else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<RecipeListSection, Recipe.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recipeIds, toSection: .main)
        recipeListDataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    /// - Tag: refreshRecipeData
    private func refreshRecipeData() {
        guard let recipeIds = recipeSplitViewController.selectedRecipes?.recipeIds() else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<RecipeListSection, Recipe.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(recipeIds, toSection: .main)
        recipeListDataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func selectRecipeIfNeeded() {
        guard let selectedRecipeId = recipeSplitViewController.selectedRecipeId else { return }
        let indexPath = recipeListDataSource.indexPath(for: selectedRecipeId)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
    }
    
}

extension RecipeListViewController {
    
    @IBAction func addRecipe(_ sender: Any) {
        // The focus on this sample is diffable data source. So instead of providing a
        // recipe editor, let's create a hard coded recipe and add it to the data store.
        var recipe = dataStore.newRecipe()
        recipe.title = "Diffable Dumplings"
        recipe.prepTime = 60
        recipe.cookTime = 900
        recipe.servings = "1"
        recipe.ingredients = "A dash of Swift\nA spinkle of data"
        recipe.directions = "Mix the ingredients in a data source. Then add to collection view."
        
        var collections = ["New Recipes"] // Always add new recipes to this collection.
        if let selectedRecipes = recipeSplitViewController.selectedRecipes {
            recipe.isFavorite = selectedRecipes.type == .favorites
            if selectedRecipes.type == .collections {
                if let collectionName = selectedRecipes.collectionName {
                    collections.append(collectionName)
                }
            }
        }
        recipe.collections = collections
        
        let addedRecipe = dataStore.add(recipe)
        recipeSplitViewController.selectedRecipeId = addedRecipe.id
    }
    
    private func delete(_ recipe: Recipe) -> Bool {
        let didDelete = dataStore.delete(recipe)
        if didDelete {
            refreshRecipeData()
            if let selectedRecipeId = recipeSplitViewController.selectedRecipeId,
               recipe.id == selectedRecipeId {
                recipeSplitViewController.selectedRecipeId = nil
            }
        }
        return didDelete
    }
    
    private func toggleIsFavorite(_ recipe: Recipe) -> Bool {
        var recipeToUpdate = recipe
        recipeToUpdate.isFavorite.toggle()
        return dataStore.update(recipeToUpdate) != nil
    }
    
}

extension RecipeListViewController {
    
    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                return self?.trailingSwipeActionsConfiguration(for: indexPath)
            }
            let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
            return section
        }
        
        collectionView.collectionViewLayout = layout
    }
    
    private func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let recipeId = recipeListDataSource.itemIdentifier(for: indexPath),
              let recipe = dataStore.recipe(with: recipeId)
        else { return nil }
        
        let configuration = UISwipeActionsConfiguration(actions: [
            deleteContextualAction(recipe: recipe),
            favoriteContextualAction(recipe: recipe)
        ])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    private func deleteContextualAction(recipe: Recipe) -> UIContextualAction {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            completionHandler(self.delete(recipe))
        }
        deleteAction.image = UIImage(systemName: "trash")
        return deleteAction
    }

    private func favoriteContextualAction(recipe: Recipe) -> UIContextualAction {
        let title = recipe.isFavorite ? "Remove from Favorites" : "Add to Favorites"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            completionHandler(self.toggleIsFavorite(recipe))
        }
        let name = recipe.isFavorite ? "heart" : "heart.fill"
        action.image = UIImage(systemName: name)
        return action
    }

}

extension RecipeListViewController {
    
    /// - Tag: configureDataSource
    ///
    private func configureDataSource() {
        
        let recipeCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Recipe> { cell, indexPath, recipe in
            var contentConfiguration = UIListContentConfiguration.subtitleCell()
            contentConfiguration.text = recipe.title
            contentConfiguration.secondaryText = recipe.subtitle
            contentConfiguration.image = recipe.smallImage
            contentConfiguration.imageProperties.cornerRadius = 4
            contentConfiguration.imageProperties.maximumSize = CGSize(width: 60, height: 60)
            
            cell.contentConfiguration = contentConfiguration
            
            if recipe.isFavorite {
                let image = UIImage(systemName: "heart.fill")
                let accessoryConfiguration = UICellAccessory.CustomViewConfiguration(customView: UIImageView(image: image),
                                                                                     placement: .trailing(displayed: .always),
                                                                                     tintColor: .secondaryLabel)
                cell.accessories = [.customView(configuration: accessoryConfiguration)]
            } else {
                cell.accessories = []
            }
        }
        
        recipeListDataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            collectionView, indexPath, identifier -> UICollectionViewCell in

            let recipe = dataStore.recipe(with: identifier)!
            return collectionView.dequeueConfiguredReusableCell(using: recipeCellRegistration, for: indexPath, item: recipe)
        }
    }
    
}

extension RecipeListViewController {
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let recipeId = recipeListDataSource.itemIdentifier(for: indexPath) {
            recipeSplitViewController.selectedRecipeId = recipeId
        }
    }
    
}
