<img width="1142" alt="Image" src="https://github.com/user-attachments/assets/8ef25c07-4f56-4e45-9ef4-38b0f18d4a42" />


The [loot tables](https://pillarsofeternity.fandom.com/wiki/Random_loot_tables) on the wiki are only calculated for when the player is at slot 0. By using the wiki data and redoing the math for other slots, we can see many more opportunities to get the desired rolls.

The script runs within Neovim (open ```main.lua``` and do a ```:so```, and change what you want to search for around line 136). It can be slightly modified to run in other environments, but the backend of bit operations in Lua may or may not be identical across different setups. You can uncomment the tests if you want to migrate.

The output is in the format day(player slots), where the slot is 0-based. Please refer to the wiki for details on how the random rolls work in PoE1.
