import LavaFlow from 0x01
import LavaToken from 0x02

// Setup players account
// We need at least to setup two players account
// 
// Game instructions:
// Sign this contract with accounts 0x02 & 0x03

transaction {
  prepare(acct: AuthAccount) {
    let playerStorage <- LavaFlow.createEmptyPlayerCollection()
    let itemStorage <- LavaFlow.createEmptyItemCollection()
    let userVault <- LavaToken.createEmptyVault()

    acct.save<@LavaFlow.PlayersCollection>(<- playerStorage, to: /storage/PlayersCollection)
    acct.link<&{LavaFlow.PlayerReceiver}>(/public/PlayersCollection, target: /storage/PlayersCollection)
    acct.save<@LavaFlow.ItemsCollection>(<- itemStorage, to: /storage/ItemsCollection)
    acct.link<&{LavaFlow.ItemReceiver}>(/public/ItemsCollection, target: /storage/ItemsCollection)
    acct.save<@LavaToken.Vault>(<- userVault, to: /storage/LavaTokenVault)
    acct.link<&LavaToken.Vault{LavaToken.Receiver}>(/public/LavaTokenVault, target: /storage/LavaTokenVault)
    
    log("Account initialized")
  }
}
 