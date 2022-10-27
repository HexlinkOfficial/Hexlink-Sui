module hexlink::hexlink {
    use sui::transfer;
    use sui::object::{UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::event;

    struct AccountSet has copy, drop {
        name: vector<u8>,
        account: address
    }

    struct Wallet has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let accounts = table::new<vector<u8>, address>(ctx);
        transfer::transfer(accounts, tx_context::sender(ctx));
    }

    public fun getAccount(accounts: &Table<vector<u8>, address>, name: vector<u8>): &address {
        table::borrow(accounts, name)
    }

    public entry fun setAccount(
        accounts: &mut Table<vector<u8>, address>,
        name: vector<u8>,
        account: address,
        _ctx: &mut TxContext
    ) {
        if (table::contains(accounts, name)) {
            table::remove(accounts, name);
        };
        table::add(accounts, name, account);
        event::emit(AccountSet { name, account })
    }

    #[test]
    fun test_module_init() {
        use sui::test_scenario;

        let admin = @0xBABE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
            let accounts = test_scenario::take_from_sender<
                Table<vector<u8>, address>>(scenario);
            assert!(table::is_empty(&accounts), 1);
            test_scenario::return_to_sender(scenario, accounts)
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_accounts_set() {
        use sui::test_scenario;
        use sui::object;

        let admin = @0xBABE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        let ctx = tx_context::dummy();
        let wallet1 = Wallet {
            id: object::new(&mut ctx)
        };
        let addr1 = object::id_address(&wallet1);
        test_scenario::next_tx(scenario, admin);
        {
            let accounts = test_scenario::take_from_sender<Table<vector<u8>, address>>(scenario);
            setAccount(&mut accounts, b"alice@gmail.com", addr1, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, accounts)
        };

        test_scenario::next_tx(scenario, admin);
        {
            let accounts = test_scenario::take_from_sender<Table<vector<u8>, address>>(scenario);
            let account = getAccount(&accounts, b"alice@gmail.com");
            assert!(*account == addr1, 1);
            test_scenario::return_to_sender(scenario, accounts)
        };

        let wallet2 = Wallet {
            id: object::new(&mut ctx)
        };
        let addr2 = object::id_address(&wallet2);
        test_scenario::next_tx(scenario, admin);
        {
            let accounts = test_scenario::take_from_sender<Table<vector<u8>, address>>(scenario);
            setAccount(&mut accounts, b"alice@gmail.com", addr2, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, accounts)
        };

        test_scenario::next_tx(scenario, admin);
        {
            let accounts = test_scenario::take_from_sender<Table<vector<u8>, address>>(scenario);
            let account = getAccount(&accounts, b"alice@gmail.com");
            assert!(*account == addr2, 1);
            test_scenario::return_to_sender(scenario, accounts)
        };

        transfer::transfer(wallet1, admin);
        transfer::transfer(wallet2, admin);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_accounts_permission_control() {
        use sui::test_scenario;
        use sui::object;

        let admin = @0xBABE;
        let attacker = @0xFACE;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        let ctx = tx_context::dummy();
        let wallet = Wallet {
            id: object::new(&mut ctx)
        };
        let addr = object::id_address(&wallet);
        test_scenario::next_tx(scenario, attacker);
        {
            // will abort with code 3 here
            let accounts = test_scenario::take_from_sender<Table<vector<u8>, address>>(scenario);
            setAccount(&mut accounts, b"alice@gmail.com", addr, test_scenario::ctx(scenario));
            test_scenario::return_to_sender(scenario, accounts)
        };

        transfer::transfer(wallet, admin);
        test_scenario::end(scenario_val);
    }
}