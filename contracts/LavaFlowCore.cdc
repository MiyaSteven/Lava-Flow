// LavaFlow Contract
// Synopsis
// The adventurers seeking riches are caught in an erupting treasure-filled volcano dungeon, Flodor. 
// Their entrance have been destroyed. They must find a way out while finding as many items and points as possible because they're greedy sons of pigs.

// Gameplay
// Players can set up accounts to hold their NFT's and FT's outside the game
// The account with the deployed LavaFlowCore.cdc contract can mint and transfer Players their own Player NFT
// Any user can create a game and sets a required number of players to start playing
// When a gameboard is created, it mints 100 tiles, 98 can contain Items, Quests or Tile Points and 2 are Empty (starting and ending tiles)
// The gameboard is finished once it owns 100 tiles total with the required start condition of number of players
// Players can send their NFT's to a game once the game is created
// Once the required number of Players have been sent to a game, any user can start the game and run the first turn of player movement
// Any user can run our game one turn at a time
// After 3 turns of player movement have passed, the environmental obstacles (Lava and Lava Bombs) activate
// The Lava moves with the same RNG dice as the players and destroys all tiles along with it's contents as it covers them
// The Lava Bombs hit random tiles determined by the size of the gameboard and only destroys an unprotected player on hit
// As players land on tiles, they are tested through requirements
// If they meet the requirements, they have a random chance to earn Item(s) or Tile Points 
// The Items effect movement, protection from the environmental obstacles or if unused at the end of the game, they will be sent to the owners storage
// The Tile Points earned at the end of the game will be sent to the owners storage and can be converted into Lava Tokens (FT's) 
// When a Player reaches the last tile, they are immediately sent back to the owners storage along with their unused assets accumulated or brought to that game
// If a Player is destroyed from any environmental obstacle, all their assets they earned or brought will be destroyed

// Code architecture
// The original idea was to implement game development's ECS pattern. However, this was eschewed in favor of storing game state directly on the resources themselves.
// Wrong move. Though it was relatively straight forward in the beginning, having to continually access and put back resources to act upon them became very unwieldy.
// OOP does not work here. For future development, it's best to capture the game world state separately, like the ECS pattern, and then modify the resources' attributes.

