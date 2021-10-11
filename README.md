# Updating Collection Views Using Diffable Data Sources

Streamline the display and update of data in a collection view using a diffable data source that contains identifiers.

## Overview

A *collection view* presents data in the form of sections and items, and an app that displays data in a collection view inserts those sections and items into the view. The app may also need to handle deleting or moving sections and items. For instance, the sample app in this project displays recipes in a collection view, and people using the app can add and delete recipes, and mark recipes as favorites. To support these actions, the sample app handles inserting, deleting, moving, and updating data within a collection view.

When populating a collection view in an app, you can create a custom data source that adopts the [`UICollectionViewDataSource`](https://developer.apple.com/documentation/uikit/uicollectionviewdatasource) protocol. To keep the information in the collection view current, you determine what data changed and perform a batch update based on those changes, a process that requires careful coordination of inserts, deletes, and moves.

To avoid the complexity of that process, the sample app uses a [`UICollectionViewDiffableDataSource`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource) object. A *diffable data source* stores a list of section and item *identifiers*, which represents the identity of each section and item contained in a collection view. These identifiers are stable, meaning they don't change. In contrast, a custom data source that conforms to [`UICollectionViewDataSource`](https://developer.apple.com/documentation/uikit/uicollectionviewdatasource) uses *indices* and *index paths*, which aren't stable. They represent the location of sections and items, which can change as the data source adds, removes, and rearranges the contents of a collection view. However, with identifiers a diffable data source can refer to a section or item without knowledge of its location within a collection view. 

- Note: This sample uses collection views to display data, but the concepts covered in this sample apply to table views as well. For more information about using a diffable data source with a table view, see [`UITableViewDiffableDataSource`](https://developer.apple.com/documentation/uikit/uitableviewdiffabledatasource).

To use a value as an identifier, its data type must conform to the [`Hashable`](https://developer.apple.com/documentation/swift/hashable) protocol. Hashing allows data collections such as [`Set`](https://developer.apple.com/documentation/swift/set), [`Dictionary`](https://developer.apple.com/documentation/swift/dictionary), and snapshots---instances of [`NSDiffableDataSourceSnapshot`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot) and [`NSDiffableDataSourceSectionSnapshot`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesectionsnapshot)---to use values as keys, providing quick and efficient lookups. Hashable types also conform to the [`Equatable`](https://developer.apple.com/documentation/swift/equatable) protocol, so your identifiers must properly implement equality. For more information, see [`Equatable`](https://developer.apple.com/documentation/swift/equatable)`.`

Because identifiers are hashable and equatable, a diffable data source can determine the differences between its current snapshot and another snapshot. Then it can insert, delete, and move sections and items within a collection view for you based on those differences, eliminating the need for custom code that performs batch updates.

- Important: Two identifiers that are equal must always have the same hash value. However, the converse isn't true; two values with the same hash value aren't required to be equal. This situation is called a *hash collision*. For maximal efficiency, try to ensure that unequal identifiers have different hash values. The occasional hash collision is okay when it's unavoidable, but keep the number of collisions to a minimum. Otherwise, the performance of lookups in the data collection may suffer.

## Define the Diffable Data Source

In this sample project, [`RecipeListViewController`](x-source-tag://RecipeListViewController) displays a list of recipes in a collection view. Before the controller can display the recipes, it defines an instance variable to store a diffable data source.

``` swift
private var recipeListDataSource: UICollectionViewDiffableDataSource<RecipeListSection, Recipe.ID>!
```

[View in Source](x-source-tag://recipeListDataSource)

`RecipeListViewController` declares `recipeListDataSource` with `RecipeListSection` as the section identifier type, and `Recipe.ID` as the item identifier type. These identifier types tell the data source the type of values it contains.

For the section identifier type, `recipeListDataSource` uses [`RecipeListSection`](x-source-tag://RecipeListSection), an enumeration with a raw value of type [`Int`](https://developer.apple.com/documentation/swift/int) (in Swift, `Int` is hashable). Each enumeration case identifies a section of the collection view. In the sample, there's only one section, `main`, which displays a list of recipes.

``` swift
private enum RecipeListSection: Int {
    case main
}
```

[View in Source](x-source-tag://RecipeListSection)

For the item identifier type, `recipeListDataSource` uses `Recipe.ID`. This type comes from the [`Recipe`](x-source-tag://Recipe) structure, defined as:

``` swift
struct Recipe: Identifiable, Codable {
    var id: Int
    var title: String
    var prepTime: Int   // In seconds.
    var cookTime: Int   // In seconds.
    var servings: String
    var ingredients: String
    var directions: String
    var isFavorite: Bool
    var collections: [String]
    fileprivate var addedOn: Date? = Date()
    fileprivate var imageNames: [String]
}
```

[View in Source](x-source-tag://Recipe)

This structure conforms to the [`Identifiable`](https://developer.apple.com/documentation/swift/identifiable) protocol, which requires the structure to include an [`id`](https://developer.apple.com/documentation/swift/identifiable/3285392-id) property. By conforming to `Identifiable`, the `Recipe` structure automatically exposes the associated type [`ID`](https://developer.apple.com/documentation/swift/identifiable/3285390-id), which is a type determined based on the declaration of the `id` property in the structure. And because this type must be hashable, the sample app can use `Recipe.ID` as the item identifier type.

- Note: The `Recipe` structure doesn't conform to the `Hashable` protocol. The structure doesn't have to be hashable because the items stored in the diffable data source and the snapshots are recipe *identifiers* (`Recipe.ID` values the backing data store provides for each recipe), not complete recipe structures. 

Using the `Recipe.ID` as the item identifier type for the `recipeListDataSource` means that the data source, and any snapshots applied to it, contains only `Recipe.ID` values and not the complete recipe data. This approach optimizes the diffable data source for peak performance when displaying recipes in a collection view because the identifier type is a simple, hashable type.

## Configure the Diffable Data Source

Before populating a collection view with data from a diffable data source, the sample app configures the data source. The app creates an instance of [`UICollectionViewDiffableDataSource`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource) and sets its *cell provider*, a closure that configures and returns a cell for the collection view.

`RecipeListViewController` configures `recipeListDataSource` in a helper method named `configureDataSource()`. The view controller calls this method in its [`viewDidLoad()`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621495-viewdidload) method.

The `configureDataSource()` method creates a cell registration and provides a handler closure that configures each cell with data from a recipe. The closure receives an instance of `Recipe`, which it uses to configure the cell.

- Note: The item type for a cell registration doesn't have to match the item identifier type that the diffable data source uses.

Next, [`configureDataSource()`](x-source-tag://configureDataSource) creates an instance of [`UICollectionViewDiffableDataSource`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource) and defines the cell provider closure. The closure receives the identifier of a recipe. It then retrieves the recipe from the backing data store (using the identifier) and passes the recipe structure to the cell registration's handler closure.

``` swift
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
```

[View in Source](x-source-tag://configureDataSource)

## Load the Diffable Data Source with Identifiers

With the diffable data source configured, the sample app performs an initial load of data into the data source, which in turn populates a collection view with recipes. `RecipeListViewController` calls its helper method [`loadRecipeData()`](x-source-tag://loadRecipeData). 

This method retrieves a list of recipe identifiers and creates an instance of  [`NSDiffableDataSourceSnapshot`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot). Then it adds the `main` section and recipe identifiers to the snapshot. Lastly, the method calls [`applySnapshotUsingReloadData(_:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource/3804469-applysnapshotusingreloaddata) to apply the snapshot to the data source, resetting the collection view to reflect the state of the data in the snapshot without computing a diff or animating the changes.

``` swift
private func loadRecipeData() {
    guard let recipeIds = recipeSplitViewController.selectedRecipes?.recipeIds() else { return }
    
    var snapshot = NSDiffableDataSourceSnapshot<RecipeListSection, Recipe.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(recipeIds, toSection: .main)
    recipeListDataSource.applySnapshotUsingReloadData(snapshot)
}
```

[View in Source](x-source-tag://loadRecipeData)

- Important: Each item identifier must be unique within a snapshot. As a result, an item identifier can't appear in multiple locations within a snapshot. The same is true of section identifiers; they must be unique and can't exist in multiple places within a snapshot.

## Insert, Delete, and Move Items

People using the sample app can make two types of changes to the recipe data:

* Changes to the collection of data itself, like adding or removing recipes, or reordering them.
* Changes to the properties of existing items, like changing the name of a recipe or marking one as a favorite.

To handle changes to a data collection, the app creates a new snapshot that represents the current state of the data collection and applies it to the diffable data source. The data source compares its current snapshot with the new snapshot to determine the changes. Then it performs the necessary inserts, deletes, and moves into the collection view based on those changes.

While a diffable data source can determine the changes between its current snapshot and a new one, it doesn't monitor the data collection for changes. Instead, it's the responsibility of the app to detect data changes and tell the diffable data source about those changes, by applying a new snapshot.

To tell the sample app that the list of recipes changed---for instance, after someone adds or removes a recipe---the recipes data store includes the [`Published`](https://developer.apple.com/documentation/combine/published) property wrapper attribute on its [`allRecipes`](x-source-tag://DataStore) property. When `allRecipes` changes as the result of a recipe addition or deletion, its publisher sends a message to a subscriber. 

``` swift
@Published var allRecipes: [Recipe]
```

[View in Source](x-source-tag://DataStore)

To detect changes in `allRecipes`, `RecipeListViewController` creates a subscriber to the `allRecipes` publisher. Upon receiving a message from the publisher, the subscriber calls the helper method `refreshRecipeData()`, then updates the selected recipe if needed.

``` swift
allRecipesSubscriber = dataStore.$allRecipes
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in
        self?.refreshRecipeData()
        self?.selectRecipeIfNeeded()
    }
```

[View in Source](x-source-tag://allRecipesSubscriber)

The implementation of [`refreshRecipeData()`](x-source-tag://refreshRecipeData) is the same as `loadRecipeData()` except that it calls [`apply(_:animatingDifferences:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource/3795617-apply) instead of [`applySnapshotUsingReloadData(_:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource/3804469-applysnapshotusingreloaddata). 

``` swift
private func refreshRecipeData() {
    guard let recipeIds = recipeSplitViewController.selectedRecipes?.recipeIds() else { return }
    
    var snapshot = NSDiffableDataSourceSnapshot<RecipeListSection, Recipe.ID>()
    snapshot.appendSections([.main])
    snapshot.appendItems(recipeIds, toSection: .main)
    recipeListDataSource.apply(snapshot, animatingDifferences: true)
}
```

[View in Source](x-source-tag://refreshRecipeData)

To reflect the changes that a person makes to the recipe collection, such as adding or removing a recipe, the `refreshRecipeData()` method uses [`apply(_:animatingDifferences:)`](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource/3795617-apply) to perform incremental updates to the collection view instead of entirely resetting the data displayed. And because `animatingDifferences` is `true`, the collection view animates the changes as they appear.

- Note: To see the visual effects as data changes in the sidebar and recipes list, rotate the device to the landscape orientation.

## Update Existing Items

To handle changes to the properties of an existing item, the sample app retrieves the current snapshot from the diffable data source and calls either [`reconfigureItems(_:)`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot/3804468-reconfigureitems) or [`reloadItems(_:)`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot/3375783-reloaditems) on the snapshot. Then the app applies the snapshot to the diffable data source, which updates the display of the specified items.

Again, the app, not the diffable data source, detects the data changes. 

To detect a change to a recipe---for instance, when a person marks a recipe as a favorite---the sample uses [`NotificationCenter`](https://developer.apple.com/documentation/foundation/notificationcenter) to inform other parts of the app about the change. The sample doesn't need to know which properties changed, only that something changed in a recipe, which is why the sample doesn't include the [`Published`](https://developer.apple.com/documentation/combine/published) property wrapper on each property of the `Recipe` structure. Instead, when a recipe changes, the data store sends a [`recipeDidChange`](x-source-tag://NSNotification.Name) notification using a notification center.

``` swift
@discardableResult
func update(_ recipe: Recipe) -> Recipe? {
    var recipeToReturn: Recipe? = nil // Return nil if the recipe doesn't exist.
    if let index = allRecipes.firstIndex(where: { $0.id == recipe.id }) {
        allRecipes[index] = recipe
        recipeToReturn = recipe
        updateCollectionsIfNeeded()
        NotificationCenter.default.post(name: .recipeDidChange, object: self, userInfo: [NotificationKeys.recipeId: recipe.id])
    }
    return recipeToReturn
}
```

[View in Source](x-source-tag://dataStoreUpdate)

To handle the `recipeDidChange` notification, `RecipeListViewController` creates a subscriber to the `recipeDidChange` notification in the [`viewDidLoad()`](https://developer.apple.com/documentation/uikit/uiviewcontroller/1621495-viewdidload) method. The subscriber inspects the message to ensure that the incoming `userInfo` dictionary contains the identifier of the changed recipe. Then it calls the view controller's helper method `recipeDidChange(_:)`.

``` swift
recipeDidChangeSubscriber = NotificationCenter.default
    .publisher(for: .recipeDidChange)
    .receive(on: RunLoop.main)
    .map { $0.userInfo?[NotificationKeys.recipeId] }
    .sink { [weak self] id in
        guard let recipeId = id as? Recipe.ID else { return }
        self?.recipeDidChange(recipeId)
    }
```

[View in Source](x-source-tag://recipeDidChangeSubscriber)

The `recipeDidChange` notification indicates that data for a single recipe changed. Because only one recipe changed, there's no need to update the entire list of recipes shown in the collection view. Instead, the sample only updates the cell that displays the recipe that changed. For instance, when a person marks a recipe as a favorite, an icon of a heart appears beside that recipe. And when the person unmarks the recipe as a favorite, the heart disappears.

To update the cell with the latest recipe data, the [`recipeDidChange(_:)`](x-source-tag://recipeDidChange) method confirms that the diffable data source contains the recipe by using its identifier. Then the method retrieves the current snapshot from the data source and calls [`reconfigureItems(_:)`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot/3804468-reconfigureitems), passing in the recipe identifier. This call tells the data source to update the data displayed in the cell identified by the recipe identifier. Finally, `recipeDidChange(_:)` applies the updated snapshot to the data source.

``` swift
private func recipeDidChange(_ recipeId: Recipe.ID) {
    guard recipeListDataSource.indexPath(for: recipeId) != nil else { return }
    
    var snapshot = recipeListDataSource.snapshot()
    snapshot.reconfigureItems([recipeId])
    recipeListDataSource.apply(snapshot, animatingDifferences: true)
}
```

[View in Source](x-source-tag://recipeDidChange)

The diffable data source compares the updated snapshot to its current snapshot and applies the difference---in this instance, a request to reconfigure the item that displays the recipe that changed. To fulfill the request, the data source invokes its cell provider closure, which retrieves the updated recipe and configures the cell with the latest recipe data. And because `animatingDifferences` is `true` when applying the snapshot, the collection view animates the visual change of the cell by showing or hiding the heart icon.

## Populate Snapshots with Lightweight Data Structures

An alternative approach to storing identifiers involves populating diffable data sources and snapshots with lightweight data structures. While the data structure approach is convenient and can be a good fit in some circumstances---like for quick prototyping, or displaying a collection of static items with properties that don't change---it carries significant limitations and tradeoffs. For instance, the [Hashable](https://developer.apple.com/documentation/swift/hashable) and [Equatable](https://developer.apple.com/documentation/swift/equatable) implementations must incorporate all properties of the structure that can change. Any changes to the data in the structure cause it to no longer be equal to the previous version, which the diffable data source uses to determine what changed when applying a new snapshot.

The sample uses this approach to show items in a sidebar. In [`SidebarViewController`](x-source-tag://SidebarViewController), the custom structure [`SidebarItem`](x-source-tag://SidebarItem) defines the properties of a sidebar item, which are `title` and `type`.

``` swift
private struct SidebarItem: Hashable {
    let title: String
    let type: SidebarItemType
    
    enum SidebarItemType {
        case standard, collection, expandableHeader
    }
}
```

[View in Source](x-source-tag://SidebarItem)

The combination of these properties determine the hashing value for each sidebar item, and because the property values don't change, populating the snapshot with this `SidebarItem` structure instead of identifiers is an acceptable use case.

``` swift
private func createSnapshotOfStandardItems() -> NSDiffableDataSourceSectionSnapshot<SidebarItem> {
    let items = [
        SidebarItem(title: StandardSidebarItem.all.rawValue, type: .standard),
        SidebarItem(title: StandardSidebarItem.favorites.rawValue, type: .standard),
        SidebarItem(title: StandardSidebarItem.recents.rawValue, type: .standard)
    ]
    return createSidebarItemSnapshot(.standardItems, items: items)
}
```

[View in Source](x-source-tag://createSnapshotOfStandardItems)

The downside of this approach is that the diffable data source can no longer track identity. Any time an existing item changes, the diffable data source sees the change as a delete of the old item and an insert of a new item. As a result, the collection view loses important state tied to the item. For instance, a selected item becomes unselected when any property of the item changes because, from the diffable data source's perspective, the app deleted the item and added a new one to take its place.

Also, if `animatingDifferences` is `true` when applying the snapshot, every change requires the process of animating out the old cell and animating in a new cell, which can be detrimental to performance and cause loss of UI state, including animations, within the cell.

Additionally, this strategy precludes using the [`reconfigureItems(_:)`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot/3804468-reconfigureitems) or [`reloadItems(_:)`](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshot/3375783-reloaditems) methods when populating a snapshot with data structures, because those methods require the use of proper identifiers. The only mechanism to update the data for existing items is to apply a new snapshot containing the new data structures, which causes the diffable data source to perform a delete and an insert for each changed item.

Storing data structures directly into diffable data sources and snapshots isn't a robust solution for many real-world use cases because the data source loses the ability to track identity. Only use this approach for simple use cases in which items don't change, like the sidebar items in this sample, or when the identity of an item isn't important. For all other use cases, or when in doubt as to which approach to use, populate diffable data sources and snapshots with proper identifiers.