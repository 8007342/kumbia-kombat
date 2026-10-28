## ADDED Requirements

### Requirement: Discreet desktop AutoPlay demonstration
The game SHALL expose a small corner AutoPlay toggle with a descriptive tooltip
and accessible toggled state. Enabling it from the ready screen SHALL start the
music through that user gesture. Automatic runs SHALL remain visibly identified.
The demo SHALL use normal tap judgment and optional flourish APIs, deliberately
mix successful and failed response phrases, and eventually clear the currently
playable rooms without directly changing progress or crowd state.

#### Scenario: observe an imperfect performance

- WHEN a desktop user enables AutoPlay
- THEN music starts and the demo performs taps and directional adornments
- AND occasional failed phrases soften nearby crowd interest before recovery
- AND full-tier proof remains required before each room's musical exit.

#### Scenario: pause or take over

- WHEN AutoPlay is disabled, the game pauses, or a room handoff begins
- THEN pending automated gestures are cancelled
- AND count-in and repeated frame updates cannot grant duplicate actions
- AND disabling the toggle returns control to normal input.
