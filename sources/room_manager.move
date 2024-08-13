module chain_reaction_fun::room_manager {
    use std::signer;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    
    struct Room has key {
        id: u64,
        creator: address,
        players: vector<address>,
        max_players: u8,
        bet_amount: u64,
        state: u8, // 0: Waiting, 1: Started, 2: Finished, 3: Abandoned
    }

    struct RoomList has key {
        rooms: vector<Room>,
        room_counter: u64,
    }

    #[event]
    struct RoomCreated has drop, store {
        room_id: u64,
        creator: address,
        max_players: u8,
        bet_amount: u64,
    }

    #[event]
    struct PlayerJoined has drop, store {
        room_id: u64,
        player: address,
    }

    const ENO_ROOM: u64 = 1;
    const EROOM_FULL: u64 = 2;
    const EROOM_STARTED: u64 = 3;
    const ENOT_PLAYER: u64 = 4;

    public fun initialize(account: &signer) {
        move_to(account, RoomList {
            rooms: vector::empty(),
            room_counter: 0,
        });
    }

    public entry fun create_room(account: &signer, max_players: u8, bet_amount: u64) acquires RoomList {
        let sender = signer::address_of(account);
        let room_list = borrow_global_mut<RoomList>(@admin_address);

        let new_room = Room {
            id: room_list.room_counter,
            creator: sender,
            players: vector::singleton(sender),
            max_players,
            bet_amount,
            state: 0,
        };

        vector::push_back(&mut room_list.rooms, new_room);
        room_list.room_counter = room_list.room_counter + 1;

        coin::transfer<AptosCoin>(account, @admin_address, bet_amount);

        event::emit(RoomCreated {
            room_id: room_list.room_counter - 1,
            creator: sender,
            max_players,
            bet_amount,
        });
    }

    public entry fun join_room(account: &signer, room_id: u64) acquires RoomList {
        let sender = signer::address_of(account);
        let room_list = borrow_global_mut<RoomList>(@admin_address);
        let room = vector::borrow_mut(&mut room_list.rooms, room_id);

        assert!(room.state == 0, EROOM_STARTED);
        assert!(vector::length(&room.players) < (room.max_players as u64), EROOM_FULL);

        vector::push_back(&mut room.players, sender);
        
        coin::transfer<AptosCoin>(account, @admin_address, room.bet_amount);

        if (vector::length(&room.players) == (room.max_players as u64)) {
            room.state = 1; // Cambiar a estado "Started"
        };

        event::emit(PlayerJoined {
            room_id,
            player: sender,
        });
    }

    public fun leave_room(account: &signer, room_id: u64) acquires RoomList {
        let sender = signer::address_of(account);
        let room_list = borrow_global_mut<RoomList>(@admin_address);
        let room = vector::borrow_mut(&mut room_list.rooms, room_id);

        let (is_in_room, index) = vector::index_of(&room.players, &sender);
        assert!(is_in_room, ENOT_PLAYER);

        if (room.state == 0) {
            coin::transfer<AptosCoin>(@admin_address, sender, room.bet_amount);
            vector::remove(&mut room.players, index);

            if (vector::is_empty(&room.players)) {
                room.state = 3; // Cambiar a estado "Abandoned"
            }
        } else if (room.state == 1) {
            vector::remove(&mut room.players, index);
        }
    }

    #[view]
    public fun get_room_info(room_id: u64): (address, vector<address>, u8, u64, u8) acquires RoomList {
        let room_list = borrow_global<RoomList>(@admin_address);
        assert!(room_id < vector::length(&room_list.rooms), ENO_ROOM);
        let room = vector::borrow(&room_list.rooms, room_id);
        (room.creator, *&room.players, room.max_players, room.bet_amount, room.state)
    }

    #[test(admin = @admin_address, player1 = @0x1, player2 = @0x2)]
    public entry fun test_room_flow(admin: signer, player1: signer, player2: signer) acquires RoomList {
        initialize(&admin);
        
        create_room(&player1, 2, 100);
        
        let (creator, players, max_players, bet_amount, state) = get_room_info(0);
        assert!(creator == signer::address_of(&player1), 0);
        assert!(vector::length(&players) == 1, 1);
        assert!(max_players == 2, 2);
        assert!(bet_amount == 100, 3);
        assert!(state == 0, 4);

        join_room(&player2, 0);
        
        let (_, players, _, _, state) = get_room_info(0);
        assert!(vector::length(&players) == 2, 5);
        assert!(state == 1, 6);
    }
}