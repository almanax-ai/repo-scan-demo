module 0x42::example {
  struct Object has key{
    data: vector<u8>
  }
 
  public fun delete(user: &signer, obj: Object) {
    let Object { data } = obj;
  }
}