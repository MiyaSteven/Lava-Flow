// LavaFlow Contract
// The adventurers seeking riches are caught in an erupting treasure-filled volcano dungeon, Flodor. 
// Their entrance have been destroyed. They must find a way out while finding as many treasures as possible because they're greedy sons of pigs.
pub contract LavaFlow {
  
  /************************************************************************
  * Global variables
  *
  * Define all the contract global variables
  *************************************************************************/
  // rng is the contract's random number generator
  access(self) let rng: RNG
  // gameboard size
  access(self) let gameboardSize: Int
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
  // Parameters: playersCount: the number of players in a game
  pub fun createGame(playersCount: UInt){
    pre {
      playersCount > UInt(1): "We need at least 2 players"
    }
    let gameMinter <- self.loadGameMinter()
    gameMinter.mintGame(playersCount: playersCount)
    self.saveGameMinter(minter: <- gameMinter)
  }

  // joinGame
  //
  // Parameters: gameId: the id of the game to join
  //             player: player resource
  //             playerCollectionRef: collection ref to return the player at the end of the game
  pub fun joinGame(gameId: UInt, player: @Player, playerCollectionRef: &AnyResource{PlayerReceiver}){
    self.gameSystem.addPlayerToGame(gameId: gameId, player: <- player, playerCollectionRef: playerCollectionRef) 
  }

  // start a game
  // pub fun startGame(gameId: UInt){
  //   let game <- self.games.remove(key: gameId)
  // }

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

    access(all) fun addEquipement(item: @Item) {
      self.equipments.append(<- item)
    }

    access(all) fun removeEquipement(position: UInt, itemReceiver: &AnyResource{ItemReceiver}) {
      let item <- self.equipments.remove(at: position)
      itemReceiver.deposit(token: <- item)
    }

    destroy() {
      var i = 0
      while i < self.equipments.length{
        let itemMinter <- LavaFlow.loadItemMinter()
        itemMinter.burnItem(item: <- self.equipments.remove(at: i))
        LavaFlow.saveItemMinter(minter: <- itemMinter)
        i = i + 1
      }
      destroy self.equipments
    }
  }

  // Item is an individual item that exists in the game world 
  pub resource Item: Unit {
    pub let id: UInt
    pub let name: String
    pub let points: UInt
    pub let type: String
    pub let effect: String
    pub let use: String
    pub let entityType: String

    init(id: UInt, name: String, points: UInt, type: String, effect: String, use: String) {
      self.id = id
      self.name = name
      self.points = points
      self.type = type
      self.effect = effect
      self.use = use
      self.entityType = "EntityItem"
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

    init(id: UInt) {
      self.id = id
      self.container <- []
    }

    pub fun addUnit(unit: @AnyResource{Unit}) {
      self.container.append(<-unit)
    }

    pub fun removeUnit(position: UInt): @AnyResource{Unit} {
      return <-self.container.remove(at: position)
    }

    destroy(){
      destroy self.container
    }
  }

  // Game represents a singular game instance
  pub resource Game {
    pub let id: UInt
    pub let gameboard: @[Tile]
    // Number of players to start a game
    pub let playersCount: UInt
    // count how many turns have been played
    pub var turnCount: UInt
    // indicate if a game has started
    pub var isGameStarted: Bool
    // indicate if a game has ended
    pub var isGameEnded: Bool
    // tracks the latest position of the Lava
    pub var lastLavaPosition: UInt
    // currentPlayerIndex points to the turn's current player
    pub var currentPlayerIndex: UInt
    // playerTilePositions maps Player id to tile position
    pub let playerTilePositions: {UInt: UInt}
    // playerTurnOrder is a queue of players that have joined the game
    pub let playerTurnOrder: [UInt]
    // playerReceivers stores all players' receivers so we can return the player at the end of a game
    pub let playerReceivers: {UInt: &AnyResource{LavaFlow.PlayerReceiver}}

    init(id: UInt, playersCount: UInt) {
      self.id = id
      self.playersCount = playersCount
      self.gameboard <- []
      self.turnCount = 0
      self.isGameStarted = false
      self.isGameEnded = false
      self.lastLavaPosition = 0
      self.playerTilePositions = {}
      self.currentPlayerIndex = 0
      self.playerTurnOrder = []
      self.playerReceivers = {}

      let tileMinter <- LavaFlow.loadTileMinter()
      self.gameboard.append(<- tileMinter.mintEmptyTile())
      // initialize the game board with tiles and items
      while(self.gameboard.length < LavaFlow.gameboardSize) {
        let newTile <- tileMinter.mintTile()
        self.gameboard.append(<- newTile) 
      }

      LavaFlow.saveTileMinter(minter: <- tileMinter)
    }

    pub fun startGame() {
      self.isGameStarted = true
    }

    pub fun endGame() {
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
      self.idCount = UInt(1)
      self.totalSupply = 0
    }

    pub fun mintPlayers(name: String, class: String): @Player {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      let randomStat1 = LavaFlow.rng.runRNG(10)
      let randomStat2 = LavaFlow.rng.runRNG(10)
      let randomStat3 = LavaFlow.rng.runRNG(10)
      return <- create Player(id: self.idCount, name: name, class: class, intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
    }

    pub fun burnPlayer(player: @AnyResource{Unit}){
      if(player.entityType == "EntityPlayer"){
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

    pub fun mintItem(name: String, type: String, effect: String, use: String): @Item {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      let points = LavaFlow.rng.runRNG(100)
      return <- create Item(id: self.idCount, name: name, points: points, type: type, effect: effect, use: use)
    }

    pub fun burnItem(item: @AnyResource{Unit}){
      if(item.entityType == "EntityItem"){
        destroy item
        self.totalSupply = self.totalSupply - UInt(1)
      }
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
      return <- create TilePoint(id: self.idCount, amount: amount)
    }

    pub fun burnPoints(point: @AnyResource{Unit}){
      if(point.entityType == "EntityTilePoint"){
        self.totalSupply = self.totalSupply - UInt(1)
        destroy point
      }
    }
  }

  access(self) fun createTilePointMinter(): @TilePointMinter{
    return <- create TilePointMinter()
  }

  access(self) fun saveTilePointMinter(minter: @TilePointMinter){
    self.account.save(<- minter, to: /storage/TilePointMinter)
  }

  access(self) fun loadTilePointMinter(): @TilePointMinter{
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
      return <- create Quest(id: self.idCount, name: name, description: description)
    }

    pub fun burnQuest(quest: @AnyResource{Unit}){
      if(quest.entityType == "EntityQuest"){
        self.totalSupply = self.totalSupply - UInt(1)
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
      if LavaFlow.rng.runRNG(100) > UInt(50) {
        // if a tile is allowed to have an event, create a resource to place on the tile
        // determine if the tile should have a quest (40%) | points (40%)| items (20%)
        let eventChance = LavaFlow.rng.runRNG(100)
        if (eventChance > UInt(60)) {
          let questMinter <- LavaFlow.loadQuestMinter()
          newTile.addUnit(unit: <- questMinter.mintQuest(name: "Quest", description: "Quest description"))
          LavaFlow.saveQuestMinter(minter: <- questMinter)
        } else if (eventChance > UInt(20)) {
          let tilePointMinter <- LavaFlow.loadTilePointMinter()
          newTile.addUnit(unit: <- tilePointMinter.mintPoints(amount: LavaFlow.rng.runRNG(100)))
          LavaFlow.saveTilePointMinter(minter: <- tilePointMinter)
        } else {
          let itemMinter <- LavaFlow.loadItemMinter()
          newTile.addUnit(unit: <- itemMinter.mintItem(name: "Item", type:"type", effect: "effect", use: "use"))
          LavaFlow.saveItemMinter(minter: <- itemMinter)
        }
      }
      
      return <- newTile
    }

    // mintEmptyTile creates an tile with an empty container
    pub fun mintEmptyTile(): @Tile {
      self.idCount = self.idCount + UInt(1)
      self.totalSupply = self.totalSupply + UInt(1)
      return <- create Tile(id: self.idCount)
    }

    pub fun destroyTile(tile: @Tile) {
      self.totalSupply = self.totalSupply - UInt(1)
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

    pub fun mintGame(playersCount: UInt) {
      self.idCount = self.idCount + UInt(1)
      self.currentGames = self.currentGames + UInt(1)
      let game <- create Game(id: self.idCount, playersCount: playersCount)
      LavaFlow.games[game.id] <-! game
    }

    pub fun destroyGame(game: @Game) {
      self.currentGames = self.currentGames - UInt(1)
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
      if !game.isGameStarted && UInt(game.playerTurnOrder.length) == game.playersCount {
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
      if !game.isGameStarted && UInt(game.playerTurnOrder.length) < game.playersCount {
        // Add the playerCollectionRef to the game player coll refs
        game.playerReceivers[player.id] = playerCollectionRef

        // Add the player to the first tile of the game
        game.playerTurnOrder.append(player.id)

        // set the player position on gameboard
        game.playerTilePositions[player.id] = 0

        // set the player in the first tile
        let firstTile <- game.gameboard.remove(at: 0)
        firstTile.container.append(<- player)
        game.gameboard.insert(at: 0, <- firstTile)  
      }
      LavaFlow.games[gameId] <-! game
    }
    
    pub fun nextTurn(gameId: UInt){
      var game <- LavaFlow.games.remove(key: gameId)!

      // 1. players roll for new positions
      for playerId in game.playerTurnOrder {
        let movementForward = LavaFlow.rng.runRNG(6) + UInt(1)
        var newPosition = game.playerTilePositions[playerId]! + UInt(movementForward)

        // ensure player ends on the last tile if they over-roll
        if newPosition >= UInt(game.gameboard.length) {
          newPosition = UInt(game.gameboard.length - 1)
        }

        // LavaFlow.movementSystem.movePlayer(gameId: gameID, playerID: playerID, tilePosition: newPosition)
      }
      LavaFlow.games[gameId] <-! game
    }
  }
  
  // TurnPhaseSystem handles all work around player movement and player turn rotation.
  pub struct TurnPhaseSystem {
  }

  // PlayerSystem manages character state, namely attributes and effects
  pub struct PlayerSystem {
  }

  // MovementSystem manages player and lava movements
  pub struct MovementSystem {
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
        tmpSeed = tmpSeed % UInt(n)
      }
      if (tmpSeed == UInt(0)) {
        return UInt(1)
      } else {
        return tmpSeed
      }
    }
  }

  init(){
    self.rng = RNG()
    self.gameboardSize = 100
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