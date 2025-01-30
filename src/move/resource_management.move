module 0x42::example {
  public fun get_order_by_id(order_id: u64): Option<Order> acquires OrderStore {
    let order_store = borrow_global_mut<OrderStore>(@admin);
    let i = 0;
    let len = vector::length(&order_store.orders);
    while (i < len) {
      let order = vector::borrow<Order>(&order_store.orders, i);
      if (order.id == order_id) {
        return option::some(*order)
      };
      i = i + 1;
    };
    return option::none<Order>()
  }
  //O(1) in time and gas operation.
  public entry fun create_order(buyer: &signer) { /* ... */ }
}