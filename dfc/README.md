# DFC Control
## Requirements
- DFC Emitter (NTM)
- Redstone I/O
- Chat Box (Computronics)
- Biometric Reader (OpenSecurity) only required for s1 core

## S1.5 usage
- `#dfc on` enable the DFC if it isn't locked
- `#dfc off` disables the DFC
- `#dfc power` sets the emitter power to a value between 1-100
- `#dfc unlock` unlocks the DFC after an emergency
- `#dfc angry true/false` enables/disables the second core. `true` must be accepted with ´#dfc accept´
- `#dfc accept` accepts the angry request. Player must be in the `allowedUsers` list
- `#dfc info` gives information about the DFC: active, angry, locked and emitter power
- `#dfc panic` turns off the DFC, locks it and sets angry to false