pub contract LavaFlow {
  /*
   * GAMEBOARD EVENTS
   */
  pub event MintedGame(id: UInt, playersCount: UInt)
  pub event DestroyedGame(id: UInt)
  pub event StartedGame(gameId: UInt)
  pub event EndedGame(gameId: UInt)
  pub event NextGameTurn(gameId: UInt)
  pub event PlayerWonGame(gameId: UInt, playerId: UInt)

  /*
   * PLAYER EVENTS
   */
  pub event MintedPlayer(id id: UInt, name name: String, class class: String, intelligence intelligence: UInt, strength strength: UInt, cunning cunning: UInt)
  pub event DestroyedPlayer(id: UInt)
  pub event PlayerMeltedInLava(id: UInt)
  pub event PlayerHitByBomb(id: UInt)
  pub event NextPlayerTurn(gameId: UInt, playerId: UInt)
  pub event AddedPlayerToGame(gameId: UInt, playerId: UInt)
  pub event MovedPlayerToTile(gameId: UInt, playerId: UInt, tilePosition: UInt)
  pub event PlayerUsedItem(gameId: UInt, playerId: UInt, itemId: UInt)
  pub event PlayerPickedItem(gameId: UInt, playerId: UInt, itemId: UInt)
  pub event PlayerPickedTilePoint(gameId: UInt, playerId: UInt, tilePointId: UInt)
  pub event PlayerPickedTilePoints(gameId: UInt, playerId: UInt, tilePointsId: UInt)
  pub event PlayerStartedQuest(gameId: UInt, playerId: UInt, questId: UInt)
  pub event PlayerCompletedQuest(gameId: UInt, playerId: UInt, questId: UInt)
  pub event PlayerFailedQuest(gameId: UInt, playerId: UInt, questId: UInt)

  /*
   * ITEM EVENTS
   */
  pub event MintedItem(id: UInt, type: UInt, durability: UInt)
  pub event DestroyedItem(id: UInt)

  /*
   * TILE POINT EVENTS
   */
  pub event MintedTilePoint(id: UInt, amount: UInt)
  pub event DestroyedTilePoint(id: UInt)

  /*
   * TILE EVENTS
   */
  pub event MintedTile(id: UInt)
  pub event DestroyedTile(id: UInt)
  pub event AddedItemToTile(tileId: UInt, itemId: UInt)
  pub event AddedQuestToTile(tileId: UInt, questId: UInt)
  pub event AddedTilePointToTile(tileId: UInt, tilePointId: UInt)
  pub event AddedTileToGame(gameId: UInt, tileId: UInt, position: UInt)

  /*
   * QUEST EVENTS
   */
  pub event MintedQuest(id: UInt, name: String, description: String)
  pub event DestroyedQuest(id: UInt)
  pub event QuestRewardedItem(gameId: UInt, playerId: UInt, itemId: UInt, questId: UInt)
  pub event QuestRewardedPoints(gameId: UInt, playerId: UInt, amount: UInt, questId: UInt)

  /*
   * LAVA EVENTS
   */
  pub event MovedLava(gameId: UInt, lastPosition: UInt)
  pub event LavaBombThrown(gameId: UInt, targetTile: UInt)

  /*
   * TRANSFER EVENTS
   */
  pub event TransferredPlayer(gameId: UInt, playerId: UInt)
  pub event TransferredTokens(gameId: UInt, amount: UInt)

  
  /************************************************************************
  * Contract level variables
  *
  * Define all the contract global variables
  *************************************************************************/
  // rng is the contract's random number generator
  access(self) let rng: RNG

  // current gameboardSize 
  access(self) let gameboardSize: Int

  // Turn at which the lava will start flowing
  access(self) let lavaTurnStart: UInt

  // games store all current games
  pub let games: @{UInt: Game}

  // Systems act upon the game world state
  access(self) let turnPhaseSystem: TurnPhaseSystem
  access(self) let playerSystem: PlayerSystem
  access(self) let questSystem: QuestSystem
  access(self) let itemSystem: ItemSystem
  access(self) let movementSystem: MovementSystem
  access(self) let gameSystem: GameSystem

  // RNG constants
  pub let playerMovementRNG: UInt
  pub let playerStatsRNG: UInt
  pub let numberOfRequirementsRNG: UInt
  pub let requirementValueRNG: UInt
  pub let operationTypeRNG: UInt
  pub let itemTypeRNG: UInt
  pub let itemDurabilityRNG: UInt
  pub let tileEventRNG: UInt // dictates the chances that a tile may have or may not have an item, quest, and points
  pub let tileEventTypeRNG: UInt
  pub let numberOfItemsPerTileRNG: UInt // number of new items to generate on a tile
  pub let newTilePointsRNG: UInt // number of new tile points to generate
  pub let lavaBombRNG: UInt // chance that a bomb goes off on a tile
  pub let lavaMovementRNG: UInt
  pub let awardTypeRNG: UInt

  /************************************************************************
  * Contract level functions
  *
  * Define all the public functions 
  *************************************************************************/
 
  // createGame
  // Creates a new game with a number of players
  //
  // Pre-Conditions:
  // We need at least 2 players
  //
  // Parameters: 
  // totalPlayerCount: the number of players in a game
  pub fun createGame(totalPlayerCount: UInt){
    pre {
      totalPlayerCount > UInt(1): "Game need at least 2 players"
    }
    let gameMinter <- self.loadGameMinter()
    gameMinter.mintGame(totalPlayerCount: totalPlayerCount)
    self.saveGameMinter(minter: <- gameMinter)
  }

  // joinGame adds a Player to a gameboard, and stores a reference of their owner's collection for return
  //
  // Parameters: 
  // gameId: id of game to join
  // player: Player to add into the game
  // playerCollectionRef: collection ref to return the Player at the end of the game
  pub fun joinGame(gameId: UInt, player: @Player, playerCollectionRef: &AnyResource{PlayerReceiver}) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to join"
    }

    let game <- LavaFlow.games.remove(key: gameId)!
    if game.isGameStarted {
      panic("game has already started")
    } else if game.totalPlayerCount == UInt(game.playerTurnOrder.length) {
      panic("game is full")
    } 
    LavaFlow.games[gameId] <-! game
    self.gameSystem.addPlayerToGame(gameId: gameId, player: <- player, playerCollectionRef: playerCollectionRef) 
  }

  // startGame starts a game only when it has the required number of players
  // 
  pub fun startGame(gameId: UInt) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to start"
    }
    let game <- LavaFlow.games.remove(key: gameId)!
    if (game.isGameStarted) {
      panic("Game is already started")
    } else if game.totalPlayerCount != UInt(game.playerTurnOrder.length) {
      panic("Not enough players")
    }
    LavaFlow.games[gameId] <-! game
    self.gameSystem.startGame(gameId: gameId)
  }

  // nextTurn cycles through another game turn
  pub fun nextTurn(gameId: UInt) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to play next turn"
    }
    let game <- LavaFlow.games.remove(key: gameId)!
    if (!game.isGameStarted) {
      panic("Game isn't started")
    } else if game.isGameEnded {
      panic("Game has ended")
    }
    LavaFlow.games[gameId] <-! game
    self.gameSystem.nextTurn(gameId: gameId)
  }

  /************************************************************************
  * Entities (resources)
  *
  * Define all the entites used in the LavaFlow game
  *************************************************************************/

  // Player is an individual character that exists in the game world.
  pub resource Player {
    pub let id: UInt
    pub let name: String
    pub let class: String
    pub let intelligence: UInt
    pub let strength: UInt
    pub let cunning: UInt
    pub let equipments: @[Item] // max 5 resources
    pub let tilePoints: @[TilePoint]

    init(id: UInt, name: String, class: String, intelligence: UInt, strength: UInt, cunning: UInt) {
      self.id = id
      self.name = name
      self.class = class
      self.intelligence = intelligence
      self.strength = strength
      self.cunning = cunning
      self.equipments <- []
      self.tilePoints <- []
    }

    access(all) fun addEquipment(item: @Item) {
      self.equipments.append(<- item)
    }

    access(all) fun removeEquipment(position: UInt): @Item{
      return <- self.equipments.remove(at: position)
    }

    access(all) fun acquireTilePoints(tilePoints: @TilePoint) {
      self.tilePoints.append(<- tilePoints)
    }

    access(all) fun removeTilePoints(position: UInt): @TilePoint{
      return <- self.tilePoints.remove(at: position)
    }

    access(all) fun depositEquipment(position: UInt, itemReceiver: &AnyResource{ItemReceiver}) {
      let item <- self.removeEquipment(position: position)
      itemReceiver.deposit(token: <- item)
    }

    // getActiveItem returns a Player's active Item (aka their first Item).
    // The active Item gets triggered after the Player moves.
    //
    access(all) fun getActiveItem(): @Item? {
      if self.equipments.length > 0 {
        var i = 0
        while i < self.equipments.length {
          let item <- self.equipments.remove(at: i)
          if item.type != UInt(0) || item.type != UInt(4) {
            return <-item
          }
          self.equipments.insert(at: i, <-item)
          i = i + 1
        }
        return nil
      } else {
        return nil
      }
    }

    // getLavaSurfboard will check and return a LavaSurfboard if the Player has one.
    // This should only be called on the lava movement phase.
    // 
    access(all) fun getLavaSurfboard(): @Item? {
      if self.equipments.length > 0 {
        var i = 0
        while i < self.equipments.length {
          let item <- self.equipments.remove(at: i)
          // item of type 0 is a LavaSurfboard
          if item.type == UInt(0) {
            return <-item
          }
          self.equipments.insert(at: i, <-item)
          i = i + 1
        }
        return nil
      } else {
        return nil
      }
    }

    // getBombShield will check and return a BombShield if the Player has one.
    // This should only be called on the Throw Bomb phase.
    // 
    access(all) fun getBombShield(): @Item? {
      if self.equipments.length > 0 {
        var i = 0
        while i < self.equipments.length {
          let item <- self.equipments.remove(at: i)
          // item of type 4 is a BombShield
          if item.type == UInt(4) {
            return <-item
          }
          self.equipments.insert(at: i, <-item)
          i = i + 1
        }
        return nil
      } else {
        return nil
      }
    }

    destroy() {
      emit DestroyedPlayer(id: self.id)
      destroy self.equipments
      destroy self.tilePoints
      let playerMinter <- LavaFlow.loadPlayerMinter()
      playerMinter.decreaseSupply()
      LavaFlow.savePlayerMinter(minter: <- playerMinter)
    }
  }

  // Item can either be harmful or beneficial for a Player. It affects a Player's movement.
  pub resource Item {
    pub let id: UInt

    // Item types
    // 1. LavaSurfboard - save a Player if the lava ever reaches them. Move Player +1 ahead of Lava. Durability = 1...3
    // 2. VolcanicBomb - hurts the Player on pickup. Disable movement. Durability = 1. Movement = 0.
    // 3. Jetpack - boosts the Player by a large number of tiles. Durability = 1...3. Move Player +3 ahead. 
    // 4. LavaSmoke - decreases the Player movement. Durability = 1...3. Movement -1.
    pub let type: UInt

    pub var durability: UInt // item usage cap

    init(id: UInt, type: UInt, durability: UInt) {
      self.id = id
      self.type = type
      self.durability = durability
    }

    pub fun decreaseDurability() {
      if self.durability > UInt(0) {
        self.durability = self.durability - UInt(1)
      }
    }

    destroy(){
      emit DestroyedItem(id: self.id)
      let itemMinter <- LavaFlow.loadItemMinter()
      itemMinter.decreaseSupply()
      LavaFlow.saveItemMinter(minter: <- itemMinter)
    }
  }

  // TilePoint can be traded in for Lava Tokens at the end of a game and the player survives with TilePoints.
  // They are acquired throughout the game, picked up on Tiles or received from Quests.
  pub resource TilePoint {
    pub let id: UInt
    pub let amount: UInt

    init(id: UInt, amount: UInt) {
      self.id = id        
      self.amount = amount
    }

    destroy() {
      emit DestroyedTilePoint(id: self.id)
      let tilePointMinter <- LavaFlow.loadTilePointMinter()
      tilePointMinter.decreaseSupply()
      LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)
    }
  }

  // Quest is an event that can be completed by players for rewards.
  pub resource Quest {
    pub let id: UInt
    pub let name: String
    pub let description: String


    // requirements are a set of minimum numerical requirements that a Player must meet to complete a Quest
    // 
    pub let requirements: [QuestRequirement] 

    init(id: UInt, name: String, description: String) {
      self.id = id
      self.name = name
      self.description = description

      // roll for the quest's requirements
      var requirements: [QuestRequirement] = []
      var numberOfRequirements = LavaFlow.rng.runRNG(LavaFlow.numberOfRequirementsRNG) + UInt(1)
      var attributes = ["strength", "intelligence", "cunning"]
      var i = 0
      // quests have a variable number of requirements
      while UInt(i) < numberOfRequirements {
        // 1. roll for value
        let requirementVal = LavaFlow.rng.runRNG(LavaFlow.requirementValueRNG) + UInt(1)

        // 2. roll for attribute
        let selectedAttribute = LavaFlow.rng.runRNG(UInt(attributes.length))
        var attribute = attributes.remove(at: selectedAttribute)

        // 3. roll for operation
        let operationType = LavaFlow.rng.runRNG(LavaFlow.operationTypeRNG)

        requirements.append(QuestRequirement(attribute: attribute, operation: operationType, value: requirementVal))

        i = i + 1
      }

      self.requirements = requirements
    }

    // checkRequirement verifies whether the Quest's requirements have been met
    //
    pub fun checkRequirement(operation: UInt, targetVal: UInt, playerAttributeVal: UInt): Bool {
      if operation == UInt(0) {
        return playerAttributeVal == targetVal

      } else if operation == UInt(1) {
        return playerAttributeVal < targetVal

      } else if operation == UInt(2) {
        return playerAttributeVal <= targetVal

      } else if operation == UInt(3) {
        return playerAttributeVal > targetVal

      } else if operation == UInt(4) { 
        return playerAttributeVal >= targetVal
      }

      return false
    }      

    pub fun awardItem(gameId: UInt, playerId: UInt): @Item {
      let itemMinter <- LavaFlow.loadItemMinter()
      let item <- itemMinter.mintItem()

      emit QuestRewardedItem(gameId: gameId, playerId: playerId, itemId: item.id, questId: self.id)

      LavaFlow.saveItemMinter(minter: <- itemMinter)
      return <- item
    }

    pub fun awardPoints(gameId: UInt, playerId: UInt): @TilePoint {
      let tilePointMinter <- LavaFlow.loadTilePointMinter()
      let points <- tilePointMinter.mintPoints(amount: LavaFlow.rng.runRNG(LavaFlow.newTilePointsRNG))

      emit QuestRewardedPoints(gameId: gameId, playerId: playerId, amount: UInt(points.amount), questId: self.id)

      LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)

      return <- points
    }

    destroy() {
      let questMinter <- LavaFlow.loadQuestMinter()
      questMinter.decreaseSupply()
      LavaFlow.saveQuestMinter(minter: <- questMinter)
    }
  }

  // QuestRequirement represents a single requirement for Quest fulfillment.
  // It dictates what and how that numerical value must be met.
  pub struct QuestRequirement {
    pub let attribute: String // strength, intelligence, cunning
    pub let operation: UInt // <, <=, >, >=, ==
    pub let value: UInt

    init(attribute: String, operation: UInt, value: UInt){
      self.attribute = attribute
      self.operation = operation
      self.value = value
    }
  }

  // Tile represents spaces on the gameboard.
  // It holds LavaFlow entites that move into it.
  pub resource Tile {
    pub let id: UInt
    pub let itemContainer: @[Item]
    pub let questContainer: @[Quest]
    pub let tilePointsContainer: @[TilePoint]
    pub let playerContainer: @[Player]
    pub var lavaCovered: Bool

    init(id: UInt) {
      self.id = id
      self.lavaCovered = false
      self.playerContainer <- []
      self.itemContainer <- []
      self.questContainer <- []
      self.tilePointsContainer <- []
    }

    pub fun addItem(item: @Item) {
      self.itemContainer.append(<-item)
    }

    pub fun removeItem(position: UInt): @Item {
      return <-self.itemContainer.remove(at: position)
    }

    pub fun addQuest(quest: @Quest) {
      self.questContainer.append(<-quest)
    }

    pub fun removeQuest(position: UInt): @Quest {
      return <-self.questContainer.remove(at: position)
    }

    pub fun addTilePoints(tilePoints: @TilePoint) {
      self.tilePointsContainer.append(<-tilePoints)
    }

    pub fun removeTilePoints(position: UInt): @TilePoint {
      return <-self.tilePointsContainer.remove(at: position)
    }

    pub fun addPlayer(player: @Player) {
      self.playerContainer.append(<-player)
    }

    pub fun removePlayer(position: UInt): @Player {
      return <-self.playerContainer.remove(at: position)
    }

    pub fun getPlayer(id: UInt): @LavaFlow.Player {
      pre {
        self.playerContainer.length > 0: "tiles should contain at least 1 player"
      }

      post {
        result != nil: "a player must be returned"
      }

      var i = 0
      var playerPositionInTileContainer = 0

      while i < self.playerContainer.length {
        let player <- self.playerContainer.remove(at: i)
        if player.id == id {
          playerPositionInTileContainer = i
        }
        self.playerContainer.insert(at: i, <- player)
        i = i + 1
      }
      return <- self.playerContainer.remove(at: playerPositionInTileContainer)
    }

    pub fun getItem(id: UInt): @LavaFlow.Item {
      pre {
        self.itemContainer.length > 0: "tiles should contain at least 1 item"
      }

      post {
        result != nil: "a item must be returned"
      }

      var i = 0
      var itemPosition = 0
      while i < self.itemContainer.length {
        let item <- self.itemContainer.remove(at: i)
        if item.id == id {
          itemPosition = i
        }
        self.itemContainer.insert(at: i, <- item)
        i = i + 1
      }
      return <- self.itemContainer.remove(at: itemPosition)
    }

    pub fun getQuest(id: UInt): @LavaFlow.Quest {
      pre {
        self.questContainer.length > 0: "tiles should contain at least 1 quest"
      }

      post {
        result != nil: "a quest must be returned"
      }

      var i = 0
      var questPosition = 0
      while i < self.questContainer.length {
        let quest <- self.questContainer.remove(at: i)
        if quest.id == id {
          questPosition = i
        }
        self.questContainer.insert(at: i, <- quest)
        i = i + 1
      }
      return <- self.questContainer.remove(at: questPosition)
    }

    pub fun getTilePoints(id: UInt): @LavaFlow.TilePoint {
      pre {
        self.tilePointsContainer.length > 0: "tiles should contain at least 1 tile points"
      }

      post {
        result != nil: "a tilepoint must be returned"
      }

      var i = 0
      var tilePointsPosition = 0
      while i < self.tilePointsContainer.length {
        let tilePoints <- self.tilePointsContainer.remove(at: i)
        if tilePoints.id == id {
          tilePointsPosition = i
        }
        self.tilePointsContainer.insert(at: i, <- tilePoints)
        i = i + 1
      }
      return <- self.tilePointsContainer.remove(at: tilePointsPosition)
    }

    // coverWithLava disables a tile with lava
    pub fun coverWithLava() {
      self.lavaCovered = true
    }

    destroy() {
      destroy self.playerContainer
      destroy self.itemContainer
      destroy self.questContainer
      destroy self.tilePointsContainer
      let tileMinter <- LavaFlow.loadTileMinter()
      tileMinter.decreaseSupply()
      LavaFlow.saveTileMinter(minter: <- tileMinter)
    }
  }

  // Game represents a singular game instance.
  pub resource Game {
    pub let id: UInt
    pub let gameboard: @[Tile]

    // totalPlayerCount is the number of players needed to start a game
    pub(set) var totalPlayerCount: UInt

    // turnCount counts how many turns have been played
    pub var turnCount: UInt

    // isGameStarted indicate if a game has started
    pub var isGameStarted: Bool

    // isGameEnded indicates if a game has ended
    pub var isGameEnded: Bool

    // lastLavaPosition tracks the latest position of the lava
    pub(set) var lastLavaPosition: UInt

    // currentPlayerIndex points to the turn's current player
    pub var currentPlayerIndex: UInt

    // playerTilePositions maps player id to tile position
    pub let playerTilePositions: {UInt: UInt}

    // playerTurnOrder is a queue of players that have joined the game
    pub let playerTurnOrder: [UInt]

    // playerReceivers stores the collection receiver of a player's account so we can return the player at the end of a game
    pub let playerReceivers: {UInt: &AnyResource{LavaFlow.PlayerReceiver}}

    init(id: UInt, totalPlayerCount: UInt) {
      self.id = id
      self.totalPlayerCount = totalPlayerCount
      self.gameboard <- []
      self.turnCount = 0
      self.isGameStarted = false
      self.isGameEnded = false
      self.lastLavaPosition = 0
      self.playerTilePositions = {}
      self.currentPlayerIndex = 0
      self.playerTurnOrder = []
      self.playerReceivers = {}
    }

    pub fun startGame() {
      emit StartedGame(gameId: self.id)
      self.isGameStarted = true
    }

    pub fun endGame() {
      emit EndedGame(gameId: self.id)
      self.isGameEnded = true
    }

    pub fun incrementTurnCount() {
      self.turnCount = self.turnCount + UInt(1)
    }

    destroy() {
      destroy self.gameboard
      let gameMinter <- LavaFlow.loadGameMinter()
      gameMinter.decreaseSupply()
      LavaFlow.saveGameMinter(minter: <- gameMinter)
    }
  }

  /************************************************************************
  * Entities Minters
  *
  * Define all the entites minters required to mint new entities
  *************************************************************************/

  pub resource PlayerMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt

    init() {
      self.idCount = UInt(0)
      self.totalSupply = 0
    }

    pub fun mintPlayers(name: String, class: String): @Player {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      
      let randomStat1 = LavaFlow.rng.runRNG(LavaFlow.playerStatsRNG) + UInt(1)
      let randomStat2 = LavaFlow.rng.runRNG(LavaFlow.playerStatsRNG) + UInt(1)
      let randomStat3 = LavaFlow.rng.runRNG(LavaFlow.playerStatsRNG) + UInt(1)
      emit MintedPlayer(id: self.idCount, name: name, class: class, intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
      return <- create Player(id: self.idCount, name: name, class: class, intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createPlayerMinter(): @PlayerMinter {
    return <- create PlayerMinter()
  }

  access(self) fun savePlayerMinter(minter: @PlayerMinter) {
    self.account.save(<- minter, to: /storage/PlayerMinter)
  }

  access(self) fun loadPlayerMinter(): @PlayerMinter {
    return <- self.account.load<@PlayerMinter>(from: /storage/PlayerMinter)!
  }

  pub resource ItemMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt

    init() {
      self.idCount = 0
      self.totalSupply = 0
    }

    pub fun mintItem(): @Item {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      let type = LavaFlow.rng.runRNG(LavaFlow.itemTypeRNG)
      var durability = LavaFlow.rng.runRNG(LavaFlow.itemDurabilityRNG) + UInt(1)
      if type == UInt(1) {
        durability = UInt(1)
      }
      
      emit MintedItem(id: self.idCount, type: type, durability: durability)
      return <- create Item(id: self.idCount, type: type, durability: durability)
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createItemMinter(): @ItemMinter {
    return <- create ItemMinter()
  }

  access(self) fun saveItemMinter(minter: @ItemMinter) {
    self.account.save(<- minter, to: /storage/ItemMinter)
  }

  access(self) fun loadItemMinter(): @ItemMinter {
    return <- self.account.load<@ItemMinter>(from: /storage/ItemMinter)!
  }

  pub resource TilePointMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt
    init() {
      self.idCount = 0
      self.totalSupply = 0
    }

    pub fun mintPoints(amount: UInt): @TilePoint {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      emit MintedTilePoint(id: self.idCount, amount: amount)
      return <- create TilePoint(id: self.idCount, amount: amount)
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createTilePointMinter(): @TilePointMinter {
    return <- create TilePointMinter()
  }

  access(self) fun saveTilePointMinter(minter: @TilePointMinter) {
    self.account.save(<- minter, to: /storage/TilePointMinter)
  }

  access(self) fun loadTilePointMinter(): @TilePointMinter {
    return <- self.account.load<@TilePointMinter>(from: /storage/TilePointMinter)!
  }

  pub resource QuestMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt
    init() {
      self.idCount = 0
      self.totalSupply = 0
    }

    pub fun mintQuest(name: String, description: String): @Quest {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      emit MintedQuest(id: self.idCount, name: name, description: description)
      return <- create Quest(id: self.idCount, name: name, description: description)
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createQuestMinter(): @QuestMinter {
    return <- create QuestMinter()
  }

  access(self) fun saveQuestMinter(minter: @QuestMinter) {
    self.account.save(<- minter, to: /storage/QuestMinter)
  }

  access(self) fun loadQuestMinter(): @QuestMinter {
    return <- self.account.load<@QuestMinter>(from: /storage/QuestMinter)!
  }

  pub resource TileMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt

    init() {
      self.idCount = 0
      self.totalSupply = 0
    }

    pub fun mintTile(): @Tile {
      var newTile <- self.mintEmptyTile()

      // roll for to determine whether an item event occurs (items, quest, ft)
      let shouldEventOccur = LavaFlow.rng.runRNG(LavaFlow.tileEventRNG) > UInt(50)

      // if a tile is allowed to have an event, create a resource to place on the tile
      // determine if the tile should have a quest (40%) | points (40%)| items (20%)
      if shouldEventOccur {
        let eventType = LavaFlow.rng.runRNG(LavaFlow.tileEventTypeRNG)
        if (eventType > UInt(60)) {
          // lay a quest on the tile
          let questMinter <- LavaFlow.loadQuestMinter()
          let quest <- questMinter.mintQuest(name: "Quest", description: "Quest description")

          emit AddedQuestToTile(tileId: newTile.id, questId: quest.id)

          newTile.addQuest(quest: <- quest)
          LavaFlow.saveQuestMinter(minter: <- questMinter)

        } else if (eventType > UInt(20)) {
          // lay some points to the tile
          let tilePointMinter <- LavaFlow.loadTilePointMinter()
          let tilePoints <- tilePointMinter.mintPoints(amount: LavaFlow.rng.runRNG(LavaFlow.newTilePointsRNG))

          emit AddedTilePointToTile(tileId: newTile.id, tilePointId: tilePoints.id)

          newTile.addTilePoints(tilePoints: <- tilePoints)
          LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)

        } else { 
          // lay some items on the tiles
          let numOfItems = LavaFlow.rng.runRNG(LavaFlow.numberOfItemsPerTileRNG) + UInt(1)
          var i = 0
          while UInt(i) < numOfItems {
            let itemMinter <- LavaFlow.loadItemMinter()
            let item <- itemMinter.mintItem()
            emit AddedItemToTile(tileId: newTile.id, itemId: item.id)
            newTile.addItem(item: <- item)
            LavaFlow.saveItemMinter(minter: <- itemMinter)
            i = i + 1
          }
        }
      }

      return <- newTile
    }

    pub fun mintEmptyTile(): @Tile {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      emit MintedTile(id: self.idCount)
      return <- create Tile(id: self.idCount)
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createTileMinter(): @TileMinter {
    return <- create TileMinter()
  }

  access(self) fun saveTileMinter(minter: @TileMinter) {
    self.account.save(<- minter, to: /storage/TileMinter)
  }

  access(self) fun loadTileMinter(): @TileMinter {
    return <- self.account.load<@TileMinter>(from: /storage/TileMinter)!
  }

  pub resource GameMinter {
    pub var idCount: UInt
    pub var currentGames: UInt
    pub var totalSupply: UInt

    init() {
      self.idCount = 0
      self.currentGames = 0
      self.totalSupply = 0
    }

    pub fun mintGame(totalPlayerCount: UInt) {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      self.currentGames = self.currentGames + UInt(1)

      let game <- create Game(id: self.idCount, totalPlayerCount: totalPlayerCount)
      emit MintedGame(id: game.id, playersCount: totalPlayerCount)

      // create tiles for the game
      let tileMinter <- LavaFlow.loadTileMinter()
      let startTile <- tileMinter.mintEmptyTile()
      emit AddedTileToGame(gameId: game.id, tileId: startTile.id, position: 0)
      game.gameboard.append(<- startTile)

      // add the tiles to the game
      var i = 0
      while i < LavaFlow.gameboardSize - 2 {
        let tile <- tileMinter.mintTile()
        emit AddedTileToGame(gameId: game.id, tileId: tile.id, position: UInt(i + 1))
        game.gameboard.append(<- tile)
        i = i + 1
      }

      // add an empty tile at the last gameboard position to prevent an event trigger
      let endTile <- tileMinter.mintEmptyTile()
      emit AddedTileToGame(gameId: game.id, tileId: endTile.id, position: 100)
      game.gameboard.append(<- endTile)

      LavaFlow.saveTileMinter(minter: <- tileMinter)

      LavaFlow.games[game.id] <-! game
    }

    access(contract) fun decreaseSupply() {
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createGameMinter(): @GameMinter{
    return <- create GameMinter()
  }

  access(self) fun saveGameMinter(minter: @GameMinter){
    self.account.save(<- minter, to: /storage/GameMinter)
  }

  access(self) fun loadGameMinter(): @GameMinter{
    return <- self.account.load<@GameMinter>(from: /storage/GameMinter)!
  }

  /************************************************************************
  * Entities Receivers
  *
  * Define all the entites receivers required to receive resources
  *************************************************************************/

  access(all) resource interface PlayerReceiver {
    access(all) fun deposit(token: @Player)
    access(all) fun getIDs(): [UInt]
    access(all) fun idExists(id: UInt): Bool
  }

  access(all) resource PlayersCollection: PlayerReceiver {
    access(all) var players: @{UInt: Player}

    init(){
      self.players <- {}
    }

    access(all) fun withdraw(id: UInt): @Player {
      let token <- self.players.remove(key: id) ?? panic("missing Player")
      return <-token
    }

    access(all) fun deposit(token: @Player) {
      let oldToken <- self.players[token.id] <- token
      destroy oldToken
    }

    access(all) fun idExists(id: UInt): Bool {
      return self.players[id] != nil
    }

    access(all) fun getIDs(): [UInt] {
      return self.players.keys
    }

    destroy() {
      destroy self.players
    }
  }

  pub fun createEmptyPlayerCollection(): @PlayersCollection {
    return <- create PlayersCollection()
  }

  access(all) resource interface ItemReceiver {
    access(all) fun deposit(token: @Item)
    access(all) fun getIDs(): [UInt]
    access(all) fun idExists(id: UInt): Bool
  }

  access(all) resource ItemsCollection: ItemReceiver {
    access(all) var items: @{UInt: Item}

    init(){
      self.items <- {}
    }

    access(all) fun withdraw(id: UInt): @Item {
      let token <- self.items.remove(key: id) ?? panic("missing Item")
      return <-token
    }

    access(all) fun deposit(token: @Item) {
      let oldToken <- self.items[token.id] <- token
      destroy oldToken
    }

    access(all) fun idExists(id: UInt): Bool {
      return self.items[id] != nil
    }

    access(all) fun getIDs(): [UInt] {
      return self.items.keys
    }

    destroy() {
      destroy self.items
    }
  }

  pub fun createEmptyItemCollection(): @ItemsCollection {
    return <- create ItemsCollection()
  }

  /************************************************************************
  * SYSTEMS
  *
  * Handles state changes in the game world
  *************************************************************************/

  // GameSystem handles all the general logic around interacting with a Game resource
  pub struct GameSystem {

    // startGame
    // Starts a game and plays the first turn
    //
    // Pre-conditions: 
    // Game should not be started
    //
    // Parameters: gameId: the game Id
    access(contract) fun startGame(gameId: UInt) {
      var game <- LavaFlow.games.remove(key: gameId)!
      if !game.isGameStarted {
        game.startGame()
        LavaFlow.games[gameId] <-! game
        self.nextTurn(gameId: gameId)
      } else {
        LavaFlow.games[gameId] <-! game
      }
    }

    // addPlayerToGame
    // Add a player to a game
    //
    // Pre conditions:
    // Game shouldn't be started
    // Game haven't reached total players
    //
    // Parameters: 
    // gameId: Game Id
    // player: The player resource to add to the game
    // playerCollectionRef: The reference to the player collection to send back the player if he survives
    access(contract) fun addPlayerToGame(gameId: UInt, player: @Player, playerCollectionRef: &AnyResource{PlayerReceiver}) {
      let game <- LavaFlow.games.remove(key: gameId)!

      if !game.isGameStarted && UInt(game.playerTurnOrder.length) < game.totalPlayerCount {
        // save a reference to the owner's PlayerReceiver to return the player at the end of the game
        game.playerReceivers[player.id] = playerCollectionRef

        // set the player's turn 
        game.playerTurnOrder.append(player.id)

        // store the player's tile position as state
        game.playerTilePositions[player.id] = 0
        emit AddedPlayerToGame(gameId: game.id, playerId: player.id)

        // move the player onto the first game tile
        let firstTile <- game.gameboard.remove(at: 0)
        firstTile.playerContainer.append(<- player)
        game.gameboard.insert(at: 0, <- firstTile)  
      }

      LavaFlow.games[gameId] <-! game
    }
    
    // nextTurn plays the next turn of the game
    //
    // Pre conditions:
    // Game should have been started
    // Game shouldn't be ended
    //
    // Parameters: 
    // gameId: Game Id
    access(contract) fun nextTurn(gameId: UInt){
      var game <- LavaFlow.games.remove(key: gameId)!
      game.incrementTurnCount()
      if game.isGameEnded || !game.isGameStarted {
        LavaFlow.games[gameId] <-! game
        return
      }
      
      LavaFlow.games[gameId] <-! game
      emit NextGameTurn(gameId: gameId)
      
      // 1. players roll for new positions
      LavaFlow.movementSystem.movePlayers(gameId: gameId)      

      // 2 check if any players have reached the last tile
      self.lastTilePlayers(gameId: gameId)
      
      // 3. run lava roll
      LavaFlow.movementSystem.moveLava(gameId: gameId)

      // 4. destroy the players trapped inside the lava
      LavaFlow.playerSystem.destroyPlayersInLava(gameId: gameId)

      // 5. run throw volcano bomb & destroy players hit by a volcano bomb
      LavaFlow.movementSystem.throwBombAndDestroy(gameId: gameId)

    }

    // lastTilePlayers sebds back the winning players
    //
    access(contract) fun lastTilePlayers(gameId: UInt){
      var game <- LavaFlow.games.remove(key: gameId)!

      // get the ids of players who have reached the last game tile
      var i = UInt(0)
      var lastTilePlayersIds: [UInt] = []
      for position in game.playerTilePositions.values {
        if(position == UInt(game.gameboard.length - 1)) {
          // player in last tile
          lastTilePlayersIds.append(game.playerTilePositions.keys[i])
        }
        i = i + UInt(1)
      }

      // return the players back to their owners
      for playerId in lastTilePlayersIds {
        // to get the player, we check the tile the players last reached (the last game tile)
        let lastTile <- game.gameboard.remove(at: game.gameboard.length - 1)
        let player <- lastTile.getPlayer(id: playerId)
        game.gameboard.append(<- lastTile)

        // return the player
        game.playerReceivers[playerId]!.deposit(token: <- player)
        emit PlayerWonGame(gameId: gameId, playerId: playerId)

        // clean the player's game state
        var j = 0
        while j < game.playerTurnOrder.length {
          if game.playerTurnOrder[j] == playerId {
            game.playerTurnOrder.remove(at: j)
          }
          j = j + 1
        }
        game.playerReceivers.remove(key: playerId)
        game.totalPlayerCount = game.totalPlayerCount - UInt(1)
        game.playerTilePositions.remove(key: playerId)
      }
      
      // end the game if there are no players left
      if game.playerTurnOrder.length == 0 {
        game.endGame()
        LavaFlow.games[gameId] <-! game
        return
      }
      
      LavaFlow.games[gameId] <-! game
    }
  }
  
  // TurnPhaseSystem handles all work around player movement and player turn rotation.
  pub struct TurnPhaseSystem {}

  // PlayerSystem manages character state, namely attributes and effects
  pub struct PlayerSystem {
    
    // destroyPlayersInLava destroys all players that happen to be on a tile covered with lava
    //
    access(contract) fun destroyPlayersInLava(gameId: UInt) {
      // get a copy of the game's player positions and the last lava position to validate whether they should be destroyed
      let game <- LavaFlow.games.remove(key: gameId)!
      let playerTilePositionKeys = game.playerTilePositions.keys
      let lastLavaPosition = game.lastLavaPosition
      LavaFlow.games[gameId] <-! game 
      
      // iterate through all the player's current tile positions
      var i = 0
      for playerId in playerTilePositionKeys {
        // get the player's current position 
        let game <- LavaFlow.games.remove(key: gameId)!
        let playerPosition = game.playerTilePositions[playerId]!
        LavaFlow.games[gameId] <-! game 

        // if the player is in lava, destroy the player
        // however, if the player has a surfboard, they are moved ahead of the lava by a space
        if playerPosition <= lastLavaPosition {
          // get the damn player. here lies the maddening need to constantly pull out and put back resources because some other function
          // needs to interact with the game resource.
          let game <- LavaFlow.games.remove(key: gameId)!
          let tile <- game.gameboard.remove(at: playerPosition)
          let player <- tile.getPlayer(id: playerId)
          LavaFlow.games[gameId] <-! game

          // save the player from the lava if they have a surfboard
          let surfboard <- player.getLavaSurfboard()
          if surfboard == nil {
            log("Player doesn't have a surfboard")
            emit PlayerMeltedInLava(id: playerId)
            // kill the player because they're dumb (and unlucky) and don't have a surfboard
            let game <- LavaFlow.games.remove(key: gameId)!
            destroy player
            game.gameboard.insert(at: playerPosition, <- tile)

            // clean up player data from game world
            var j = 0
            while j < game.playerTurnOrder.length {
              if game.playerTurnOrder[j] == playerId {
                game.playerTurnOrder.remove(at: j)
              }
              j = j + 1
            }
            game.playerReceivers.remove(key: playerId)
            game.totalPlayerCount = game.totalPlayerCount - UInt(1)
            game.playerTilePositions.remove(key: playerId)
            LavaFlow.games[gameId] <-! game
            
          } else {
            log("Player has a surfboard")

            let game <- LavaFlow.games.remove(key: gameId)!

            emit PlayerUsedItem(gameId: gameId, playerId: playerId, itemId: surfboard?.id!)

            surfboard?.decreaseDurability()
            if surfboard?.durability == UInt(0) {
              destroy surfboard
            } else {
              player.equipments.insert(at: 0, <- surfboard!)    
            }

            tile.playerContainer.append(<- player)
            game.gameboard.insert(at: playerPosition, <- tile)
            LavaFlow.games[gameId] <-! game

            // the surfboard saves the player by moving them on step ahead of the lava
            LavaFlow.movementSystem.movePlayer(gameId: gameId, playerId: playerId, tilePosition: lastLavaPosition + UInt(1))
          }
        }
        i = i + 1
      }
    }
  }

  // MovementSystem manages player and lava movements
  pub struct MovementSystem {

    // movePlayers moves all players in the game
    //
    access(contract) fun movePlayers(gameId: UInt) {
      // get a copy of playerTurnOrder and put the game back because `movePlayer` needs access to the game resource
      let game <- LavaFlow.games.remove(key: gameId)!
      let playerTurnOrder = game.playerTurnOrder
      LavaFlow.games[gameId] <-! game
      
      // for each player, compute their new position and move them to the tile at position
      for playerId in playerTurnOrder {
        let game <- LavaFlow.games.remove(key: gameId)!
        let movementForward = LavaFlow.rng.runRNG(LavaFlow.playerMovementRNG) + UInt(1)
        var newTilePosition = game.playerTilePositions[playerId]! + UInt(movementForward)

        // ensure player ends on the last tile if they over-roll
        if newTilePosition >= UInt(game.gameboard.length) {
          newTilePosition = UInt(game.gameboard.length - 1)
        }

        emit NextPlayerTurn(gameId: game.id, playerId: playerId)

        LavaFlow.games[gameId] <-! game
        LavaFlow.movementSystem.movePlayer(gameId: gameId, playerId: playerId, tilePosition: newTilePosition)
      }
    }

    // movePlayer moves a player to a specified tile
    //
    // Parameters: 
    // gameId: Game Id
    // playerId: The id of the player to move
    // tilePosition: The next player position
    access(contract) fun movePlayer(gameId: UInt, playerId: UInt, tilePosition: UInt) {
      let game <- LavaFlow.games.remove(key: gameId)!

      // get the tile the player is on
      let currentTilePosition = game.playerTilePositions[playerId]!
      let currentTile <- game.gameboard.remove(at: currentTilePosition)

      // player is guaranteed to exist in the tile because we store and read the current player positions 
      let player <- currentTile.getPlayer(id: playerId)

      // put back the tile
      game.gameboard.insert(at: currentTilePosition, <- currentTile)

      // triggering their active item and compute the player's new position
      var postItemEffectTilePosition = tilePosition

      // get their active non-surfboard item and trigger their affects accordingly
      let activeItem <- player.getActiveItem()
      if activeItem != nil {

        // 1. VolcanicBomb - hurts the Player on pickup. Disable movement. Durability = 1. Movement = 0.
        if activeItem?.type == UInt(1) {
          postItemEffectTilePosition = currentTilePosition

        // 2. Jetpack - boosts the Player by a large number of tiles. Durability = 1...3. Move Player +2 ahead. 
        } else if activeItem?.type == UInt(2) {
          postItemEffectTilePosition = postItemEffectTilePosition + UInt(2)

        // 3. Slime - decreases the Player movement. Durability = 1...3. Movement -1.
        } else if activeItem?.type == UInt(3) {
          postItemEffectTilePosition = postItemEffectTilePosition - UInt(1)
        }

        emit PlayerUsedItem(gameId: gameId, playerId: playerId, itemId: activeItem?.id!)

        activeItem?.decreaseDurability()
        if activeItem?.durability == UInt(0) {
          destroy activeItem
        } else {
          player.equipments.insert(at: 0, <- activeItem!)    
        }
      }

      // get the destination tile given tile id
      emit MovedPlayerToTile(gameId: gameId, playerId: playerId, tilePosition: postItemEffectTilePosition)
      let destinationTile <- game.gameboard.remove(at: postItemEffectTilePosition)

      // the player picks up an item from the tile if one exists
      if destinationTile.itemContainer.length > 0 {
        let item <- destinationTile.removeItem(position: 0)
        emit PlayerPickedItem(gameId: gameId, playerId: playerId, itemId: item.id)
        player.addEquipment(item: <-item)
      }

      // the player picks up some points from the tile if one exists
      if destinationTile.tilePointsContainer.length > 0 {
        let tilePoints <- destinationTile.removeTilePoints(position: 0)
        emit PlayerPickedTilePoints(gameId: gameId, playerId: playerId, tilePointsId: tilePoints.id)
        player.acquireTilePoints(tilePoints: <- tilePoints)
      }

      // the player triggers a quest on the tile if one exists
      if destinationTile.questContainer.length > 0 {
        let quest <- destinationTile.removeQuest(position: 0)
        emit PlayerStartedQuest(gameId: gameId, playerId: playerId, questId: quest.id)
        
        // if the player fails any of the requirements, they fail the quest completely
        // note: these are pretty stringent requirements. it's not just a simple >= comparison. all comparator operators are used
        var success = true
        var i = 0
        while i < quest.requirements.length {
          var currentRequirement = quest.requirements[i]
          var attribute = currentRequirement.attribute
          var targetVal = currentRequirement.value
          var operation = currentRequirement.operation
        
          if attribute == "strength" {
            if !quest.checkRequirement(operation: operation, targetVal: targetVal, playerAttributeVal: player.strength) {
              success = false
            }
          } else if attribute == "intelligence" {
            if !quest.checkRequirement(operation: operation, targetVal: targetVal, playerAttributeVal: player.intelligence) {
              success = false
            }
          } else if attribute == "cunning" {
            if !quest.checkRequirement(operation: operation, targetVal: targetVal, playerAttributeVal: player.cunning) {
              success = false
            }
          }
       
          i = i + 1
        }

        // calculate the chance that a quest "awards" a player with an item or points
        // as the player moves along the game, the chances to receive a reward increases
        // i.e. gameboard size = 100, player position = 10: player award chance = 10%
        if success {
          emit PlayerCompletedQuest(gameId: gameId, playerId: playerId, questId: quest.id)
          
          let awardChanceTarget = postItemEffectTilePosition
          let playerAwardChance = LavaFlow.rng.runRNG(UInt(LavaFlow.gameboardSize))
          if awardChanceTarget > playerAwardChance {
            let awardType = LavaFlow.rng.runRNG(LavaFlow.awardTypeRNG)
            if awardType == UInt(0) {
              // reward item
              player.addEquipment(item: <-quest.awardItem(gameId: gameId, playerId: playerId))
            } else {
              // reward points
              player.acquireTilePoints(tilePoints: <- quest.awardPoints(gameId: gameId, playerId: playerId))
            }
          } 

        } else {
          emit PlayerFailedQuest(gameId: gameId, playerId: playerId, questId: quest.id)
        }

        // put the quest back onto the tile for other players to enjoys
        destinationTile.addQuest(quest: <-quest)
      }
      
      // put the player inside the destinationTile
      destinationTile.playerContainer.append(<- player)

      // put back the @destinationTile
      game.gameboard.insert(at: postItemEffectTilePosition, <- destinationTile)
      
      // update the player's new position in the world
      game.playerTilePositions[playerId] = postItemEffectTilePosition
      
      LavaFlow.games[gameId] <-! game
    }

    // moveLava moves the deathly lava forward
    //
    pub fun moveLava(gameId: UInt){
      let game <- LavaFlow.games.remove(key: gameId)!

      // the lava only starts moving after a specifed number of game turns
      if game.turnCount > LavaFlow.lavaTurnStart {
        var lavaMovement = LavaFlow.rng.runRNG(LavaFlow.lavaMovementRNG) + UInt(1)
        var lastLavaPosition = game.lastLavaPosition

        // check that the lava does not exceed the board's length
        if(lastLavaPosition + lavaMovement > UInt(LavaFlow.gameboardSize - 1) ){
          lavaMovement = UInt(LavaFlow.gameboardSize) - lastLavaPosition - UInt(1)
        }

        // Cover the tiles with lava
        while lastLavaPosition < game.lastLavaPosition + lavaMovement {
          let tile <- game.gameboard.remove(at: lastLavaPosition)
          tile.coverWithLava()
          game.gameboard.insert(at: lastLavaPosition, <- tile)
          lastLavaPosition = lastLavaPosition + UInt(1)
        }

        // Update the last lava position
        game.lastLavaPosition = lastLavaPosition
        emit MovedLava(gameId: gameId, lastPosition: game.lastLavaPosition)

      }

      // End the game if the lava reaches the last tile
      if (game.lastLavaPosition == UInt(LavaFlow.gameboardSize - 1)) {
        emit EndedGame(gameId: game.id)
        game.endGame()
        LavaFlow.games[gameId] <-! game
        return
      }
      
      LavaFlow.games[gameId] <-! game
    }

    pub fun throwBombAndDestroy(gameId: UInt){
      let game <- LavaFlow.games.remove(key: gameId)!

      // the lava only starts moving after a specifed number of game turns
      if game.turnCount > LavaFlow.lavaTurnStart {
        // every time the lava moves, a lava bomb is thrown
        let throwBomb = LavaFlow.rng.runRNG(LavaFlow.lavaBombRNG)
        if (throwBomb == UInt(1)) {
          let volcanoBombTarget = LavaFlow.rng.runRNG(UInt(LavaFlow.gameboardSize))

          emit LavaBombThrown(gameId: game.id, targetTile: volcanoBombTarget)
          
          let playerTilePositionKeys = game.playerTilePositions.keys
          // 1. get the target tile
          let targetTile <- game.gameboard.remove(at: volcanoBombTarget)

          for playerId in playerTilePositionKeys {
            let playerPosition = game.playerTilePositions[playerId]!
            if playerPosition == volcanoBombTarget {
              let player <- targetTile.getPlayer(id: playerId)
              let bombShield <- player.getBombShield()
              if bombShield == nil {
                emit PlayerHitByBomb(id: playerId)
                destroy player

                // clean up player data from game world
                var j = 0
                while j < game.playerTurnOrder.length {
                  if game.playerTurnOrder[j] == playerId {
                    game.playerTurnOrder.remove(at: j)
                  }
                  j = j + 1
                }
                game.playerReceivers.remove(key: playerId)
                game.totalPlayerCount = game.totalPlayerCount - UInt(1)
                game.playerTilePositions.remove(key: playerId)
              } else {            
                emit PlayerUsedItem(gameId: gameId, playerId: playerId, itemId: bombShield?.id!)
                bombShield?.decreaseDurability()
                if bombShield?.durability == UInt(0) {
                  destroy bombShield
                } else {
                  player.equipments.insert(at: 0, <- bombShield!)    
                }
                targetTile.playerContainer.append(<- player)
              }
            }
          }
          game.gameboard.insert(at: volcanoBombTarget, <- targetTile)
        }
      }
      LavaFlow.games[gameId] <-! game
    }
  }

  // QuestSystem handles all work around quest interactions
  pub struct QuestSystem {}

  // ItemSystem handles all work around item interactions
  pub struct ItemSystem {}

  /************************************************************************
  * Helpers
  *
  * Define all the helpers features
  *************************************************************************/

  // RNG handles number generation
  access(all) struct RNG {

    // seed is the initial seed value
    access(contract) var seed: UInt

    // init the seed and call random function to generate a first seed
    init() {
      self.seed = UInt(0)
      self.random(seed: UInt(12345))
    }

    // Random function that takes a seed and update it with a random number
    access(all) fun random(seed: UInt) {
      let tmpSeed = seed % UInt(2147483647)
      if (tmpSeed <= UInt(0)) {
        self.seed = tmpSeed + UInt(2147483646)
      } else {
        self.seed = tmpSeed
      }
    }
    
    // next gets the next generated number
    access(all) fun next(): UInt {
      self.seed = self.seed * UInt(16807) % UInt(2147483647)
      return self.seed
    }

    // runRNG gets a new random number
    access(all) fun runRNG(_ n: UInt): UInt {
      var tmpSeed = self.next()
      while(tmpSeed > n) {
        tmpSeed = tmpSeed % n
      }
      return tmpSeed
    }
  }

  init(){
    self.rng = RNG()
    self.gameboardSize = 50
    self.lavaTurnStart = UInt(5)
    self.games <- {}

    self.playerMovementRNG = UInt(6)
    self.playerStatsRNG = UInt(10)
    self.numberOfRequirementsRNG = UInt(3)
    self.requirementValueRNG = UInt(10)
    self.operationTypeRNG = UInt(5)
    self.itemTypeRNG = UInt(5)
    self.itemDurabilityRNG = UInt(3)
    self.numberOfItemsPerTileRNG = UInt(3)
    self.tileEventRNG = UInt(100)
    self.tileEventTypeRNG = UInt(100)
    self.newTilePointsRNG = UInt(100)
    self.lavaBombRNG = UInt(2)
    self.lavaMovementRNG = UInt(6)
    self.awardTypeRNG = UInt(2)

    self.turnPhaseSystem = TurnPhaseSystem()
    self.playerSystem = PlayerSystem()
    self.questSystem = QuestSystem()
    self.itemSystem = ItemSystem()
    self.movementSystem = MovementSystem()
    self.gameSystem = GameSystem()

    let playerMinter <- self.createPlayerMinter()
    self.savePlayerMinter(minter: <- playerMinter)

    let itemMinter <- self.createItemMinter()
    self.saveItemMinter(minter: <- itemMinter)

    let tilePointMinter <- self.createTilePointMinter()
    self.saveTilePointMinter(minter: <- tilePointMinter)

    let questMinter <- self.createQuestMinter()
    self.saveQuestMinter(minter: <- questMinter)

    let tileMinter <- self.createTileMinter()
    self.saveTileMinter(minter: <- tileMinter)

    let gameMinter <- self.createGameMinter()
    self.saveGameMinter(minter: <- gameMinter)
  }
}
 