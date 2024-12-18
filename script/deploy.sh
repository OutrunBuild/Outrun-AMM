source ../.env
forge clean
forge build

forge script OutrunAMMScript.s.sol:OutrunAMMScript --rpc-url bsc_testnet \
    --with-gas-price 3000000000 \
    --optimize --optimizer-runs 100000 \
    --via-ir \
    --broadcast --ffi -vvvv \
    --verify 

# forge script OutrunAMMScript.s.sol:OutrunAMMScript --rpc-url base_sepolia \
#     --with-gas-price 1200000 \
#     --optimize --optimizer-runs 100000 \
#     --via-ir \
#     --broadcast --ffi -vvvv \
#     --verify 

# forge script OutrunAMMScript.s.sol:OutrunAMMScript --rpc-url mantle_sepolia \
#     --with-gas-price 20000000 \
#     --optimize --optimizer-runs 100000 \
#     --via-ir \
#     --broadcast --ffi -vvvv \
#     --verify 
