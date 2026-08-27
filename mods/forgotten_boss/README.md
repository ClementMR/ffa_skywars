# Forgotten boss arena

Build the arena, then stand at each location and run these as an `ffa_manager`:

1. `/boss pos1` and `/boss pos2` for the opposite arena corners.
2. `/boss entry` for the player arrival point inside the arena.
3. `/boss exit` for the player return point outside the arena.
4. `/boss spawn` for The Forgotten.

Open an event with `/boss open` (60-second warning by default), or `/boss open 180` for a three-minute warning. `/boss start` spawns the boss immediately. Players join with a Golden Ticket by using it or running `/boss enter`; `/boss leave` is always available.

Administrators can give tickets with `/boss ticket <player> [count]`, inspect the state with `/boss status`, list fighters with `/boss players`, and cancel an event with `/boss stop`.
