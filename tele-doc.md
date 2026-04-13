- Phase 1
- A    spat    pulse
- A    import  on

- Phase 2
- B    spat    pulse
- B    storage on

- Phase 3
- A    wait for empty
- A    import  off

- Phase 4
- B    storage off
- B    import  on

- Phase 5
- A    storage on
- A    wait for full
- A    storage off

- Phase 6
- B    import  off
- B    spat    pulse
- B    import  on
- B    storage on
- B    wait 0.5 seconds
- B    import  off
- B    storage off