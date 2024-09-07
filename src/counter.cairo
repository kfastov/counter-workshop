#[starknet::interface]
pub trait ICounter<TState> {
    fn get_counter(self: @TState) -> u32;
    fn increase_counter(ref self: TState);
}

#[starknet::contract]
pub mod counter_contract {
    use OwnableComponent::InternalTrait;
use starknet::event::EventEmitter;
    use starknet::ContractAddress;
    use super::ICounter;
    use openzeppelin::access::ownable::OwnableComponent;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage{
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }

    #[event]
    #[derive(starknet::Event, Drop)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(starknet::Event, Drop)]
    struct CounterIncreased {
        value: u32
    }

    #[abi(embed_v0)]
    impl ICounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }
        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();

            let kill_switch = IKillSwitchDispatcher {
                contract_address: self.kill_switch.read(),
            };

            assert!(!kill_switch.is_active(), "Kill Switch is active");

            self.counter.write(self.counter.read() + 1);
            self.emit(CounterIncreased { value: self.counter.read() });
        }
    }
}