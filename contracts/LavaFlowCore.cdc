// LavaFlow Contract
// The adventurers seeking riches are caught in an erupting treasure-filled volcano dungeon, Flodor. 
// Their entrance have been destroyed. They must find a way out while finding as many treasures as possible because they're greedy sons of pigs.
pub contract LavaFlow {
  
  pub event MintedPlayer(id id: UInt,name name: String,class class: String,intelligence intelligence: UInt,strength strength: UInt,cunning cunning: UInt)
  pub event DestroyedPlayer(id: UInt)
  pub event MintedItem(id: UInt, type: UInt, durability: UInt)
  pub event DestroyedItem(id: UInt)
  pub event MintedTilePoint(id: UInt, amount: UInt)
  pub event DestroyedTilePoint(id: UInt)
  pub event MintedQuest(id: UInt, name: String, description: String)
  pub event DestroyedQuest(id: UInt)
  pub event MintedTile(id: UInt)
  pub event DestroyedTile(id: UInt)
  pub event AddedItemToTile(tileId: UInt, itemId: UInt)
  pub event AddedQuestToTile(tileId: UInt, questId: UInt)
  pub event AddedTilePointToTile(tileId: UInt, tilePointId: UInt)
  pub event MintedGame(id: UInt, playersCount: UInt)
  pub event DestroyedGame(id: UInt)
  pub event AddedTileToGame(gameId: UInt, tileId: UInt, position: UInt)
  pub event StartedGame(gameId: UInt)
  pub event EndedGame(gameId: UInt)
  pub event AddedPlayerToGame(gameId: UInt, playerId: UInt)
  pub event NextGameTurn(gameId: UInt)
  pub event NextPlayerTurn(gameId: UInt, playerId: UInt)
  pub event MovedPlayerToTile(gameId: UInt, playerId: UInt, tilePosition: UInt)
  pub event MovedLava(gameId: UInt, lastPosition: UInt)
  
  pub event PlayerEndedGame(gameId: UInt, playerId: UInt)
  pub event TransferredPlayer(gameId: UInt, playerId: UInt)
  pub event TransferredTokens(gameId: UInt, amount: UInt)
  pub event PlayerPickedItem(gameId: UInt, playerId: UInt, itemId: UInt)
  pub event PlayerPickedTilePoint(gameId: UInt, playerId: UInt, tilePointId: UInt)
  pub event PlayerCompletedQuest(gameId: UInt, playerId: UInt, questId: UInt)
  pub event PlayerRewardedItem(gameId: UInt, playerId: UInt, itemId: UInt)
  pub event PlayerFailedQuest(gameId: UInt, playerId: UInt, questId: UInt)
  
  /************************************************************************
  * Global variables
  *
  * Define all the contract global variables
  *************************************************************************/
  // rng is the contract's random number generator
  access(self) let rng: RNG
  // gameboard size
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

  /************************************************************************
  * Global functions
  *
  * Define all the public fucntions
  *************************************************************************/
 
  // createGame
  //
  // Create a new game with a number of players
  //
  // Pre-Conditions:
  // We need at least 2 players
  //
  // Parameters: totalPlayerCount: the number of players in a game
  pub fun createGame(totalPlayerCount: UInt){
    pre {
      totalPlayerCount > UInt(1): "Game need at least 2 players"
    }
    let gameMinter <- self.loadGameMinter()
    gameMinter.mintGame(totalPlayerCount: totalPlayerCount)
    self.saveGameMinter(minter: <- gameMinter)
  }

  // joinGame
  //
  // Parameters: gameId: the id of the game to join
  //             player: player resource
  //             playerCollectionRef: collection ref to return the player at the end of the game
  pub fun joinGame(gameId: UInt, player: @Player, playerCollectionRef: &AnyResource{PlayerReceiver}) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to join"
    }
    let game <- LavaFlow.games.remove(key: gameId)!
    if game.isGameStarted {
      panic("Game is already started")
    } else if game.totalPlayerCount == UInt(game.playerTurnOrder.length) {
      panic("Game is full")
    } 
    LavaFlow.games[gameId] <-! game
    self.gameSystem.addPlayerToGame(gameId: gameId, player: <- player, playerCollectionRef: playerCollectionRef) 
  }

  // start a game
  pub fun startGame(gameId: UInt) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to join"
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

  // play next game turn
  pub fun nextTurn(gameId: UInt) {
    pre {
      LavaFlow.games[gameId] != nil : "No game to join"
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
  * Entities
  *
  * Define all the entites used for the LavaFlow game
  *************************************************************************/

  // Unit is an internal data structure for resources that reside within a Tile
  pub resource interface Unit {
    pub let id: UInt
    pub let entityType: String
  }

  // Player is an individual character that exists in the game world
  pub resource Player: Unit {
    pub let id: UInt
    pub let name: String
    pub let class: String
    pub let intelligence: UInt
    pub let strength: UInt
    pub let cunning: UInt
    pub let equipments: @[Item] // items of type and attributes, max 5 resources
    pub let entityType: String

    init(id: UInt, name: String, class: String, intelligence: UInt, strength: UInt, cunning: UInt) {
      self.id = id
      self.name = name
      self.class = class
      self.intelligence = intelligence
      self.strength = strength
      self.cunning = cunning
      self.equipments <- []
      self.entityType = "EntityPlayer"
    }

    access(all) fun addEquipment(item: @Item) {
      self.equipments.append(<- item)
    }

    access(all) fun removeEquipment(position: UInt, itemReceiver: &AnyResource{ItemReceiver}) {
      let item <- self.equipments.remove(at: position)
      itemReceiver.deposit(token: <- item)
    }

    access(all) fun getActiveItem(): @Item? {
      if self.equipments.length > 0 {
        var i = 0
        while i < self.equipments.length {
          let item <- self.equipments.remove(at: i)
          if item.type != UInt(0) {
            return <-item
          }
          self.equipments.insert(at: i, <-item)
          i = i + 1
        }
        return <- self.equipments.remove(at: 0)
      } else {
        return nil
      }
    }

    destroy() {
      var i = 0
      while i < self.equipments.length {
        let itemMinter <- LavaFlow.loadItemMinter()
        // itemMinter.burnItem(item: <- self.equipments.remove(at: i))
        LavaFlow.saveItemMinter(minter: <- itemMinter)
        i = i + 1
      }
      destroy self.equipments
    }
  }

  // Item is an individual item that exists in the game world 
  pub resource Item {
    pub let id: UInt
    pub let type: UInt
    // Type
    // 1. LavaSurfboard - save a Player if the lava ever reaches them. Move Player +1 ahead. Durability = 1...3
    // 2. BearTrap - hurts the Player on pickup. Disable movement. Durability = 1. Movement = 0.
    // 3. Jetpack - boosts the Player by a large number of tiles. Durability = 1...3. Move Player +2 ahead. 
    // 4. Slime - decreases the Player movement. Durability = 1...3. Movement -1.

    pub var durability: UInt // max number of usage

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
  }

  // TilePoint can be traded in for Lava Tokens at the end of a game
  pub resource TilePoint: Unit {
    pub let id: UInt
    pub let entityType: String
    pub let amount: UInt

    init(id: UInt, amount: UInt) {
      self.id = id        
      self.amount = amount
      self.entityType = "EntityTilePoint"
    }
  }

  // Quest is an individual Quest that exists in the game world
  pub resource Quest: Unit {
    pub let id: UInt
    pub let name: String
    pub let description: String
    pub let entityType: String
    pub let requirements: [QuestRequirement]

    init(id: UInt, name: String, description: String) {
      self.id = id
      self.name = name
      self.description = description
      self.requirements = []
      self.entityType = "EntityQuest"
    }
  }

  pub struct QuestRequirement {
    
    pub let attribute: String
    pub let operation: UInt
    pub let value: UInt

    init(attribute: String, operation: UInt, value: UInt){
      self.attribute = attribute
      self.operation = operation
      self.value = value
    }
  }

  // Tile represents spaces in the game world
  // It references entities that are within a certain space
  pub resource Tile {
    pub let id: UInt
    pub let container: @[AnyResource{Unit}]
    pub let itemContainer: @[Item]
    pub let playerContainer: @[Player]
    pub var lavaCovered: Bool

    init(id: UInt) {
      self.id = id
      self.container <- []
      self.lavaCovered = false
      self.playerContainer <- []
      self.itemContainer <- []
    }

    pub fun addUnit(unit: @AnyResource{Unit}) {
      self.container.append(<-unit)
    }

    pub fun removeUnit(position: UInt): @AnyResource{Unit} {
      return <-self.container.remove(at: position)
    }

    pub fun addItem(item: @Item) {
      self.itemContainer.append(<-item)
    }

    pub fun removeItem(position: UInt): @Item {
      return <-self.itemContainer.remove(at: position)
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

    // coverWithLava disables a tile with lava
    pub fun coverWithLava() {
      self.lavaCovered = true
    }

    destroy(){
      destroy self.container
      destroy self.playerContainer
      destroy self.itemContainer
    }
  }

  // Game represents a singular game instance
  pub resource Game {
    pub let id: UInt
    pub let gameboard: @[Tile]
    // Number of players to start a game
    pub(set) var totalPlayerCount: UInt
    // count how many turns have been played
    pub var turnCount: UInt
    // indicate if a game has started
    pub var isGameStarted: Bool
    // indicate if a game has ended
    pub var isGameEnded: Bool
    // tracks the latest position of the Lava
    pub(set) var lastLavaPosition: UInt
    // currentPlayerIndex points to the turn's current player
    pub var currentPlayerIndex: UInt
    // playerTilePositions maps Player id to tile position
    pub let playerTilePositions: {UInt: UInt}
    // playerTurnOrder is a queue of players that have joined the game
    pub let playerTurnOrder: [UInt]
    // playerReceivers stores all players' receivers so we can return the player at the end of a game
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

    pub fun incrementLavaPosition(amount: UInt) {
      self.lastLavaPosition = self.lastLavaPosition + amount
    }

    pub fun incrementCurrentPlayerIndex(){
      self.currentPlayerIndex = self.currentPlayerIndex + UInt(1)
      if(self.currentPlayerIndex == UInt(self.playerTurnOrder.length)){
        self.currentPlayerIndex = 0
      }
    }

    destroy() {
      destroy self.gameboard
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
      let randomStat1 = LavaFlow.rng.runRNG(10)
      let randomStat2 = LavaFlow.rng.runRNG(10)
      let randomStat3 = LavaFlow.rng.runRNG(10)
      emit MintedPlayer(id: self.idCount, name: name, class: class, intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
      return <- create Player(id: self.idCount, name: name, class: class, intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
    }

    pub fun burnPlayer(player: @AnyResource{Unit}){
      if(player.entityType == "EntityPlayer"){
        emit DestroyedPlayer(id: player.id)
        destroy player
        self.totalSupply = self.totalSupply - UInt(1)
      }
    }
  }

  access(self) fun createPlayerMinter(): @PlayerMinter{
    return <- create PlayerMinter()
  }

  access(self) fun savePlayerMinter(minter: @PlayerMinter){
    self.account.save(<- minter, to: /storage/PlayerMinter)
  }

  access(self) fun loadPlayerMinter(): @PlayerMinter{
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
      let type = LavaFlow.rng.runRNG(4)

      var durability = LavaFlow.rng.runRNG(3) + UInt(1)
      if type == UInt(1) {
        durability = UInt(1)
      }
      
      emit MintedItem(id: self.idCount, type: type, durability: durability)
      return <- create Item(id: self.idCount, type: type, durability: durability)
    }

    pub fun burnItem(item: @Item){
      emit DestroyedItem(id: item.id)
      destroy item
      self.totalSupply = self.totalSupply - UInt(1)
    }
  }

  access(self) fun createItemMinter(): @ItemMinter{
    return <- create ItemMinter()
  }

  access(self) fun saveItemMinter(minter: @ItemMinter){
    self.account.save(<- minter, to: /storage/ItemMinter)
  }

  access(self) fun loadItemMinter(): @ItemMinter{
    return <- self.account.load<@ItemMinter>(from: /storage/ItemMinter)!
  }

  pub resource TilePointMinter{
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

    pub fun burnPoints(point: @AnyResource{Unit}){
      if(point.entityType == "EntityTilePoint"){
        self.totalSupply = self.totalSupply - UInt(1)
        emit DestroyedTilePoint(id: point.id)
        destroy point
      }
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

    pub fun burnQuest(quest: @AnyResource{Unit}) {
      if (quest.entityType == "EntityQuest") {
        self.totalSupply = self.totalSupply - UInt(1)
        emit DestroyedQuest(id: quest.id)
        destroy quest
      }
    }
  }

  access(self) fun createQuestMinter(): @QuestMinter{
    return <- create QuestMinter()
  }

  access(self) fun saveQuestMinter(minter: @QuestMinter){
    self.account.save(<- minter, to: /storage/QuestMinter)
  }

  access(self) fun loadQuestMinter(): @QuestMinter{
    return <- self.account.load<@QuestMinter>(from: /storage/QuestMinter)!
  }

  // TileMinter mints new tiles
  pub resource TileMinter {
    pub var idCount: UInt
    pub var totalSupply: UInt

    init() {
      self.idCount = 0
      self.totalSupply = 0
    }

    // mintTile that mints a new Tile with a new ID
    // and deposits it in the Gameboard collection 
    // using their collection reference
    pub fun mintTile(): @Tile {
      var newTile <- self.mintEmptyTile()
      // determine whether an event trigger occurs (items, quest, ft)
      // Run rng to see if we have something on the tile (50% chance)
      let fullTileChance = LavaFlow.rng.runRNG(100)

      if fullTileChance > UInt(50) {
        // if a tile is allowed to have an event, create a resource to place on the tile
        // determine if the tile should have a quest (40%) | points (40%)| items (20%)
        let eventChance = LavaFlow.rng.runRNG(100)
        if (eventChance > UInt(60)) {
          let questMinter <- LavaFlow.loadQuestMinter()
          let quest <- questMinter.mintQuest(name: "Quest", description: "Quest description")
          emit AddedQuestToTile(tileId: newTile.id, questId: quest.id)
          newTile.addUnit(unit: <- quest)
          LavaFlow.saveQuestMinter(minter: <- questMinter)

        } else if (eventChance > UInt(20)) {
          let tilePointMinter <- LavaFlow.loadTilePointMinter()
          let tilePoint <- tilePointMinter.mintPoints(amount: LavaFlow.rng.runRNG(100))
          emit AddedTilePointToTile(tileId: newTile.id, tilePointId: tilePoint.id)
          newTile.addUnit(unit: <- tilePoint)
          LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)

        } else { 
          // generate a random number of items
          let numOfItems = LavaFlow.rng.runRNG(3) + UInt(1)

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

    // mintEmptyTile creates an tile with an empty container
    pub fun mintEmptyTile(): @Tile {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      emit MintedTile(id: self.idCount)
      return <- create Tile(id: self.idCount)
    }

    pub fun destroyTile(tile: @Tile) {
      self.totalSupply = self.totalSupply - UInt(1)
      emit DestroyedTile(id: tile.id)
      var i: UInt = 0
      while i < UInt(tile.container.length){
        let unit <- tile.removeUnit(position: i)
        if(unit.entityType == "EntityPlayer"){
          let playerMinter <- LavaFlow.loadPlayerMinter()
          playerMinter.burnPlayer(player: <- unit)
          LavaFlow.savePlayerMinter(minter: <- playerMinter)
        } else if(unit.entityType == "EntityItem"){
          let itemMinter <- LavaFlow.loadItemMinter()
          itemMinter.burnItem(item: <- unit)
          LavaFlow.saveItemMinter(minter: <- itemMinter)
        } else if(unit.entityType == "EntityTilePoint"){
          let tilePointMinter <- LavaFlow.loadTilePointMinter()
          tilePointMinter.burnPoints(point: <- unit)
          LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)
        } else if(unit.entityType == "EntityQuest"){
          let questMinter <- LavaFlow.loadQuestMinter()
          questMinter.burnQuest(quest: <- unit)
          LavaFlow.saveQuestMinter(minter: <- questMinter)
        } 
        i = i + UInt(1)
      }
      
      destroy tile
    }
  }

  access(self) fun createTileMinter(): @TileMinter{
    return <- create TileMinter()
  }

  access(self) fun saveTileMinter(minter: @TileMinter){
    self.account.save(<- minter, to: /storage/TileMinter)
  }

  access(self) fun loadTileMinter(): @TileMinter{
    return <- self.account.load<@TileMinter>(from: /storage/TileMinter)!
  }

  // GameMinter mints new games
  pub resource GameMinter {
    pub var idCount: UInt
    pub var currentGames: UInt

    init() {
        self.idCount = 0
        self.currentGames = 0
    }

    pub fun mintGame(totalPlayerCount: UInt) {
      self.idCount = self.idCount + UInt(1)
      self.currentGames = self.currentGames + UInt(1)
      let game <- create Game(id: self.idCount, totalPlayerCount: totalPlayerCount)
      emit MintedGame(id: game.id, playersCount: totalPlayerCount)
      // create tiles
      let tileMinter <- LavaFlow.loadTileMinter()
      let startTile <- tileMinter.mintEmptyTile()
      emit AddedTileToGame(gameId: game.id, tileId: startTile.id, position: 0)
      game.gameboard.append(<- startTile)
      var i = 0
      while i < LavaFlow.gameboardSize - 2 {
        let tile <- tileMinter.mintTile()
        emit AddedTileToGame(gameId: game.id, tileId: tile.id, position: UInt(i + 1))
        game.gameboard.append(<- tile)
        i = i + 1
      }
      let endTile <- tileMinter.mintEmptyTile()
      emit AddedTileToGame(gameId: game.id, tileId: endTile.id, position: 100)
      game.gameboard.append(<- endTile)
      LavaFlow.saveTileMinter(minter: <- tileMinter)

      LavaFlow.games[game.id] <-! game
    }

    pub fun destroyGame(game: @Game) {
      self.currentGames = self.currentGames - UInt(1)
      emit DestroyedGame(id: game.id)
      destroy game
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
  // Definition of an interface for Player Receiver
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

  pub fun createEmptyPlayerCollection(): @PlayersCollection{
    return <- create PlayersCollection()
  }

  // Definition of an interface for Item Receiver
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

  pub fun createEmptyItemCollection(): @ItemsCollection{
    return <- create ItemsCollection()
  }

  /************************************************************************
  * SYSTEMS
  *
  * Handles state changes in the game world
  *************************************************************************/

  // GameSystem handles the life of a game
  pub struct GameSystem {
    // startGame
    pub fun startGame(gameId: UInt) {
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
    pub fun addPlayerToGame(gameId: UInt, player: @Player, playerCollectionRef: &AnyResource{PlayerReceiver}) {
      let game <- LavaFlow.games.remove(key: gameId)!
      if !game.isGameStarted && UInt(game.playerTurnOrder.length) < game.totalPlayerCount {
        // Add the playerCollectionRef to the game player coll refs
        game.playerReceivers[player.id] = playerCollectionRef

        // Add the player to the first tile of the game
        game.playerTurnOrder.append(player.id)

        // set the player position on gameboard
        game.playerTilePositions[player.id] = 0
        emit AddedPlayerToGame(gameId: game.id, playerId: player.id)
        // set the player in the first tile
        let firstTile <- game.gameboard.remove(at: 0)
        firstTile.playerContainer.append(<- player)
        game.gameboard.insert(at: 0, <- firstTile)  
      }
      LavaFlow.games[gameId] <-! game
    }
    
    pub fun nextTurn(gameId: UInt){
      var game <- LavaFlow.games.remove(key: gameId)!
      game.incrementTurnCount()
      if game.isGameEnded {
        destroy game
        //LavaFlow.games[gameId] <-! game
        // Do something ... send players back if they win!! ??
        return
      }
      emit NextGameTurn(gameId: gameId)
      LavaFlow.games[gameId] <-! game
      // create a copy of the game and put it back into the collection because movementSystem.movePlayer will also pull the game from the collection
      log("Moving players")
      // 1. players roll for new positions
      LavaFlow.movementSystem.movePlayers(gameId: gameId)

      // 2. trigger player effects (pick up items)


      log("Checking if a player reached the last tile")
      // 2.5 check if any players have reached the last tile
      var newGame <- LavaFlow.games.remove(key: gameId)!
      var i = UInt(0)
      var lastTilePlayersIds: [UInt] = []
      for position in newGame.playerTilePositions.values {
        if(position == UInt(newGame.gameboard.length - 1)) {
          // player in last tile
          lastTilePlayersIds.append(newGame.playerTilePositions.keys[i])
        }
        i = i + UInt(1)
      }

      log(lastTilePlayersIds)

      for playerId in lastTilePlayersIds {
        log("Removing winner player with id")
        log(playerId)
        //get last tile
        let lastTile <- newGame.gameboard.remove(at: newGame.gameboard.length - 1)
        let player <- lastTile.getPlayer(id: playerId)
        newGame.gameboard.append(<- lastTile)
        // send back the player
        newGame.playerReceivers[playerId]!.deposit(token: <- player)
        log("Sent player")
        
        var j = 0
        while j < newGame.playerTurnOrder.length {
          if newGame.playerTurnOrder[j] == playerId {
            newGame.playerTurnOrder.remove(at: j)
          }
          j = j + 1
        }
        newGame.playerReceivers.remove(key: playerId)
        newGame.totalPlayerCount = newGame.totalPlayerCount - UInt(1)
        newGame.playerTilePositions.remove(key: playerId)
      }
      
      if newGame.playerTurnOrder.length == 0 {
        newGame.endGame()
        destroy newGame
        return
      }
      
      LavaFlow.games[gameId] <-! newGame

      log("Moving the lave")
      // 3. run lava roll
      LavaFlow.movementSystem.moveLava(gameId: gameId)

      // 4. destroy the players trapped inside the lava
      LavaFlow.playerSystem.destroyPlayersInLava(gameId: gameId)

      // self.nextTurn(gameId: gameId)
    }
  }
  
  // TurnPhaseSystem handles all work around player movement and player turn rotation.
  pub struct TurnPhaseSystem {
  }

  // PlayerSystem manages character state, namely attributes and effects
  pub struct PlayerSystem {
    pub fun destroyPlayersInLava(gameId: UInt) {
      log("Destroy player in tile")
      // get a copy of the game's player positions
      let game <- LavaFlow.games.remove(key: gameId)!
      
      var i = 0
      for playerId in game.playerTilePositions.keys {
        log("PlayerId")
        log(playerId)
        // if the player's position sits inside the lava, we destroy the player
        // to destroy the player, get the tile they're positioned on, then get the player
        let playerPosition = game.playerTilePositions[playerId]!
        if playerPosition <= game.lastLavaPosition {
          
          let tilePlayerPositionedOn <- game.gameboard.remove(at: playerPosition)
          
          let player <- tilePlayerPositionedOn.getPlayer(id: playerId)

          // TODO: check if player can survive destruction through an item usage
          // call playerminter destroyPlayer
          destroy player
          
          // puttile back into place
          game.gameboard.insert(at: playerPosition, <- tilePlayerPositionedOn)

          // Clean player data
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
        i = i + 1
      }

      LavaFlow.games[gameId] <-! game 
    }

  }

  // MovementSystem manages player and lava movements
  pub struct MovementSystem {
    pub fun movePlayers(gameId: UInt) {
      let game <- LavaFlow.games.remove(key: gameId)!
      let playerTurnOrder = game.playerTurnOrder
      LavaFlow.games[gameId] <-! game
      
      for playerId in playerTurnOrder {
        var game <- LavaFlow.games.remove(key: gameId)!
        let movementForward = LavaFlow.rng.runRNG(6) + UInt(1)

        // loop through the equipments, and add them, multiply to the movementForward
        // check if item is one time use, then destroy

        var newPosition = game.playerTilePositions[playerId]! + UInt(movementForward)

        // ensure player ends on the last tile if they over-roll
        if newPosition >= UInt(game.gameboard.length) {
          newPosition = UInt(game.gameboard.length - 1)
        }
        emit NextPlayerTurn(gameId: game.id, playerId: playerId)

        LavaFlow.games[gameId] <-! game
        LavaFlow.movementSystem.movePlayer(gameId: gameId, playerId: playerId, tilePosition: newPosition)
      }
    }

    pub fun movePlayer(gameId: UInt, playerId: UInt, tilePosition: UInt) {
      log("Moving player with ID")
      log(playerId)
      let game <- LavaFlow.games.remove(key: gameId)!

      // get the current player tile => @startTile
      let currentTilePosition = game.playerTilePositions[playerId]!
      let currentTile <- game.gameboard.remove(at: currentTilePosition)
      log("Current player position")
      log(currentTilePosition)
      

      // player is guaranteed to exist in the tile because we store and read the current player positions 
      let player <- currentTile.getPlayer(id: playerId)

      // put back the current player tile
      game.gameboard.insert(at: currentTilePosition, <- currentTile)

      var postPositionEffect = tilePosition
      // get active item, not surfboard
      let activeItem <- player.getActiveItem()
      if activeItem != nil {
        // use item
        // Type
        // 0. LavaSurfboard - save a Player if the lava ever reaches them. Move Player +1 ahead. Durability = 1...3
        // 1. BearTrap - hurts the Player on pickup. Disable movement. Durability = 1. Movement = 0.
        if activeItem?.type == UInt(1) {
          postPositionEffect = currentTilePosition

        } else if activeItem?.type == UInt(2) {
        // 2. Jetpack - boosts the Player by a large number of tiles. Durability = 1...3. Move Player +2 ahead. 
          postPositionEffect = postPositionEffect + UInt(2)

        } else if activeItem?.type == UInt(3) {
        // 3. Slime - decreases the Player movement. Durability = 1...3. Movement -1.
          postPositionEffect = postPositionEffect - UInt(1)
        }

        activeItem?.decreaseDurability()
        if activeItem?.durability == UInt(0) {
          destroy activeItem
        } else {
          player.equipments.insert(at: 0, <- activeItem!)    
        }
      }

      // get the destination tile given tileId 
      emit MovedPlayerToTile(gameId: gameId, playerId: playerId, tilePosition: postPositionEffect)
      let destinationTile <- game.gameboard.remove(at: postPositionEffect)

      // check if tile contains items
      if destinationTile.itemContainer.length > 0 {
        let item <- destinationTile.removeItem(position: 0)
        player.equipments.append(<-item)
      }
      
      // put the player inside the destinationTile
      destinationTile.playerContainer.append(<- player)

      // put back the @destinationTile
      game.gameboard.insert(at: postPositionEffect, <- destinationTile)
      log("New player position")
      log(postPositionEffect)

      // update the player's new position in the world
      game.playerTilePositions[playerId] = postPositionEffect
      
      LavaFlow.games[gameId] <-! game
    }

    pub fun moveLava(gameId: UInt){
      let game <- LavaFlow.games.remove(key: gameId)!
      if game.turnCount > LavaFlow.lavaTurnStart {
        log("Moving lava")
        var lavaMovement = LavaFlow.rng.runRNG(6) + UInt(1) // 6
        var lastLavaPosition = game.lastLavaPosition
        log("Current lava position")
        log(lastLavaPosition)
        // check that lastLavaTilePosition + lavaMovement <= gameboardSize - 1
        if(lastLavaPosition + lavaMovement > UInt(LavaFlow.gameboardSize - 1) ){
          lavaMovement = UInt(LavaFlow.gameboardSize) - lastLavaPosition - UInt(1)
        }

        while lastLavaPosition < game.lastLavaPosition + lavaMovement {
          // get the tile at lastLavaTilePosition
          let tile <- game.gameboard.remove(at: lastLavaPosition)
          tile.coverWithLava()
          game.gameboard.insert(at: lastLavaPosition, <- tile)
          lastLavaPosition = lastLavaPosition + UInt(1)
        }
        log("New lava position")
        log(lastLavaPosition)
        game.lastLavaPosition = lastLavaPosition
        emit MovedLava(gameId: gameId, lastPosition: game.lastLavaPosition)

      }

      if (game.lastLavaPosition == UInt(LavaFlow.gameboardSize - 1)) {
        emit EndedGame(gameId: game.id)
        game.endGame()
      }

      // check if we still have players in the game
      // end the game otherwise
      

      LavaFlow.games[gameId] <-! game
    }
  }

  // QuestSystem handles all work around quest interactions
  pub struct QuestSystem {
  }

  // ItemSystem handles all work around item interactions
  pub struct ItemSystem {
  }

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
      self.random(seed: UInt(1238345))
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
    self.gameboardSize = 25
    self.lavaTurnStart = UInt(0)
    self.games <- {}

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
 