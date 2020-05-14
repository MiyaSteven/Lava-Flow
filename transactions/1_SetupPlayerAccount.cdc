import LavaFlow from 0x01
// Setup players account
// We need at least to setup two players account
// Note: Use account 0x02 & 0x03
transaction{

  prepare(acct: AuthAccount) {
    let playerStorage <- LavaFlow.createEmptyPlayerCollection()
    let itemStorage <- LavaFlow.createEmptyItemCollection()
    acct.save<@LavaFlow.PlayersCollection>(<- playerStorage, to: /storage/PlayersCollection)
    acct.link<&{LavaFlow.PlayerReceiver}>(/public/PlayersCollection, target: /storage/PlayersCollection)
    acct.save<@LavaFlow.ItemsCollection>(<- itemStorage, to: /storage/ItemsCollection)
    acct.link<&{LavaFlow.ItemReceiver}>(/public/ItemsCollection, target: /storage/ItemsCollection)
    log("Account initialized")
  }
  
}
 