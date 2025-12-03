# evil-window-move-cross-frame

Cross-frame window movement for Evil using absolute pixel geometry. When Evil
says “no window” in a direction, this package searches across frames and jumps
to the nearest window based on top-left coordinates.

- Works with multiple frames
- Ignores child frames (e.g., corfu popups)
- Verbose debug mode for troubleshooting
- Customizable keybindings (defaults to C-w h/j/k/l)

*Note* Movement computed by the top left corner of the destination windows, so
it will default accordingly.

--

Written because I just got some new monitors and I was getting annoyed by the
movement between the monitors. When having multiple frames open in Emacs. I may
have given Claude the wheel for a while there, so if there are some strange
things its probably due to that.
