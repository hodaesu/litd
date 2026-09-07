# P0 Impact — acceptance checklist

## Required behavior

- [ ] 6×5 grid visible in one view
- [ ] Sahen and Rampant are immediately distinguishable
- [ ] Tap/click selects a valid adjacent movement tile
- [ ] Basic attack changes VIT and POST
- [ ] Coup d’épaule deals 12 VIT / 22 POST before collision
- [ ] Coup d’épaule pushes the Rampant by up to 2 cells
- [ ] A blocked remaining push becomes wall collision
- [ ] Each blocked push cell adds 6 VIT / 12 POST in this P0
- [ ] POST reaching 0 puts the Rampant À TERRE
- [ ] Camera briefly emphasizes the action and returns to the full grid
- [ ] Rampant performs a minimal move/attack turn
- [ ] POST recovers 15% at the start of the next player cycle
- [ ] Reset returns the test to its canonical starting state

## P0 success test

Without reading a rules explanation, a tester should understand:

1. Sahen hits the Rampant.
2. The Rampant is physically displaced.
3. The wall stops the remaining displacement.
4. The wall collision adds a consequence.
5. Posture break can put the Rampant down.

If one of these five points is unclear, the P0 is not accepted even if the code is technically correct.
