import LavaFlow from 0x01

transaction{

  prepare(acct: AuthAccount) {
    let receiverWallet = getAccount(0x03)
    let playeCollectionRef = receiverWallet
      .getCapability(/public/PlayersCollection)!
      .borrow<&{LavaFlow.PlayerReceiver}>()!
    let playerMinter <- acct.load<@LavaFlow.PlayerMinter>(from: /storage/PlayerMinter)!
    if(playerMinter == nil){
      panic("no player minter")
    }
    let player <- playerMinter.mintPlayers(name: "Player 1", class: "Warrior")
    playeCollectionRef.deposit(token: <- player)
    acct.save<@LavaFlow.PlayerMinter>(<- playerMinter, to: /storage/PlayerMinter )
    log("Player minted and transfered")
  }
  
}
 