;;; evil-window-move-cross-frame.el --- Move across frames with Evil using geometry -*- lexical-binding: t; -*-
;;
;; Author: Dylan Leifer-Ives <dleiferives@gmail.com>
;; Maintainer: Dylan Leifer-Ives <dleiferives@gmail.com>
;; URL: https://github.com/dleiferives/evil-window-move-cross-frame
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (evil "1.15.0") (seq "2.24"))
;; Keywords: convenience, windows, frames, evil
;;
;; This file is NOT part of GNU Emacs.
;;
;;; Commentary:
;;
;; evil-window-move-cross-frame provides smarter window movement for Evil users:
;; when Evil reports "no window" in a direction, this package searches across
;; all visible frames and picks the nearest window in that direction using
;; absolute pixel geometry (top-left corner).
;;
;; Features:
;; - Cross-frame movement for left/right/up/down (C-w h/j/k/l by default)
;; - Geometry-based fallbacks when Evil cannot move
;; - Optional verbose debug logging
;; - Customizable keybindings (install defaults or your own)
;;
;; Quick start (use-package):
;;
;;   (use-package evil-window-move-cross-frame
;;     :after evil
;;     :custom
;;     ;; Enable logs if you need to debug movement
;;     ;; (evil-window-move-cross-frame-debug-mode t)
;;     ;; Prefer geometry even if Evil could move within a frame
;;     ;; (evil-window-move-cross-frame-force-geometry-when-available t)
;;     ;; Control whether default keys are installed:
;;     ;; (evil-window-move-cross-frame-enable-default-keybindings t)
;;     ;; Provide your own keys (disables the defaults if you also set the flag to nil)
;;     ;; (evil-window-move-cross-frame-normal-state-keys
;;     ;;  '(("M-h" . evil-window-move-cross-frame-left)
;;     ;;    ("M-l" . evil-window-move-cross-frame-right)
;;     ;;    ("M-k" . evil-window-move-cross-frame-up)
;;     ;;    ("M-j" . evil-window-move-cross-frame-down)))
;;     :config
;;     ;; Apply the configured keybindings (default or custom)
;;     (evil-window-move-cross-frame-setup-keybindings))
;;
;; Notes:
;; - Child frames (like corfu popups) are ignored as movement targets.
;; - Movement uses window-absolute-pixel-edges and each window's top-left point.
;;
;;; License:
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;; Code:

