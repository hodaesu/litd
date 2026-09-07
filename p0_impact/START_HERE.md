# Start P0 Impact on Windows

1. Checkout branch `p0-impact`.
2. Open the folder `p0_impact` in Godot.
3. Run the project (`F6`/`F5`).
4. Use **Coup d’épaule** on the adjacent Rampant.
5. Observe whether the Rampant moves one free cell, collides with the wall on the blocked second push, loses extra VIT/POST, and becomes **À TERRE** when POST reaches 0.
6. Use `P0_CHECKLIST.md` to judge the result.

Do not expand the prototype before this interaction is accepted. The first useful changes are only camera angle/FOV, timing, push readability, collision impact, Posture values, and touch target sizing.
