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

    // Entities references all existing interactive models in the Lava Flow universe
    // Systems will reference Entities here to access Components
    pub let playerEntities: [UInt64]
    pub let itemEntities: [UInt64]
    pub let tileEntities: [UInt64]

    // Systems act upon the game world state (Components), reading and updating as necessary
    pub let turnPhaseSystem: TurnPhaseSystem
    pub let playerSystem: PlayerSystem
    pub let questSystem: QuestSystem
    pub let itemSystem: ItemSystem
    
    // Component maps hold references to Components that exist in the game world
    pub let players: {UInt64: &Player}
    pub let items: {UInt64: &Item}
    pub let tiles: {UInt64: &Tile}
    pub let quests: {UInt64: &Quest}

    /************************************************************************
    * COMPONENTS
    *
    * Components are the individual resources that belong in the game world
    * It captures the state of the world
    *************************************************************************/

    // Player is an individual character that exists in the game world
    pub resource Player {
        pub let id: UInt64
        pub let name: String
        pub let class: String
        pub let intelligence: UInt64
        pub let strength: UInt64
        pub let cunning: UInt64

        init(id: UInt64, name: String, class: String, intelligence: UInt64, strength: UInt64, cunning: UInt64) {
            self.id = id
            self.name = name
            self.class = class
            self.intelligence = intelligence
            self.strength = strength
            self.cunning = cunning
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

        init(id: UInt64) {
            self.id = id
            self.contains = []
        }
    }

    // QuestComponent is an individual Quest that exists in the game world
    pub resource Quest {
        
    }

    /************************************************************************
    * SYSTEMS
    *
    * Handles state changes in the game world
    *************************************************************************/

    // TurnPhaseSystem handles all work around player movement and player turn rotation
    pub struct TurnPhaseSystem {}
    
    // PlayerSystem manages character state, namely attributes and effects
    pub struct PlayerSystem {
        pub fun newPlayer(): @Player {
            return <-create Player(id: 1, name: "Guest Character", class: "swashbuckler", intelligence: UInt64(1), strength: UInt64(1), cunning: UInt64(1))
        }

        pub fun Players(): @Players {
            return <-create Players()
        }
    }

    // QuestSystem handles all work around quest interactions
    pub struct QuestSystem {}
    
    // ItemSystem handles all work around item interactions
    pub struct ItemSystem {}

    // initialize the entities, components, and systems for Lava Flow
    init() {
        self.playerEntities = []
        self.itemEntities = []
        self.tileEntities = []

        self.players = {}
        self.items = {}
        self.tiles = {}
        self.quests = {}
        
        self.turnPhaseSystem = TurnPhaseSystem()
        self.playerSystem = PlayerSystem()
        self.questSystem = QuestSystem()
        self.itemSystem = ItemSystem()
    }

}
 