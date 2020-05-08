import LavaToken from 0x02
transaction {

  prepare(lavaTokenAccount: AuthAccount, lavaFlowAccount: AuthAccount) {
    let minter <- lavaTokenAccount.load<@LavaToken.LavaTokenMinter>(from: /storage/MainMinter)!
    lavaFlowAccount.save<@LavaToken.LavaTokenMinter>(<- minter, to: /storage/LavaTokenMinter)
    log("Minter transfered")
  }

}
 