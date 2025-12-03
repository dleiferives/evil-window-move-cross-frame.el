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



## Install

My personal install is configured as such (I use doom emacs).

``` emacs-lisp
; packages.el file
(package! evil-window-move-cross-frame
  :recipe (:type git
           :host github
           :repo "dleiferives/evil-window-move-cross-frame.el"
           :files ("evil-window-move-cross-frame.el")))
       
; config.el file       
(use-package! evil-window-move-cross-frame
  :after evil
  :init
  (setq evil-window-move-cross-frame-enable-default-keybindings nil)
  (setq evil-window-move-cross-frame-normal-state-keys nil))

(map! :leader
      (:prefix ("w" . "window")
       :desc "Move to window left" "h" #'evil-window-move-cross-frame-left
       :desc "Move to window right" "l" #'evil-window-move-cross-frame-right
       :desc "Move to window down" "j" #'evil-window-move-cross-frame-down
       :desc "Move to window up" "k" #'evil-window-move-cross-frame-up))
```


Though a more standard `use-package` install could be done with the following:

``` emacs-lisp
(use-package evil-window-move-cross-frame
  :after evil
  :init
  (setq evil-window-move-cross-frame-enable-default-keybindings nil)
  (setq evil-window-move-cross-frame-normal-state-keys nil)
  :config
  (with-eval-after-load 'evil
    (define-key evil-normal-state-map (kbd "C-c a") #'evil-window-move-cross-frame-left)
    (define-key evil-normal-state-map (kbd "C-c d") #'evil-window-move-cross-frame-right)
    (define-key evil-normal-state-map (kbd "C-c w") #'evil-window-move-cross-frame-up)
    (define-key evil-normal-state-map (kbd "C-c s") #'evil-window-move-cross-frame-down)))
```

--

### Notes

Written because I just got some new monitors and I was getting annoyed by the
movement between the monitors. When having multiple frames open in Emacs. I may
have given Claude the wheel for a while there, so if there are some strange
things its probably due to that.
