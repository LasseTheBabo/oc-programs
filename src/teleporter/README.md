Relay Servers are required because a server can only hold one Linked Card.
Servers, Clients and Relay Servers need minitel installed over ´oppm install minitel-util´

## Requirements
### Server
- T2 Server
- T2 CPU
- 2x T2
- Linked Card (connection to other deleporters)
- Network Card (connection to relay servers)

### Client (Deleporter)
- T2 Server
- T2 CPU
- 2x T2 RAM
- Linked Card (connection to server)
- T2 Screen
- 1x Storage Bus
- 1x Import Bus
- 1x Redstone I/O
- Spatial IO Setup (all deleporters need the same card dimensions e.g. 3x3x3)
- Spatial IO Card in the input slot of the Spatial IO block

### Relay Server
- server requirements or higher
- Linked Card
- Network Card

## Spatial IO cell transport protocol
- Phase 1 (A)
    - spatial pulse
    - import  on
- Phase 2 (B)
    - spatial pulse
    - storage on
- Phase 3 (A)
    - wait for empty
    - import  off
- Phase 4 (B)
    - storage off
    - import  on
- Phase 5 (A)
    - storage on
    - wait for full
    - storage off
- Phase 6 (B)
    - import  off
    - spatial pulse
    - import  on
    - storage on
    - wait 1 second
    - import  off
    - storage off