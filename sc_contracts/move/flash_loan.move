module 0x42::example {
  struct Coin<T> {
    amount: u64
  }
 
  struct Receipt {
    amount: u64
  }
 
  public fun flash_loan<T>(user: &signer, amount: u64): (Coin<T>, Receipt) {
    let (coin, fee) = withdraw(user, amount);
    ( coin, Receipt {amount: amount + fee} )
  }
 
  public fun repay_flash_loan<T>(rec: Receipt, coins: Coin<T>) {
    let Receipt{ amount } = rec;
    assert!(coin::value<T>(&coin) >= rec.amount, 0);
    deposit(coin);
  }
}