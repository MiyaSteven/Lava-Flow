// LavaFlow Contract
// The adventurers seeking riches are caught in a lava-filled treasure cave, Mordor. 
// Their entrance have been destroyed. They must find a way out while finding as many treasures as possible.
//
// Architecture: loosely architected based on the Entity-Components-System pattern
// https://aframe.io/docs/1.0.0/introduction/entity-component-system.html
// https://en.wikipedia.org/wiki/Entity_component_system

pub contract LavaFlow {

    /**************************************************************
    * LAVA FLOW WORLD STATE 
    * 
    * Here are all the declared entities, components, and systems
    ***************************************************************/

    // // ENTITIES = THINGS IN THE GAME
    // // Entities references all existing interactive models in the Lava Flow universe
    // // Systems will reference Entities here to access Components
    // pub let playerEntities: {} // 2, 0, 1
    // pub let itemEntities: [UInt64]
    // pub let tileEntities: [UInt64]

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
    }

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

    // Player is an individual character that exists in the game world
    pub resource Player {
        pub let id: UInt64
        pub let name: String
        pub let class: String
        pub let intelligence: UInt64
        pub let strength: UInt64
        pub let cunning: UInt64
        pub let equipments: @[AnyResource] // items of type and attributes, max 5 resources

        init(id: UInt64, name: String, class: String, intelligence: UInt64, strength: UInt64, cunning: UInt64) {
            self.id = id
            self.name = name
            self.class = class
            self.intelligence = intelligence
            self.strength = strength
            self.cunning = cunning
            self.equipments <- []
        }


        destroy() {
            destroy self.equipments
        }
    }

    // Item is an individual item that exists in the game world 
    pub resource Item {
        pub let id: UInt64
        pub let name: String
        pub let points: UInt64
        pub let type: String
        pub let effect: String
        pub let use: String
        
        init(id: UInt64, name: String, points: UInt64, type: String, effect: String, use: String) {
            self.id = id
            self.name = name
            self.points = points
            self.type = type
            self.effect = effect
            self.use = use
        }
    }

    // Quest is an individual Quest that exists in the game world
    pub resource Quest {
        pub let id: UInt64
        pub let name: String
        // Max 3 requirements without double req on attribute
        // pub let requirements: {strength: UInt64, intelligence: UInt64, cunning: UInt64}
        // ex requirements1: { strenght < 10 }
        // ex requirements2: { strenght >= 5, intelligence < 8 }
        // ex requirements3: { strenght <= 5, intelligence > 8, cunning = 6 }
        // pub let requirements: [QuestRequirement]
        //
        pub let description: String
        pub let onComplete: Bool

        init(id: UInt64, name: String, description: String, onFail: Bool, onComplete: Bool) {
            self.id = id
            self.name = name
            //self.requirements = requirements
            self.description = description
            self.onComplete = false
        }
    }

    pub struct QuestRequirement{
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

    pub resource QuestMinter {
        pub var idCount: UInt64
        pub let rng: RNG

        init() {
            self.idCount = 1
            self.rng = RNG()
        }

        pub fun mintQuest(recipient: &AnyResource{TileReceiver}) {
            let id = self.idCount + UInt64(1)
            // let name = 
            let newTile <- create Quest(id: UInt64, name: String, description: String, onFail: Bool, onComplete: Bool)

            self.idCount = self.idCount + UInt64(1)
        }
    }
    
    // Units are an internal data structure for entities that reside within the Tile
    pub struct Unit {
        pub let entityType: String
        pub let entityID: UInt64

        init(id: UInt64, type: String) {
            self.entityType = type
            self.entityID = id
        }
    }
    
    // TileComponent represents spaces in the game world
    // It references entities that are within a certain space
    pub resource Tile {
        pub let id: UInt64
        pub let contains: [Unit]

        init(initID: UInt64) {
            self.id = initID
            self.contains = []
        }

        pub fun addUnit() {
            // self.contains.push(Unit(entityType: "Player", entityID: UInt64(1)))
        }

        pub fun removeUnit() {}
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

      pub fun depositQuest(quest: @Quest)
      pub fun depositItem(item: @Item)
      pub fun deposit(token: @LavaToken.Receiver)

      pub fun getIDs(): [UInt64]

      pub fun idExists(id: UInt64): Bool
    }


    pub resource TileMinter: MaxTileSupply {
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
            pub fun depositQuest(quest: @Quest) {
                let oldQuest <- self.ownedQuests[quest.id] <- quest
                destroy oldQuest
            }

            pub fun depositItem(item: Item) {
                let oldItem <- self.ownedItems[item.id] <- item
                destroy oldItem
            }

            pub fun depositLavaToken(token: @LavaFlowToken.Receiver) {
                let oldTokens <- self.ownedTokens[token.count] <- token
                destroy oldTokens
            }
                // 1- Quest:
                    // create the quest using QuestMinter
                    // let quest <- LavaFlow.questMinter.mintQuest() // add the quest to the quests component
                    // add the quest to the tile contents
                // 2- FT
                    // run some rng to determine the amount of FT to mint
                    // create the FlowToken using FlowTokenMinter
                    // add the FT to the tile
                // 3- Item
                    // create the item using itemMinter
                    // add the item to the tile
                

            // deposit it in the recipient's account using their reference
            recipient.deposit(tile: <-newTile)

            // change the id so that each ID is unique
            self.idCount = self.idCount + UInt64(1)
        }

        pub fun deposit(tile: @Tile){
            LavaFlow.gameboard.append(tile.id)
            LavaFlow.tiles[tile.id] <-! tile
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
 