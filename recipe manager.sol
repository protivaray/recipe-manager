// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RecipeManager
 * @dev A decentralized recipe management system on the blockchain
 * @author Recipe DApp Team
 */
contract RecipeManager {
    
    // Recipe structure
    struct Recipe {
        uint256 id;
        string name;
        string ingredients;
        string instructions;
        string category;
        address owner;
        uint256 createdAt;
        bool isPublic;
    }
    
    // State variables
    mapping(uint256 => Recipe) public recipes;
    mapping(address => uint256[]) public userRecipes;
    mapping(string => uint256[]) public categoryRecipes;
    
    uint256 public recipeCounter;
    uint256 public totalRecipes;
    
    // Events
    event RecipeCreated(
        uint256 indexed recipeId,
        string name,
        address indexed owner,
        string category,
        bool isPublic
    );
    
    event RecipeUpdated(
        uint256 indexed recipeId,
        string name,
        address indexed owner
    );
    
    event RecipeVisibilityChanged(
        uint256 indexed recipeId,
        bool isPublic,
        address indexed owner
    );
    
    // Modifiers
    modifier onlyRecipeOwner(uint256 _recipeId) {
        require(recipes[_recipeId].owner == msg.sender, "Not the recipe owner");
        _;
    }
    
    modifier recipeExists(uint256 _recipeId) {
        require(recipes[_recipeId].id != 0, "Recipe does not exist");
        _;
    }
    
    /**
     * @dev Create a new recipe
     * @param _name Recipe name
     * @param _ingredients List of ingredients
     * @param _instructions Cooking instructions
     * @param _category Recipe category (e.g., "Dessert", "Main Course")
     * @param _isPublic Whether the recipe is public or private
     */
    function createRecipe(
        string memory _name,
        string memory _ingredients,
        string memory _instructions,
        string memory _category,
        bool _isPublic
    ) external {
        require(bytes(_name).length > 0, "Recipe name cannot be empty");
        require(bytes(_ingredients).length > 0, "Ingredients cannot be empty");
        require(bytes(_instructions).length > 0, "Instructions cannot be empty");
        
        recipeCounter++;
        totalRecipes++;
        
        Recipe memory newRecipe = Recipe({
            id: recipeCounter,
            name: _name,
            ingredients: _ingredients,
            instructions: _instructions,
            category: _category,
            owner: msg.sender,
            createdAt: block.timestamp,
            isPublic: _isPublic
        });
        
        recipes[recipeCounter] = newRecipe;
        userRecipes[msg.sender].push(recipeCounter);
        categoryRecipes[_category].push(recipeCounter);
        
        emit RecipeCreated(recipeCounter, _name, msg.sender, _category, _isPublic);
    }
    
    /**
     * @dev Update an existing recipe
     * @param _recipeId Recipe ID to update
     * @param _name New recipe name
     * @param _ingredients New ingredients list
     * @param _instructions New cooking instructions
     * @param _category New recipe category
     */
    function updateRecipe(
        uint256 _recipeId,
        string memory _name,
        string memory _ingredients,
        string memory _instructions,
        string memory _category
    ) external onlyRecipeOwner(_recipeId) recipeExists(_recipeId) {
        require(bytes(_name).length > 0, "Recipe name cannot be empty");
        require(bytes(_ingredients).length > 0, "Ingredients cannot be empty");
        require(bytes(_instructions).length > 0, "Instructions cannot be empty");
        
        Recipe storage recipe = recipes[_recipeId];
        
        // Remove from old category if category changed
        if (keccak256(bytes(recipe.category)) != keccak256(bytes(_category))) {
            _removeFromCategory(recipe.category, _recipeId);
            categoryRecipes[_category].push(_recipeId);
        }
        
        recipe.name = _name;
        recipe.ingredients = _ingredients;
        recipe.instructions = _instructions;
        recipe.category = _category;
        
        emit RecipeUpdated(_recipeId, _name, msg.sender);
    }
    
    /**
     * @dev Toggle recipe visibility (public/private)
     * @param _recipeId Recipe ID to toggle
     */
    function toggleRecipeVisibility(uint256 _recipeId) 
        external 
        onlyRecipeOwner(_recipeId) 
        recipeExists(_recipeId) 
    {
        Recipe storage recipe = recipes[_recipeId];
        recipe.isPublic = !recipe.isPublic;
        
        emit RecipeVisibilityChanged(_recipeId, recipe.isPublic, msg.sender);
    }
    
    /**
     * @dev Get recipe details
     * @param _recipeId Recipe ID to retrieve
     * @return id Recipe ID
     * @return name Recipe name
     * @return ingredients Recipe ingredients list
     * @return instructions Cooking instructions
     * @return category Recipe category
     * @return owner Recipe owner address
     * @return createdAt Creation timestamp
     * @return isPublic Visibility status
     */
    function getRecipe(uint256 _recipeId) 
        external 
        view 
        recipeExists(_recipeId)
        returns (
            uint256 id,
            string memory name,
            string memory ingredients,
            string memory instructions,
            string memory category,
            address owner,
            uint256 createdAt,
            bool isPublic
        ) 
    {
        Recipe memory recipe = recipes[_recipeId];
        
        // Check if user can access this recipe
        require(
            recipe.isPublic || recipe.owner == msg.sender, 
            "Recipe is private and you are not the owner"
        );
        
        return (
            recipe.id,
            recipe.name,
            recipe.ingredients,
            recipe.instructions,
            recipe.category,
            recipe.owner,
            recipe.createdAt,
            recipe.isPublic
        );
    }
    
    /**
     * @dev Get all recipe IDs owned by a user
     * @param _user User address
     * @return recipeIds Array of recipe IDs owned by the user
     */
    function getUserRecipes(address _user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userRecipes[_user];
    }
    
    /**
     * @dev Get all public recipe IDs in a category
     * @param _category Category name
     * @return publicRecipeIds Array of public recipe IDs in the specified category
     */
    function getRecipesByCategory(string memory _category) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory categoryIds = categoryRecipes[_category];
        uint256[] memory publicIds = new uint256[](categoryIds.length);
        uint256 publicCount = 0;
        
        for (uint256 i = 0; i < categoryIds.length; i++) {
            if (recipes[categoryIds[i]].isPublic) {
                publicIds[publicCount] = categoryIds[i];
                publicCount++;
            }
        }
        
        // Resize array to actual public count
        uint256[] memory result = new uint256[](publicCount);
        for (uint256 j = 0; j < publicCount; j++) {
            result[j] = publicIds[j];
        }
        
        return result;
    }
    
    /**
     * @dev Internal function to remove recipe from category array
     * @param _category Category to remove from
     * @param _recipeId Recipe ID to remove
     */
    function _removeFromCategory(string memory _category, uint256 _recipeId) internal {
        uint256[] storage categoryArray = categoryRecipes[_category];
        for (uint256 i = 0; i < categoryArray.length; i++) {
            if (categoryArray[i] == _recipeId) {
                categoryArray[i] = categoryArray[categoryArray.length - 1];
                categoryArray.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Get contract statistics
     * @return totalRecipeCount Total number of recipes created
     * @return currentCounter Current recipe counter value
     */
    function getContractStats() external view returns (uint256, uint256) {
        return (totalRecipes, recipeCounter);
    }
}
