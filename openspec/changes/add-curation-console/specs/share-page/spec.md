## ADDED Requirements

### Requirement: Share route
The game SHALL serve a share page at `/qr` (with or without a trailing slash)
on the production deploy and on the local preview, and from `/?page=qr` and
`/#/qr`.

#### Scenario: Production path
- **WHEN** a browser opens `https://kumbias.tlatoani.net/qr`
- **THEN** the share page loads, not the game

### Requirement: Scannable code for the game
The share page SHALL show a QR code whose content is exactly
`https://kumbias.tlatoani.net`, drawn dark on light with at least a four-module
light quiet zone on every side, nothing drawn over the code, error correction
level Q or higher, and each module at least 8 logical pixels on a 360-wide
phone. The address SHALL also be shown as text.

#### Scenario: Drawn as encoded
- **WHEN** the code is rendered
- **THEN** every module's centre is dark exactly where the encoder's module is dark, and the quiet zone is light all round

#### Scenario: Decodes outside the app
- **WHEN** the rendered code is read by a standard decoder (zxing), as drawn, shrunk to 120 pixels, and blurred
- **THEN** each read returns `https://kumbias.tlatoani.net`

### Requirement: Framed by the game
The share page SHALL show the game's title and the party's characters from the
shipping sprite atlases (Mācron, the Gatekeeper, BlinBlin, the Pool Player and
others), dancing on the beat, on a warm night-party background. A character
whose art fails to load SHALL be left out without affecting the code.

#### Scenario: Missing art
- **WHEN** the sprite manifests cannot load
- **THEN** the title, the code and the address still show
