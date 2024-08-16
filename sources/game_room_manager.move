module chain_reaction_fun::game_room_manager {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    struct Room has key {
        id: u64,
        creator: address,
        bet_amount: u64,
        max_players: u8,
        current_players: vector<address>,
        vault: Coin<AptosCoin>,
        state: u8, // 0: Waiting, 1: Started, 2: Finished, 3: Abandoned
        created_at: u64,
    }

    struct RoomCounter has key {
        counter: u64,
    }

    const E_ROOM_NOT_FOUND: u64 = 1;
    const E_ROOM_FULL: u64 = 2;
    const E_ALREADY_JOINED: u64 = 3;
    const E_NOT_IN_ROOM: u64 = 4;
    const E_ROOM_STARTED: u64 = 5;
    const E_INSUFFICIENT_BALANCE: u64 = 6;

    public fun initialize(account: &signer) {
        move_to(account, RoomCounter { counter: 0 });
    }

    public fun create_room(creator: &signer, bet_amount: u64, max_players: u8): u64 acquires RoomCounter {
        let counter = borrow_global_mut<RoomCounter>(@chain_reaction_fun);
        let room_id = counter.counter;
        counter.counter = counter.counter + 1;

        let creator_address = signer::address_of(creator);
        let room = Room {
            id: room_id,
            creator: creator_address,
            bet_amount,
            max_players,
            current_players: vector::empty(),
            vault: coin::zero<AptosCoin>(),
            state: 0, // Waiting
            created_at: timestamp::now_seconds(),
        };

        move_to(creator, room);

        room_id
    }

    public fun join_room(player: &signer, room_id: u64) acquires Room {
        let room = borrow_global_mut<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);
        assert!(room.state == 0, E_ROOM_STARTED);
        assert!(vector::length(&room.current_players) < (room.max_players as u64), E_ROOM_FULL);

        let player_address = signer::address_of(player);
        assert!(!vector::contains(&room.current_players, &player_address), E_ALREADY_JOINED);

        vector::push_back(&mut room.current_players, player_address);
        place_bet(player, room.bet_amount, room_id);

        if (vector::length(&room.current_players) == (room.max_players as u64)) {
            room.state = 1; // Started
        }
    }

    public fun leave_room(player: &signer, room_id: u64): (bool, u64) acquires Room {
        let room = borrow_global_mut<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);

        let player_address = signer::address_of(player);
        assert!(vector::contains(&room.current_players, &player_address), E_NOT_IN_ROOM);

        let index = 0;
        let len = vector::length(&room.current_players);
        while (index < len) {
            if (*vector::borrow(&room.current_players, index) == player_address) {
                vector::remove(&mut room.current_players, index);
                break
            };
            index = index + 1;
        };

        if (room.state == 0) { // Waiting
            refund_bet(player_address, room.bet_amount, &mut room.vault);
            (true, 0)
        } else { // Started
            (false, room.bet_amount)
        }
    }

    public fun is_room_full(room_id: u64): bool acquires Room {
        let room = borrow_global<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);
        vector::length(&room.current_players) == (room.max_players as u64)
    }

    public fun close_room(room_id: u64) acquires Room {
        let Room { id, creator: _, bet_amount: _, max_players: _, current_players: _, vault, state: _, created_at: _ } = move_from<Room>(@chain_reaction_fun);
        assert!(id == room_id, E_ROOM_NOT_FOUND);
        coin::destroy_zero(vault);
    }

    fun place_bet(player: &signer, amount: u64, room_id: u64) acquires Room {
        let player_address = signer::address_of(player);
        assert!(coin::balance<AptosCoin>(player_address) >= amount, E_INSUFFICIENT_BALANCE);

        let room = borrow_global_mut<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);
        let bet_coins = coin::withdraw<AptosCoin>(player, amount);
        coin::merge(&mut room.vault, bet_coins);
    }

    fun refund_bet(player_address: address, amount: u64, vault: &mut Coin<AptosCoin>) {
        let refund = coin::extract(vault, amount);
        coin::deposit(player_address, refund);
    }

    public fun distribute_winnings(winner_address: address, amount: u64, room_id: u64) acquires Room {
        let room = borrow_global_mut<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);
        assert!(coin::value(&room.vault) >= amount, E_INSUFFICIENT_BALANCE);
        let winnings = coin::extract(&mut room.vault, amount);
        coin::deposit(winner_address, winnings);
    }

    public fun distribute_winnings_with_fee(room_id: u64, winner_address: address, fee_percentage: u8):u64 acquires Room {
        let room = borrow_global_mut<Room>(@chain_reaction_fun);
        assert!(room.id == room_id, E_ROOM_NOT_FOUND);

        let total_pot = coin::value(&room.vault);
        let fee_amount = (total_pot * (fee_percentage as u64)) / 100;
        let winnings = total_pot - fee_amount;

        let winner_coins = coin::extract(&mut room.vault, winnings);
        coin::deposit(winner_address, winner_coins);

        // Transferir la tarifa a la cuenta del contrato
        let fee_coins = coin::extract(&mut room.vault, fee_amount);
        coin::deposit(@chain_reaction_fun, fee_coins);

        // Retornamos la cantidad de la tarifa
        fee_amount
    }
}