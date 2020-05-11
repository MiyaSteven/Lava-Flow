// LavaFlow Contract
// The adventurers seeking riches are caught in an erupting treasure-filled volcano dungeon, Flodor. 
// Their entrance have been destroyed. They must find a way out while finding as many treasures as possible because they're greedy sons of pigs.
pub contract LavaFlow {

    /**************************************************************
    * LAVA FLOW LOCAL GAME WORLD STATE 
    * 
    * Declare all entities, collections, and systems
    ***************************************************************/

    // Systems act upon the game world state
    pub let turnPhaseSystem: TurnPhaseSystem
    pub let playerSystem: PlayerSystem
    pub let questSystem: QuestSystem
    pub let itemSystem: ItemSystem
    pub let movementSystem: MovementSystem
    pub let gameSystem: GameSystem

    // Entities hold references to all the resources in the game world
    // This enables easy access to resources
    pub let playerEntities: {UInt64: &Player}
    pub let itemEntities: {UInt64: &Item}
    pub let questEntities: {UInt64: &Quest}
    
    // rng is the contract's random number generator
    pub let rng: RNG

    /****************************************************************
    * LAVA FLOW RESOURCES
    *
    * Declare all the resources that belong in the game world
    *****************************************************************/

    // Minters create the game's resources
    access(contract) let itemMinter: @ItemMinter
    access(contract) let questMinter: @QuestMinter
    access(contract) let tilePointMinter: @TilePointMinter
    access(contract) let tileMinter: @TileMinter
    access(contract) let playerMinter: @PlayerMinter
    pub let gameboardMinter: @GameboardMinter

    // Collections hold all the entities that exist in the game world
    pub let players: @{UInt64: Player}
    pub let items: @{UInt64: Item}
    pub let tiles: @{UInt64: Tile}
    pub let quests: @{UInt64: Quest}
    pub let games: @{UInt64: Gameboard}

    /**************************************************
    * LAVA FLOW RESOURCE COLLECTIONS
    **************************************************/

    // Players owns all the individual Player data
    pub resource Players {
        pub let players: @{UInt64: Player}

        init() {
            self.players <- {}
        }

        destroy() {
            destroy self.players
        }
    }

    // ItemCollection owns all the individual Item data
    pub resource Items {
        pub let items: @{UInt64: Item}

        init() {
            self.items <- {}
        }

        destroy() {
            destroy self.items
        }
    }
    
    // Quests is a collection of all the quests
    pub resource Quests {
        pub let quests: @{UInt64: Quest}

        init() {
            self.quests <- {}
        }

        destroy() {
            destroy self.quests
        }
    }

    /**************************************************
    * LAVA FLOW MINTERS AND RESOURCES
    **************************************************/

    // GameboardMinter mints new gameboards
    pub resource GameboardMinter {
        pub var idCount: UInt64

        init() {
            self.idCount = 0
        }

        pub fun mintGameboard() {
            self.idCount = self.idCount + UInt64(1)
            let game <- create Gameboard(id: self.idCount)
            LavaFlow.games[game.id] <-! game
        }
    }

    // Gameboard represents a singular game instance
    pub resource Gameboard {
        pub let id: UInt64
        pub let tiles: @[Tile]
        pub var turnCount: UInt64
        pub var isGameEnded: Bool
        
        // playerTilePositions maps Player id to tile position
        // {playerId: tilePositionkey (0 - 99)}
        pub let playerTilePositions: {UInt64: UInt}

         // currentPlayerIndex points to the turn's current player
        pub(set) var currentPlayerIndex: Int // i.e. 0...4

        // playerTurnOrder is a queue of players that have joined the game
        pub let playerTurnOrder: [UInt64]

        // playerReceivers stores all players' receivers so we can return the player at the end of a game
        pub let playerReceivers: {UInt64: &AnyResource{LavaFlow.PlayerReceiver}}
        pub(set) var isStarted: Bool
        pub var lastLavaPosition: UInt

        pub fun incrementTurn() {
            self.turnCount = self.turnCount + UInt64(1)
        }

        pub fun endGame() {
            self.isGameEnded = true
        }

        init(id: UInt64) {
            self.id = id
            self.isStarted = false
            self.tiles <- []
            self.playerTilePositions = {}
            self.playerReceivers = {}
            self.currentPlayerIndex = 0
            self.playerTurnOrder = []
            self.tiles.append(<-LavaFlow.tileMinter.mintEmptyTile())
            self.turnCount = 0
            self.isGameEnded = false
            self.lastLavaPosition = 0
            
            // initialize the game board with tiles and items
            while(self.tiles.length < 5) {
                let newTile <- LavaFlow.tileMinter.mintTile()
                self.tiles.append(<-newTile) 
            }
        }

        destroy() {
            destroy self.tiles
        }
    }
        
    // Unit is an internal data structure for resources that reside within a Tile
    pub resource interface Unit {
        pub let id: UInt64
        pub let entityType: String
    }

    // ItemMinter mints new items
    pub resource ItemMinter {
        pub var idCount: UInt64

        init() {
            self.idCount = UInt64(0)
        }

        pub fun mintItem(): @Item {
            self.idCount = self.idCount + UInt64(1)
            let points = LavaFlow.rng.runRNG(100)
            return <- create Item(id: self.idCount, name: "placement name", points: points, type: "placement item type", effect: "diarrhea", use: "plunger")
        }
    }

    // Item is an individual item that exists in the game world 
    pub resource Item: Unit {
        pub let id: UInt64
        pub let name: String
        pub let points: UInt64
        pub let type: String
        pub let effect: String
        pub let use: String
        pub let entityType: String

        init(id: UInt64, name: String, points: UInt64, type: String, effect: String, use: String) {
            self.id = id
            self.name = name
            self.points = points
            self.type = type
            self.effect = effect
            self.use = use
            self.entityType = "EntityItem"
        }
    }
    
    pub resource TilePointMinter{
        pub var idCount: UInt64

        init() {
            self.idCount = UInt64(0)
        }

        pub fun mintPoints(amount: UInt64): @TilePoint {
            self.idCount = self.idCount + UInt64(1)
            return <- create TilePoint(id: self.idCount, amount: amount)
        }
    }

    // TilePoint can be traded in for Lava Tokens at the end of a game
    pub resource TilePoint: Unit {
        pub let id: UInt64
        pub let entityType: String
        pub let amount: UInt64

        init(id: UInt64, amount: UInt64) {
            self.id = id        
            self.amount = amount
            self.entityType = "EntityTilePoint"
        }
    }

    pub resource PlayerMinter {
        pub var idCount: UInt64

        init() {
            self.idCount = UInt64(1)
        }

        pub fun mintPlayers(): @Player {
            self.idCount = self.idCount + UInt64(1)
            /* Should we make a global variable for rng variables? */
            let randomStat1 = LavaFlow.rng.runRNG(10)
            let randomStat2 = LavaFlow.rng.runRNG(10)
            let randomStat3 = LavaFlow.rng.runRNG(10)
            return <- create Player(id: UInt64(1), name: "placement name", class: "placement class", intelligence: randomStat1, strength: randomStat2, cunning: randomStat3)
        }
    }

    // Player is an individual character that exists in the game world
    pub resource Player: Unit {
        pub let id: UInt64
        pub let name: String
        pub let class: String
        pub let intelligence: UInt64
        pub let strength: UInt64
        pub let cunning: UInt64
        pub let equipments: @[AnyResource] // items of type and attributes, max 5 resources
        pub let entityType: String

        init(id: UInt64, name: String, class: String, intelligence: UInt64, strength: UInt64, cunning: UInt64) {
            self.id = id
            self.name = name
            self.class = class
            self.intelligence = intelligence
            self.strength = strength
            self.cunning = cunning
            self.equipments <- []
            self.entityType = "EntityPlayer"
        }


        destroy() {
            destroy self.equipments
        }
    }

    pub resource QuestMinter {
        pub var idCount: UInt64
        pub let rng: RNG

        init() {
            self.idCount = 1
            self.rng = RNG()
        }

        pub fun mintQuest(): @Quest {
            let id = self.idCount + UInt64(1)
            self.idCount = self.idCount + UInt64(1)
            return <- create Quest(id: id, name: "PlaceholderName", description: "PlaceholderDesc")
        }
    }

    // Quest is an individual Quest that exists in the game world
    pub resource Quest: Unit {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let entityType: String
        
        // pub let requirements: LavaFlow.requirement
        // Max 3 requirements without double req on attribute
        // pub let requirements: {strength: UInt64, intelligence: UInt64, cunning: UInt64}
        // ex requirements1: { strenght < 10 }
        // ex requirements2: { strenght >= 5, intelligence < 8 }
        // ex requirements3: { strenght <= 5, intelligence > 8, cunning = 6 }
        pub let requirements: [QuestRequirement]
        // pub let onFail: ((): void)
        // pub let onComplete: ((): void)

        init(id: UInt64, name: String, description: String) {
            self.id = id
            self.name = name
            self.description = description
            self.requirements = []
            self.entityType = "EntityQuest"
            // self.onFail = fun(): void
            // self.onComplete = fun(): void
        }
    }

    pub struct QuestRequirement {
        /*
         * 'strength'
         * 'intelligence'
         * 'cunning'
         */
        pub let attribute: String

        /*
         * '<' => UInt(0)
         * '<=' => UInt(1)
         * '==' => UInt(2)
         * '>' => UInt(3)
         * '>=' => UInt(4)
         */
        pub let operation: UInt

        /*
         * [2..10]
         */
        pub let value: UInt
        init(attribute: String, operation: UInt, value: UInt){
            self.attribute = attribute
            self.operation = operation
            self.value = value
        }
    }

    // TileMinter mints new tiles
    pub resource TileMinter {
        pub var idCount: UInt64
        init() {
            self.idCount = 0
        }

        // mintTile that mints a new Tile with a new ID
        // and deposits it in the Gameboard collection 
        // using their collection reference
        pub fun mintTile(): @Tile {
            var newTile <- create Tile(initID: self.incrementID())

            // determine whether an event trigger occurs (items, quest, ft)
            // Run rng to see if we have something on the tile (50% chance)
            if LavaFlow.rng.runRNG(100) > UInt64(50) {
                // if a tile is allowed to have an event, create a resource to place on the tile
                // determine if the tile should have a quest (40%) | points (40%)| items (20%)
                let eventChance = LavaFlow.rng.runRNG(100)
                if (eventChance > UInt64(60)) {
                    newTile.addUnit(unit: <-LavaFlow.questMinter.mintQuest())
                } else if (eventChance > UInt64(20)) {
                    newTile.addUnit(unit: <-LavaFlow.tilePointMinter.mintPoints(amount: LavaFlow.rng.runRNG(100)))
                } else {
                    newTile.addUnit(unit: <-LavaFlow.itemMinter.mintItem())
                }
            }
            
            return <- newTile
        }

        // mintEmptyTile creates an tile with an empty container
        pub fun mintEmptyTile(): @Tile {
            return <- create Tile(initID: self.incrementID())
        }

        // incrementID increments the internal tile id counter
        pub fun incrementID(): UInt64 {
            self.idCount = self.idCount + UInt64(1)
            return self.idCount
        }
    }
    
    // TileComponent represents spaces in the game world
    // It references entities that are within a certain space
    pub resource Tile {
        pub let id: UInt64
        pub let container: @[AnyResource{Unit}]
        pub(set) var lavaCovered: Bool

        init(initID: UInt64) {
            self.id = initID
            self.container <- []
            self.lavaCovered = false
        }

        pub fun addUnit(unit: @AnyResource{LavaFlow.Unit}) {
            self.container.append(<-unit)
        }

        pub fun removeUnit(id: UInt64): @AnyResource{LavaFlow.Unit} {
            return <-self.container.remove(at: id)
        }

        pub fun getUnit(id: UInt64, type: String): @AnyResource{LavaFlow.Unit} {
            var i = 0
            var unitPositionInTileContainer = 0

            while i < self.container.length {
                let unit <- self.container.remove(at: i)
                if unit.id == id && unit.entityType == type {
                    unitPositionInTileContainer = i
                }
                self.container.insert(at: i, <- unit)
            }

            return <- self.container.remove(at: unitPositionInTileContainer)
        }

        // coverWithLava disables a tile with lava
        pub fun coverWithLava() {
            self.lavaCovered = true
        }

        destroy(){
            destroy self.container
        }
    }
    
    /************************************************************************
    * SYSTEMS
    *
    * Handles state changes in the game world
    *************************************************************************/

    // Definition of an interface for Player Receiver
    access(all) resource interface PlayerReceiver {
        access(all) fun deposit(token: @Player)
        access(all) fun getIDs(): [UInt64]
        access(all) fun idExists(id: UInt64): Bool
    }

    access(all) resource PlayersCollection: PlayerReceiver {
        access(all) var ownedPlayers: @{UInt64: Player}

        init () {
        self.ownedPlayers <- {}
        }

        access(all) fun withdraw(id: UInt64): @Player {
            let token <- self.ownedPlayers.remove(key: id) ?? panic("missing Player")
            return <-token
        }

        access(all) fun deposit(token: @Player) {
            let oldToken <- self.ownedPlayers[token.id] <- token
            destroy oldToken
        }

        access(all) fun idExists(id: UInt64): Bool {
            return self.ownedPlayers[id] != nil
        }

        access(all) fun getIDs(): [UInt64] {
            return self.ownedPlayers.keys
        }

        destroy() {
            destroy self.ownedPlayers
        }
    }
    
    // GameSystem handles the life of a game
    pub struct GameSystem {
        // startGame initiates and recursively runs a game to completion
        pub fun startGame(gameID: UInt64) {
            let game <- LavaFlow.games.remove(key: gameID)!
            let playersCount = game.playerTilePositions.keys.length
            if !game.isStarted && playersCount > 1 {
                game.isStarted = true
                self.nextTurn(gameID: gameID)
            }
            LavaFlow.games[gameID] <-! game
        }

        pub fun nextTurn(gameID: UInt64) {
            let game <- LavaFlow.games.remove(key: gameID)!
            
            // 1. players roll for new positions
            for playerID in game.playerTurnOrder {
                let movementForward = LavaFlow.rng.runRNG(6) + UInt64(1)
                var newPosition = game.playerTilePositions[playerID]! + UInt(movementForward)

                // ensure player ends on the last tile if they over-roll
                if newPosition >= UInt(game.tiles.length) {
                    newPosition = UInt(game.tiles.length - 1)
                } 

                LavaFlow.movementSystem.movePlayer(gameId: gameID, playerID: playerID, tilePosition: newPosition)
            }

            // 2. trigger player effects
            
            // 3. run lava roll
            if game.turnCount > UInt64(3) {
                let lavaMovement = LavaFlow.rng.runRNG(6) + UInt64(1)
                var lastLavaTilePosition = game.lastLavaPosition + UInt(1) // increment by 1 because the last tile is already covered with lava
                while lastLavaTilePosition < lastLavaTilePosition + UInt(lavaMovement) {
                    let tile <- game.tiles.remove(at: lastLavaTilePosition)
                    tile.coverWithLava()

                    // check if a player is on a tile covered with lava
                    // destroy the player if lava touches them
                    var i = 0
                    for tilePositionWithPlayer in game.playerTilePositions.values {
                        if lastLavaTilePosition == tilePositionWithPlayer {
                            // now that we have a player that is on a tile with lava, 
                            // we remove them from the game
                            var playerID = game.playerTilePositions.keys[i]
                            
                            // cleanup player state from game world
                            // 1. playerOrderTurn, playerEntities, 
                            
                            // You are not worthy of the Lava
                            let player <- tile.getUnit(id: playerID, type: "EntityPlayer")
                            destroy player

                            game.playerTilePositions.remove(key: playerID)
                            
                            var j = 0
                            for turnPlayerID in game.playerTurnOrder {
                                if turnPlayerID == playerID {
                                    game.playerTurnOrder.remove(at: j)
                                }
                                j = j + 1
                            }

                            game.playerReceivers.remove(key: playerID)
                        }

                        i = i + 1
                    }

                    game.tiles.insert(at: lastLavaTilePosition, <- tile)
                    lastLavaTilePosition = lastLavaTilePosition + UInt(1)
                }
            }
            
            // 4. end game for player in tile with lava
            // 5. check game status: number of live players or if all players reached end
            
            game.incrementTurn()

            if !game.isGameEnded {
                self.nextTurn(gameID: game.id)
            }
            
            LavaFlow.games[gameID] <-! game
        }

        // addPlayerToGame moves a Player into the game world
        pub fun addPlayerToGame(player: @Player, gameID: UInt64, playerCollectionRef: &AnyResource{PlayerReceiver}) {
            let game <- LavaFlow.games.remove(key: gameID)!
            if !game.isStarted {
                // Add the playerCollectionRef to the game player coll refs
                game.playerReceivers[player.id] = playerCollectionRef
                // Add the player to the first tile of the game
                game.playerTurnOrder.append(player.id)
                game.playerTilePositions[player.id] = 0
                let firstTile <- game.tiles.remove(at: 0)
                firstTile.container.append(<- player)
                game.tiles.insert(at: 0, <- firstTile)  
            }
            LavaFlow.games[gameID] <-! game
        }

        // pub fun rollLavaMovement(game: @Gameboard): @Gameboard {
        //     let lavaMovement = LavaFlow.rng.runRNG(6) + UInt64(1)
        //     var lastLavaTilePosition = game.lastLavaPosition + UInt(1) // +1 because the last tile is already covered with lava
        //     while lastLavaTilePosition < lastLavaTilePosition + UInt(lavaMovement) {
        //         let tile <- game.tiles.remove(at: lastLavaTilePosition)
        //         tile.coverWithLava()

        //         // check if a player is on a tile covered with lava
        //         var i = 0
        //         for tilePositionWithPlayer in game.playerTilePositions.values {
        //             if lastLavaTilePosition == tilePositionWithPlayer {
        //                 // now that we have a player that is on a tile with lava, 
        //                 // we remove them from the game
        //                 var playerID = game.playerTilePositions.keys[i]
                        
        //                 // cleanup player state from game world
        //                 // 1. playerOrderTurn, playerEntities, 
                        
        //                 // You are not worthy of the Lava
        //                 let player <- tile.getUnit(id: playerID, type: "EntityPlayer")
        //                 destroy player

        //                 game.playerTilePositions.remove(key: playerID)
                        
        //                 var j = 0
        //                 for turnPlayerID in game.playerTurnOrder {
        //                     if turnPlayerID == playerID {
        //                         game.playerTurnOrder.remove(at: j)
        //                     }
        //                     j = j + 1
        //                 }

        //                 game.playerReceivers.remove(key: playerID)


        //             }
        //             i = i + 1
        //         }
        //         game.tiles.insert(at: lastLavaTilePosition, <- tile)
        //         lastLavaTilePosition = lastLavaTilePosition + UInt(1)
        //     }
            
        //     return <- game
        // }
        
        // // removePlayerFromGame removes a Player from the game world.
        // // Example: When an owner's account wants to retrieve their Player after a game ends
        // pub fun removePlayerFromGame(game: &AnyResource{LavaFlow.Gameboard}, tile: @Tile, playerID: UInt64) {
        //     // You are not worthy of the Lava
        //     let player <- tile.getUnit(id: playerID, type: "EntityPlayer")
        //     destroy player

        //     game.playerTilePositions.remove(key: playerID)
            
        //     var j = 0
        //     for turnPlayerID in game.playerTurnOrder {
        //         if turnPlayerID == playerID {
        //             game.playerTurnOrder.remove(at: j)
        //         }
        //         j = j + 1
        //     }

        //     game.playerReceivers.remove(key: playerID)
        // }
    }

    // TurnPhaseSystem handles all work around player movement and player turn rotation.
    pub struct TurnPhaseSystem {
        // pickFirstPlayer rolls to determine player starts the game
        pub fun pickFirstPlayer(gameID: UInt64) {
            let game <- LavaFlow.games.remove(key: gameID)!
            let firstPlayerIndex = LavaFlow.rng.runRNG(UInt64(game.playerTurnOrder.length))
            game.currentPlayerIndex = Int(firstPlayerIndex)
            LavaFlow.games[gameID] <-! game
        }

        // getCurrentTurnPlayer returns the current turn's player ID.
        pub fun getCurrentTurnPlayer(gameID: UInt64): UInt64 {
            let game <- LavaFlow.games.remove(key: gameID)!
            let currentPlayerID = game.playerTurnOrder[game.currentPlayerIndex]
            LavaFlow.games[gameID] <-! game
            return currentPlayerID
        }

        // nextTurn forwards the turn by 1 and returns the new current player's ID
        pub fun nextTurn(gameID: UInt64) {
            let game <- LavaFlow.games.remove(key: gameID)!

            var nextTurn = game.currentPlayerIndex + 1
            if nextTurn == game.playerTurnOrder.length {
                nextTurn = 0
            }
            game.currentPlayerIndex = nextTurn
            
            self.getCurrentTurnPlayer(gameID: game.id)

            LavaFlow.games[gameID] <-! game
        }

        // prevTurn only sets the player order back by 1 turn and returns the new current player's ID
        // It does not support reversing a turn skip.
        pub fun prevTurn(gameID: UInt64) {
            let game <- LavaFlow.games.remove(key: gameID)!
            var prevTurn = game.currentPlayerIndex - 1
            if prevTurn < 0 {
                prevTurn = game.playerTurnOrder.length - 1
            }
            game.currentPlayerIndex = prevTurn
            LavaFlow.games[gameID] <-! game
        }
    }
    
    // PlayerSystem manages character state, namely attributes and effects
    pub struct PlayerSystem {
        pub fun newPlayer(): @Player {
            return <-create Player(id: 1, name: "Guest Character", class: "swashbuckler", intelligence: UInt64(1), strength: UInt64(1), cunning: UInt64(1))
        }

        pub fun Players(): @Players {
            return <-create Players()
        }

        pub fun readAttributes() {
            // sum the attributes of all the player's base attributes and their equipments by type (intell, strength, cunning)
        }
    }

    pub struct MovementSystem {
        // moveEntity moves a Unit into a Tile
        access(self) fun moveUnit(unit: @AnyResource{LavaFlow.Unit}, to tile: &Tile) {
            tile.container.append(<-unit)
        }

        pub fun movePlayer(gameId: UInt64, playerID: UInt64, tilePosition: UInt){
            // get the game => @game
            let game <- LavaFlow.games.remove(key: gameId)!
            
            // get the current player tile => @startTile
            let currentTilePosition = game.playerTilePositions[playerID]!
            let currentTile <- game.tiles.remove(at: currentTilePosition)

            let player <- currentTile.getUnit(id: playerID, type: "EntityPlayer")

            // put back @startTile
            game.tiles.insert(at: currentTilePosition, <- currentTile)
            // get the destination tile given tileId => @destinationTile
            let destinationTile <- game.tiles.remove(at: tilePosition)
            // put @player inside @destinationTile
            destinationTile.container.append(<- player)
            // put back @@destinationTile
            game.tiles.insert(at: tilePosition, <- destinationTile)
            // put back the @game

            LavaFlow.games[gameId] <-! game

        }
    }

    // QuestSystem handles all work around quest interactions
    pub struct QuestSystem {
        pub fun completeQuest() {
            // // 1. get the quest
            // // var q1 = LavaFlow.quests[UInt64(5)]
            // // 2. get reference to player
            // var currentPlayerID = LavaFlow.playerOrder[LavaFlow.currentPlayerIndex]
            // // if playerRef.intel >= q1.req.intel && playerRef.strenght >= q1.req.strength
            // // => players win
            // // Run RNG => if rng == 1
            // // Mint new equipment  let equipement <- LavaFlow.itemMinter.mint()?
            // // playerRef.equipment.push(<-equipment)

            
            // let chance = LavaFlow.rng.runRNG(100)
            // if(chance == UInt64(0)){
            //     // move the resource out from collection to act upon it
            //     let player <- LavaFlow.players.remove(key: currentPlayerID)! 
            //     // mint the equipement
                
            //     LavaFlow.players[currentPlayerID] <-! self.rewardPlayer(player: <-player)
            // }
            // // player.equipments.append(<- equipment)
            // // is there a way to do it non-forced? It's safe because we know that that spot is nil
            
            // // LavaFlow.players[playerID] <- player
            // // 1. evaluate winning chance
            // // 2. if win, reward player, else {}
        }

        pub fun rewardPlayer(player: @Player): @Player {
            // 1. MINT THE ITEM
            // player.equipments.append(<- equipment)
            // 2. MOVE ITEM TO PLAYER'S EQUIPMENT

            return <- player
        }
    }

    // ItemSystem handles all work around item interactions
    pub struct ItemSystem {
        pub let maxNumEquipment: Int
        
        init() {
            self.maxNumEquipment = 5
        }
    }

    // init the Lava Flow contract
    init() {
        self.players <- {}
        self.items <- {}
        self.tiles <- {}
        self.quests <- {}
        self.games <- {}

        self.itemMinter <- create ItemMinter()
        self.questMinter <- create QuestMinter()
        self.tilePointMinter <- create TilePointMinter()
        self.gameboardMinter <- create GameboardMinter()
        self.tileMinter <- create TileMinter()
        self.playerMinter <- create PlayerMinter()

        self.turnPhaseSystem = TurnPhaseSystem()
        self.playerSystem = PlayerSystem()
        self.questSystem = QuestSystem()
        self.itemSystem = ItemSystem()
        self.movementSystem = MovementSystem()
        self.gameSystem = GameSystem()

        self.playerEntities = {}
        self.itemEntities = {}
        self.questEntities = {}

        self.rng = RNG()
    }

    /************************************************************************
    * LAVA FLOW UTILS
    *
    * Random number generator, logs, other utils necessary to maintain Lava Flow
    *************************************************************************/

    // viewGames logs a game's tiles and its contents
    pub fun viewGames(id: UInt64) {
        let game <- self.games.remove(key: id)!
        log("gameID")
        log(game.id)

        // access nested tiles
        var i = 0
        while i < game.tiles.length {
            let tile <- game.tiles.remove(at: i)
            log("tileID")
            log(tile.id)

            // access nested tile content
            var j = 0
            while j < tile.container.length {
                let unit <- tile.container.remove(at: UInt64(j))
                log("unitID")
                log(unit.id)
                log(unit.entityType)
                tile.container.insert(at: j, <-unit)
                j = j + 1
            }

            game.tiles.insert(at: i, <-tile)

            i = i + 1
        }

        self.games[id] <-! game
    }

    // RNG handles number generation
    access(all) struct RNG {

        // seed is the initial seed value
        access(contract) var seed: UInt64

        // init the seed and call random function to generate a first seed
        init() {
            self.seed = UInt64(0)
        }
        
        // next gets the next generated number
        access(all) fun next(): UInt64 {
            self.seed = self.seed * UInt64(16807) % UInt64(2147483647)
            return self.seed
        }

       // runRNG gets a new random number
        access(all) fun runRNG(_ n: UInt64): UInt64 {
            var tmpSeed = self.next()
            while(tmpSeed > n) {
                tmpSeed = tmpSeed % UInt64(n)
            }
            if (tmpSeed == UInt64(0)) {
                return UInt64(1)
            } else {
                return tmpSeed
            }
        }
    }
}