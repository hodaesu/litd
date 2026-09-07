# P0 Impact — acceptance checklist

## Automatically validated in Godot 4.3 CI

- [x] Basic attack changes VIT and POST
- [x] Coup d’épaule deals 12 VIT / 22 POST before collision
- [x] Coup d’épaule pushes the Rampant by up to 2 cells
- [x] A blocked remaining push becomes wall collision
- [x] Each blocked push cell adds 6 VIT / 12 POST in this P0
- [x] POST reaching 0 puts the Rampant À TERRE
- [x] Rampant performs a minimal move/attack turn
- [x] POST recovers 15% at the start of the next player cycle
- [x] Reset returns the test to its canonical starting state
- [x] Push 2 without obstacle adds no collision damage
- [x] Grid-edge blockage converts only unfulfilled Push into collision
- [x] Non-adjacent Coup d’épaule is rejected without consuming the turn
- [x] Coup d’épaule cannot hit an already downed Rampant
- [x] Invalid/occupied movement is rejected without consuming the turn
- [x] Player movement is rejected outside the player turn
- [x] Posture recovery cannot exceed maximum Posture

## Still requires interactive visual/touch validation

- [ ] 6×5 grid is comfortably visible in one view on the target screen
- [ ] Sahen and Rampant are immediately distinguishable by silhouette/readability
- [ ] Tap/touch reliably selects the intended adjacent tile on the target phone aspect ratio
- [ ] Camera briefly emphasizes the action and returns without losing tactical context
- [ ] Push speed makes displacement physically readable
- [ ] Collision impact is understandable without reading the numeric message
- [ ] À TERRE remains visually obvious after the impact
- [ ] UI/button sizes are comfortable on iPhone in landscape

## P0 success test

Without reading a rules explanation, a tester should understand:

1. Sahen hits the Rampant.
2. The Rampant is physically displaced.
3. The wall stops the remaining displacement.
4. The wall collision adds a consequence.
5. Posture break can put the Rampant down.

The automated suite proves the rules above are executed correctly. It cannot prove that these five events are visually obvious or satisfying to a human player.

If one of these five points is unclear during the interactive test, the P0 is not accepted even if all CI tests are green.
