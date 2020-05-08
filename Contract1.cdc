// LavaFlow Contract
// The adventurers seeking riches are caught in a lava-filled treasure cave, Mordor. 
// Their entrance have been destroyed. They must find a way out while finding as many treasures as possible.
pub contract LavaFlow {

    /**************************************************************
    * LAVA FLOW WORLD STATE 
    * 
    * Here are all the declared entities, components, and systems
    ***************************************************************/

    // Systems act upon the game world state (Components), reading and updating as necessary
    pub let turnPhaseSystem: TurnPhaseSystem
    pub let playerSystem: PlayerSystem
    pub let questSystem: QuestSystem
    pub let itemSystem: ItemSystem
    
    // Component maps hold references to Components that exist in the game world
    pub let players: @{UInt64: Player}
    pub let items: @{UInt64: Item}
    pub let tiles: @{UInt64: Tile}
    pub let quests: @{UInt64: Quest}
    
    pub let rng: RNG

    /*
    * MINTERS
    */
    access(contract) let itemMinter: @ItemMinter
    access(contract) let questMinter: @QuestMinter
    access(contract) let tilePointMinter: @TilePointMinter
    /************************************************************************
    * COMPONENTS === GAME STATE
    *
    * Components are the individual resources that belong in the game world
    * It captures the state of the world
    *************************************************************************/

    // currentPlayerIndex points to the turn's current player
    pub let currentPlayerIndex: Int // 0...4
    
    // playerOrder is a queue of players that have joined the game
    pub let playerOrder: [UInt64]

    // gameboard is the order of tiles laid out for movement
    pub let gameboard: [UInt64]

        
    // Units are an internal data structure for entities that reside within the Tile
    pub resource interface Unit {
        pub let id: UInt64
        pub let entityType: String
    }

    // TilePoint represents the tokens to be rewarded to a player
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
            // self.onComplete = false
            // self.onFail = fun(): void
            // self.onComplete = fun(): void
        }
    }

    pub struct QuestRequirement {
        /*
         * 'strenght'
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
    
    // TileComponent represents spaces in the game world
    // It references entities that are within a certain space
    pub resource Tile {
        pub let id: UInt64
        pub let contains: @[AnyResource{Unit}]

        init(initID: UInt64) {
            self.id = initID
            self.contains <- []
        }

        pub fun addUnit() {
            // self.contains.push(Unit(entityType: "Player", entityID: UInt64(1)))
        }

        pub fun removeUnit() {}

        destroy(){
            destroy self.contains
        }
    }

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

    // Gameboard owns all the individual Tile data
    pub resource Gameboard {
        pub let tiles: @{UInt64: Tile}

        init() {
            self.tiles <- {}
        }

        destroy() {
            destroy self.tiles
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

    
    
    /************************************************************************
    * SYSTEMS
    *
    * Handles state changes in the game world
    *************************************************************************/

    // TurnPhaseSystem handles all work around player movement and player turn rotation
    pub struct TurnPhaseSystem {
        // pub fun nextTurn(): @[playerEntities]
    }
    
    // PlayerSystem manages character state, namely attributes and effects
    pub struct PlayerSystem {
        pub fun newPlayer(): @Player {
            return <-create Player(id: 1, name: "Guest Character", class: "swashbuckler", intelligence: UInt64(1), strength: UInt64(1), cunning: UInt64(1))
        }

        pub fun Players(): @Players {
            return <-create Players()
        }

        pub fun movePlayer(id: UInt64) {
            // 1. get the player id
            // 2. check if id exists in the game world
            // 3. update the tile that contains the player
        }

        pub fun readAttributes() {
            // sum the attributes of all the player's base attributes and their equipments by type (intell, strength, cunning)
        }
    }

    pub resource interface TileReceiver {
      pub fun getIDs(): [UInt64]
      pub fun idExists(id: UInt64): Bool
    }

    // Minters
    
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

    pub resource TileMinter {
        pub let maxTileCount: UInt64
        pub var idCount: UInt64

        // the ID that is used to mint NFTs
        // it is onlt incremented so that NFT ids remain
        // unique. It also keeps track of the total number of NFTs
        // in existence

        init() {
            self.maxTileCount = 100
            self.idCount = 1
        }

        // mintTile 
        //
        // Function that mints a new Tile with a new ID
        // and deposits it in the Gameboard collection 
        // using their collection reference
        pub fun mintTile(recipient: &AnyResource{TileReceiver}) {

            // create a new Tile
            var newTile <- create Tile(initID: self.idCount)

            // Run rng to see if we have something on the tile (50% chance)
            // run rng to determine if the tile contains a quest (40% chance) | FT (40% chance)| items (20% items)
            let shouldTileHaveEvent = LavaFlow.rng.runRNG(100)
            if shouldTileHaveEvent > UInt64(50) {
                let eventChance = LavaFlow.rng.runRNG(100)
                if (eventChance > UInt64(60)) {
                    let quest <- LavaFlow.questMinter.mintQuest()
                    newTile.contains.append(<-quest)
                } else if (eventChance > UInt64(20)) {
                    let randomAmount = LavaFlow.rng.runRNG(100)
                    let points <- LavaFlow.tilePointMinter.mintPoints(amount: randomAmount)
                    newTile.contains.append(<-points)
                } else {
                    let item <- LavaFlow.itemMinter.mintItem()
                    newTile.contains.append(<-item)
                }
            }
        }
    }

        // QuestSystem handles all work around quest interactions
    pub struct QuestSystem {
        pub fun completeQuest() {
            // 1. get the quest
            // var q1 = LavaFlow.quests[UInt64(5)]
            // 2. get reference to player
            var currentPlayerID = LavaFlow.playerOrder[LavaFlow.currentPlayerIndex]
            // if playerRef.intel >= q1.req.intel && playerRef.strenght >= q1.req.strength
            // => players win
            // Run RNG => if rng == 1
            // Mint new equipment  let equipement <- LavaFlow.itemMinter.mint()?
            // playerRef.equipment.push(<-equipment)

            
            let chance = LavaFlow.rng.runRNG(100)
            if(chance == UInt64(0)){
                // move the resource out from collection to act upon it
                let player <- LavaFlow.players.remove(key: currentPlayerID)! 
                // mint the equipement
                
                LavaFlow.players[currentPlayerID] <-! self.rewardPlayer(player: <-player)
            }
            // player.equipments.append(<- equipment)
            // is there a way to do it non-forced? It's safe because we know that that spot is nil
            
            // LavaFlow.players[playerID] <- player
            // 1. evaluate winning chance
            // 2. if win, reward player, else {}
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

        // pub fun addItem(to player: Player) {
        //     // check maxNumEquipment
        // }

        // pub fun removeItem(from player: Player) {}
    }

    // initialize the entities, components, and systems for Lava Flow
    init() {
        self.rng = RNG()
        // self.playerEntities = []
        // self.itemEntities = []
        // self.tileEntities = []

        self.players <- {}
        self.items <- {}
        self.tiles <- {}
        self.quests <- {}

        self.playerOrder = []
        self.currentPlayerIndex = 0

        // initialize the game world with a mix of the tile IDs
        self.gameboard = []
        
        self.itemMinter <- create ItemMinter()
        self.questMinter <- create QuestMinter()
        self.tilePointMinter <- create TilePointMinter()

        self.turnPhaseSystem = TurnPhaseSystem()
        self.playerSystem = PlayerSystem()
        self.questSystem = QuestSystem()
        self.itemSystem = ItemSystem()
    }

    // Declare a structure that holds the RNG logic
    access(all) struct RNG {

        // The initial seed
        access(contract) var seed: UInt64

        // Initialize the seed and call random function to generate a first seed
        init() {
        self.seed = UInt64(0)
        self.random(seed: UInt64(12345))
        }
        
        // Random function that takes a seed and update it with a random number
        access(all) fun random(seed: UInt64) {
            let tmpSeed = seed % UInt64(2147483647)
            if (tmpSeed <= UInt64(0)) {
                self.seed = tmpSeed + UInt64(2147483646)
            } else {
                self.seed = tmpSeed
            }
        }
        
        // Get the next generated number
        access(all) fun next(): UInt64 {
            self.seed = self.seed * UInt64(16807) % UInt64(2147483647)
            return self.seed
        }

        // Get the next integer number
        access(all) fun nextInt(): UInt64 {
            var tmpSeed = self.next()
            while(tmpSeed > UInt64(10)) {
                tmpSeed = tmpSeed % UInt64(10)
            }
            if (tmpSeed == UInt64(0)) {
                return UInt64(1)
            } else {
                return tmpSeed
            }
        }

       // Get the next integer number
        access(all) fun runRNG(_ n: UInt64): UInt64 {
            var tmpSeed = self.next()
            while(tmpSeed > n) {
                tmpSeed = tmpSeed % UInt64(10)
            }
            if (tmpSeed == UInt64(0)) {
                return UInt64(1)
            } else {
                return tmpSeed
            }
        }
    }
}     