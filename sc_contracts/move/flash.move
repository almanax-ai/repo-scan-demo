module challenge::flash {

    use aptos_framework::signer;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::{
        Self,
        FungibleAsset,
        MintRef,
        BurnRef,
        TransferRef,
        Metadata
    };
    use aptos_framework::option;
    use aptos_framework::string::utf8;

    const ASSET_SYMBOL: vector<u8> = b"JBZ";

    struct ChallengeStatus has key {
        loan: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Management has key {
        extend_ref: ExtendRef,
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
        metadata: Object<Metadata>,
    }

    public entry fun initialize(account: &signer) {
        let account_address = signer::address_of(account);
        assert!(account_address == @challenger, 0);

        let constructor_ref = &object::create_named_object(account, ASSET_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(constructor_ref,
            option::none(),
            utf8(ASSET_SYMBOL),
            utf8(ASSET_SYMBOL),
            8,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com"),);

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let tokens = fungible_asset::mint(&mint_ref, 1337);
        let metadata = fungible_asset::mint_ref_metadata(&mint_ref);
        let management =
            Management {
                extend_ref: object::generate_extend_ref(constructor_ref),
                mint_ref,
                burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
                metadata,
            };

        fungible_asset::deposit(primary_fungible_store::ensure_primary_store_exists(
                    @challenger, fungible_asset::asset_metadata(&tokens)),
            tokens);

        move_to(account, management);
        move_to(account, ChallengeStatus { loan: false, });
    }

    public fun flash_loan(_account: &signer, amount: u64): FungibleAsset acquires Management, ChallengeStatus {
        let challenge_status = borrow_global_mut<ChallengeStatus>(@challenger);
        challenge_status.loan = true;
        let management = borrow_global<Management>(@challenger);

        primary_fungible_store::withdraw_with_ref(&management.transfer_ref, @challenger,
            amount)
    }

    public fun repay(_account: &signer, fa: FungibleAsset) acquires Management, ChallengeStatus {
        let challenge_status = borrow_global_mut<ChallengeStatus>(@challenger);
        challenge_status.loan = false;
        let management = borrow_global<Management>(@challenger);
        primary_fungible_store::deposit_with_ref(&management.transfer_ref, @challenger, fa);
    }

    public entry fun is_solved(_account: &signer) acquires Management, ChallengeStatus {
        let challenge_status = borrow_global_mut<ChallengeStatus>(@challenger);
        let management = borrow_global<Management>(@challenger);
        assert!(!challenge_status.loan, 2);
        assert!(primary_fungible_store::balance(@challenger, management.metadata) == 0, 3);

    }
}