(require 'evil)
(require 'seq)

(defgroup evil-window-move-cross-frame nil
  "Geometry-based Evil window movement across frames."
  :group 'convenience)

(defcustom evil-window-move-cross-frame-debug-mode nil
  "If non-nil, enable verbose logging."
  :type 'boolean)

(defcustom evil-window-move-cross-frame-force-geometry-when-available nil
  "If non-nil, always use geometry-based selection instead of Evil, even if Evil could move."
  :type 'boolean)

;; Keybinding customization
(defcustom evil-window-move-cross-frame-enable-default-keybindings t
  "If non-nil, install default Evil keybindings (C-w h/j/k/l)."
  :type 'boolean)

(defcustom evil-window-move-cross-frame-normal-state-keys
  '(("C-w h" . evil-window-move-cross-frame-left)
    ("C-w l" . evil-window-move-cross-frame-right)
    ("C-w k" . evil-window-move-cross-frame-up)
    ("C-w j" . evil-window-move-cross-frame-down))
  "Alist of keybindings for evil-normal-state-map.
Each entry is (KEYSTRING . COMMAND). Set to nil to disable installing any keys."
  :type '(repeat (cons (string :tag "Key") (function :tag "Command"))))

(defun evil-window-move-cross-frame--log (fmt &rest args)
  (when evil-window-move-cross-frame-debug-mode
    (apply #'message (concat "[EWMCF] " fmt) args)))

(defun evil-window-move-cross-frame--frame-id (fr)
  (format "#<frame %s @%s>"
          (or (frame-parameter fr 'name) "?")
          (frame-parameter fr 'window-id)))

(defun evil-window-move-cross-frame--win-id (w)
  (format "#<win %s on %s>"
          (buffer-name (window-buffer w))
          (evil-window-move-cross-frame--frame-id (window-frame w))))

(defun evil-window-move-cross-frame--safe-num (x)
  (if (numberp x) x 0))

(defun evil-window-move-cross-frame--window-top-left (win)
  (pcase-let ((`(,l ,t ,_r ,_b) (window-absolute-pixel-edges win)))
    (cons (evil-window-move-cross-frame--safe-num l)
          (evil-window-move-cross-frame--safe-num t))))

(defun evil-window-move-cross-frame--dump-frames-and-windows ()
  (when evil-window-move-cross-frame-debug-mode
    (evil-window-move-cross-frame--log "Frames and windows:")
    (dolist (fr (frame-list))
      (when (frame-live-p fr)
        (evil-window-move-cross-frame--log "  Frame %s selected-window=%s"
                                           (evil-window-move-cross-frame--frame-id fr)
                                           (condition-case e
                                               (evil-window-move-cross-frame--win-id (frame-selected-window fr))
                                             (error (format "ERR %S" e))))
        (dolist (w (condition-case _
                       (window-list fr 'never nil)
                     (error (window-list fr nil nil))))
          (when (window-live-p w)
            (let ((pt (evil-window-move-cross-frame--window-top-left w)))
              (evil-window-move-cross-frame--log "    %s tl=%S buf=%s"
                                                 (evil-window-move-cross-frame--win-id w)
                                                 pt
                                                 (buffer-name (window-buffer w))))))))))

(defun evil-window-move-cross-frame--all-windows ()
  "All live windows across frames, excluding minibuffer and child frames."
  (apply #'append
         (mapcar
          (lambda (fr)
            (when (and (frame-live-p fr)
                       (not (frame-parameter fr 'parent-frame))) ; ignore child frames
              (condition-case _
                  (window-list fr 'never nil)
                (error (window-list fr nil nil)))))
          (frame-list))))

(defun evil-window-move-cross-frame--windows-in-direction-topleft (cur-win direction)
  (let* ((cur-pt (evil-window-move-cross-frame--window-top-left cur-win))
         (cx (car cur-pt))
         (cy (cdr cur-pt))
         (all (evil-window-move-cross-frame--all-windows)))
    (evil-window-move-cross-frame--log "Current %s tl=%S on %s"
                                       (evil-window-move-cross-frame--win-id cur-win)
                                       cur-pt
                                       (evil-window-move-cross-frame--frame-id (window-frame cur-win)))
    (evil-window-move-cross-frame--log "Scanning %d windows across frames..." (length all))
    (dolist (w all)
      (evil-window-move-cross-frame--log "  Seen %s tl=%S"
                                         (evil-window-move-cross-frame--win-id w)
                                         (evil-window-move-cross-frame--window-top-left w)))
    (let ((cands
           (seq-filter
            (lambda (w)
              (and (window-live-p w)
                   (not (eq w cur-win))
                   (pcase-let ((`(,x . ,y) (evil-window-move-cross-frame--window-top-left w)))
                     (pcase direction
                       ('left  (< x cx))
                       ('right (> x cx))
                       ('up    (< y cy))
                       ('down  (> y cy))
                       (_ nil)))))
            all)))
      (evil-window-move-cross-frame--log "Direction=%s candidates (%d):" direction (length cands))
      (dolist (w cands)
        (evil-window-move-cross-frame--log "  cand %s tl=%S"
                                           (evil-window-move-cross-frame--win-id w)
                                           (evil-window-move-cross-frame--window-top-left w)))
      cands)))

(defun evil-window-move-cross-frame--axis-dist (cx cy x y direction)
  (pcase direction
    ('left  (max 0 (- cx x)))
    ('right (max 0 (- x cx)))
    ('up    (max 0 (- cy y)))
    ('down  (max 0 (- y cy)))))

(defun evil-window-move-cross-frame--ortho-dist (cx cy x y direction)
  (pcase direction
    ((or 'left 'right) (abs (- (evil-window-move-cross-frame--safe-num y)
                               (evil-window-move-cross-frame--safe-num cy))))
    ((or 'up 'down)    (abs (- (evil-window-move-cross-frame--safe-num x)
                               (evil-window-move-cross-frame--safe-num cx))))
    (_ 0)))

(defun evil-window-move-cross-frame--select-best-window-topleft (cur-win direction)
  (let* ((cur-pt (evil-window-move-cross-frame--window-top-left cur-win))
         (cx (car cur-pt))
         (cy (cdr cur-pt))
         (cands (evil-window-move-cross-frame--windows-in-direction-topleft cur-win direction))
         (best nil))
    (when cands
      (evil-window-move-cross-frame--log "Scoring candidates:")
      (dolist (w cands)
        (pcase-let ((`(,x . ,y) (evil-window-move-cross-frame--window-top-left w)))
          (let ((d (evil-window-move-cross-frame--axis-dist cx cy x y direction))
                (o (evil-window-move-cross-frame--ortho-dist cx cy x y direction)))
            (evil-window-move-cross-frame--log "  %s tl=%S axis=%d ortho=%d"
                                               (evil-window-move-cross-frame--win-id w)
                                               (cons x y) d o)))))
    (setq best
          (when cands
            (car
             (sort
              (copy-sequence cands)
              (lambda (a b)
                (pcase-let* ((`(,ax . ,ay) (evil-window-move-cross-frame--window-top-left a))
                             (`(,bx . ,by) (evil-window-move-cross-frame--window-top-left b))
                             (da (evil-window-move-cross-frame--axis-dist cx cy ax ay direction))
                             (db (evil-window-move-cross-frame--axis-dist cx cy bx by direction))
                             (oa (evil-window-move-cross-frame--ortho-dist cx cy ax ay direction))
                             (ob (evil-window-move-cross-frame--ortho-dist cx cy bx by direction)))
                  (or (< da db)
                      (and (= da db) (< oa ob)))))))))
    (if best
        (evil-window-move-cross-frame--log "Best %s tl=%S on %s"
                                           (evil-window-move-cross-frame--win-id best)
                                           (evil-window-move-cross-frame--window-top-left best)
                                           (evil-window-move-cross-frame--frame-id (window-frame best)))
      (evil-window-move-cross-frame--log "Best nil"))
    best))

(defun evil-window-move-cross-frame--focus-frame (fr)
  (when (frame-live-p fr)
    (evil-window-move-cross-frame--log "  Focusing frame: %s"
                                       (evil-window-move-cross-frame--frame-id fr))
    (select-frame-set-input-focus fr)
    (raise-frame fr)
    fr))

(defun evil-window-move-cross-frame--select-window-and-log (w)
  (when (and w (window-live-p w))
    (let* ((orig-fr (selected-frame))
           (target-fr (window-frame w))
           (inhibit-redisplay t)
           (inhibit-quit t)
           (cursor-in-echo-area cursor-in-echo-area)
           (mouse-autoselect-window nil)
           (focus-follows-mouse nil))
      (when (not (eq orig-fr target-fr))
        (evil-window-move-cross-frame--log "Switching frames: %s -> %s"
                                           (evil-window-move-cross-frame--frame-id orig-fr)
                                           (evil-window-move-cross-frame--frame-id target-fr))
        (evil-window-move-cross-frame--focus-frame target-fr))
      (select-window w)
      (evil-window-move-cross-frame--log "Selected %s tl=%S"
                                         (evil-window-move-cross-frame--win-id w)
                                         (evil-window-move-cross-frame--window-top-left w)))))

(defun evil-window-move-cross-frame--try-geometry-move (direction)
  (let ((cur (selected-window)))
    (evil-window-move-cross-frame--log "Attempting evil move %s from %s"
                                       direction (evil-window-move-cross-frame--win-id cur))
    (condition-case err
        (progn
          (pcase direction
            ('left  (evil-window-left 1))
            ('right (evil-window-right 1))
            ('up    (evil-window-up 1))
            ('down  (evil-window-down 1)))
          (evil-window-move-cross-frame--log "Evil move %s succeeded to %s"
                                             direction (evil-window-move-cross-frame--win-id (selected-window))))
      (error
       (evil-window-move-cross-frame--log "Evil move %s errored: %S" direction err)
       (evil-window-move-cross-frame--dump-frames-and-windows)
       (let ((alt (evil-window-move-cross-frame--select-best-window-topleft cur direction)))
         (if alt
             (evil-window-move-cross-frame--select-window-and-log alt)
           (user-error "No geometric candidate for %s direction" direction)))))))

(defun evil-window-move-cross-frame--evil-move (direction)
  (if evil-window-move-cross-frame-force-geometry-when-available
      (let* ((cur (selected-window))
             (_ (evil-window-move-cross-frame--dump-frames-and-windows))
             (alt (evil-window-move-cross-frame--select-best-window-topleft cur direction)))
        (if alt
            (evil-window-move-cross-frame--select-window-and-log alt)
          (evil-window-move-cross-frame--log "No geometric candidate (forced); falling back to Evil.")
          (evil-window-move-cross-frame--try-geometry-move direction)))
    (evil-window-move-cross-frame--try-geometry-move direction)))

;;; Interactive commands
(defun evil-window-move-cross-frame-left ()  (interactive) (evil-window-move-cross-frame--evil-move 'left))
(defun evil-window-move-cross-frame-right () (interactive) (evil-window-move-cross-frame--evil-move 'right))
(defun evil-window-move-cross-frame-up ()    (interactive) (evil-window-move-cross-frame--evil-move 'up))
(defun evil-window-move-cross-frame-down ()  (interactive) (evil-window-move-cross-frame--evil-move 'down))

;;; Setup function for customizable keybindings
(defun evil-window-move-cross-frame-setup-keybindings ()
  "Install keybindings for evil-window-move-cross-frame according to customization.
- If `evil-window-move-cross-frame-enable-default-keybindings` is non-nil,
  bind `evil-window-move-cross-frame-normal-state-keys` in `evil-normal-state-map`.
- To disable key installation, set that variable to nil or the keys alist to nil."
  (when (and evil-window-move-cross-frame-enable-default-keybindings
             evil-window-move-cross-frame-normal-state-keys)
    (with-eval-after-load 'evil
      (dolist (kv evil-window-move-cross-frame-normal-state-keys)
        (let ((key (car kv)) (cmd (cdr kv)))
          (when (and (stringp key) (commandp cmd))
            (define-key evil-normal-state-map (kbd key) cmd)))))))

;; Install default keys by default; users can override via custom before load.
(evil-window-move-cross-frame-setup-keybindings)

;;; Manual debug entrypoint
(defun evil-window-move-cross-frame-debug-best (direction)
  "Run a debug trace for DIRECTION without moving. Respects debug mode."
  (interactive
   (list (intern (completing-read "Direction: " '("left" "right" "up" "down")))))
  (evil-window-move-cross-frame--dump-frames-and-windows)
  (let* ((cur (selected-window))
         (best (evil-window-move-cross-frame--select-best-window-topleft cur direction)))
    (if best
        (evil-window-move-cross-frame--log "DEBUG best for %s is %s"
                                           direction (evil-window-move-cross-frame--win-id best))
      (evil-window-move-cross-frame--log "DEBUG no best for %s" direction))
    best))

(provide 'evil-window-move-cross-frame)
;;; evil-window-move-cross-frame.el ends here
