;;; vim.el --- a VIM-emulation for Emacs

;; Copyright (C) 2009, 2010 Frank Fischer

;; Author: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; Maintainer: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; URL: http://www.emacswiki.org/emacs/VimMode 
;; License: GPLv2 or later, as described below under "License"
;; Compatibility: Emacs 22, 23, XEmacs 21.4
;; Version: 0.3.0
;; Keywords: emulation, vim
;; Human-Keywords: vim, emacs
;;
;; This file is not part of GNU Emacs.

;;; Acknowledgements:

;; This package contains code from several other packages:
;;
;; - rect-mark.el
;; - viper
;; - vimpulse.el
;; - windmove.el
;;
;; Special thanks go to the authors of those packages.

;;; Commentary:

;; A simple VIM-mode for Emacs
;;
;; This project is in a VERY early development state and many function
;; have not been implemented yet.
;;
;; If you want to try, open this file in your Emacs and evaluate the buffer.
;; The mode can be activated by 'M-x vim-mode'.
;;
;; Don't forget to disable Viper if you want to try vim-mode.
;;
;; The project is divided into many files. Each file implements some
;; almost-independent feature. If you want to learn how to implement
;; new commands or motions, look at the files vim-commands.el and
;; vim-motions.el.
;;
;; Here is a short description of the contents of each file:
;;
;;  - vim.el:  This file just sets up the mode and loads the other files.
;;
;;  - vim-compat.el: Compatibility layer for different Emacsen.
;;
;;  - vim-keymap.el: A few functions for defining keymaps for vim-mode.
;;
;;  - vim-vim.el: This file contains the macros for defining motions
;;                and commands as well as some utility functions for
;;                calling them.
;;
;;  - vim-modes.el: Each VIM-mode (normal-mode, insert-mode, ...) corresponds
;;                  to an Emacs-minor-mode. This file contains some macros and
;;                  functions to define new vim-modes in this context.   
;;
;;  - vim-insert-mode.el: The implementation of insert-mode.         
;;                                                                    
;;  - vim-normal-mode.el: The implementation of normal-mode.         
;;                                                                    
;;  - vim-visual-mode.el: The implementation of visual-mode.         
;;
;;  - vim-ex-mode.el: The implementation of ex-mode.         
;;                                                                    
;;  - vim-commands.el: The implementations of commands like 'delete', 
;;                     'yank', 'paste' and so on.               
;;
;;  - vim-motions.el: The implementations of motion commands like 'h',
;;                    'i', 'j', 'k', 'f', 'w', ...
;;
;;  - vim-scroll.el: The implementation of scrolling commands like
;;                   'zz', 'Ctrl-F'.
;;
;;  - vim-window-el: The implementation of window commands like 'C-w s'.
;;
;;  - vim-ex-commands.el: The implementations of commands like ':edit'
;;                        or ':buffer'.
;;
;;  - vim-search.el: The implementation of '/' and ':substitute'.
;;
;;  - vim-undo.el: Some variables and functions for undo/redo.
;;
;;  - vim-maps.el: The definition of the basic keymaps.  This file
;;                 connects the keymaps with the commands and motions
;;                 defined in vim-commands.el and vim-motions.el.
;;
;; TODO:
;;
;; HAVE:
;;   - framework for keymaps, motions, commands and command-mappings
;;   - insert-mode, normal-mode, visual-mode and ex-mode
;;   - simple motions
;;   - deletion, yank, paste, change, replace
;;   - undo/redo
;;   - repeat
;;
;; MISSING:
;;   - better Emacs integration (modes, buffer local variables, ...)
;;   - text objects
;;   - several commands
;;   - marks and register
;;   - ...

;; - several calls 'looking-back' may be inefficient

;;; Code:

(provide 'vim)

(require 'cl)

(defgroup vim-mode nil
  "A VIM emulation mode."
  :group 'emulations)

(defcustom vim:whitelist
  nil
  "*List of major modes in which vim-mode should be enabled."
  :type '(repeat symbol)
  :group 'vim-mode)

(defcustom vim:blacklist
  '(debugger-mode
    compilation-mode
    grep-mode
    gud-mode
    sldb-mode
    slime-repl-mode
    reftex-select-bib-mode
    completion-list-mode
    help-mode
    )
  "*List of major modes in which vim-mode should *NOT* be enabled."
  :type '(repeat symbol)
  :group 'vim-mode)


(defmacro vim:deflocalvar (name &rest args)
  "Defines a buffer-local variable."
  (declare (indent defun))
  `(progn
     (defvar ,name ,@args)
     (make-variable-buffer-local ',name)))
(font-lock-add-keywords 'emacs-lisp-mode '("vim:deflocalvar"))

(defvar vim:emulation-mode-alist nil
  "List of all keymaps used by some modes.")

(let ((load-path (cons (expand-file-name ".") load-path)))
  (eval-when-compile
    (load "vim-compat")
    (load "vim-keymap")
    (load "vim-modes")
    (load "vim-vim")
    (load "vim-normal-mode")
    (load "vim-insert-mode")
    (load "vim-visual-mode")
    (load "vim-commands")
    (load "vim-motions")
    (load "vim-scroll")
    (load "vim-window")
    (load "vim-undo")
    (load "vim-ex")
    (load "vim-ex-commands")
    (load "vim-search")
    (load "vim-maps"))
  
  (require 'vim-compat)
  (require 'vim-keymap)
  (require 'vim-modes)
  (require 'vim-vim)
  (require 'vim-normal-mode)
  (require 'vim-insert-mode)
  (require 'vim-visual-mode)
  (require 'vim-commands)
  (require 'vim-motions)
  (require 'vim-scroll)
  (require 'vim-window)
  (require 'vim-undo)
  (require 'vim-ex)
  (require 'vim-ex-commands)
  (require 'vim-search)
  (require 'vim-maps))

(define-minor-mode vim-local-mode
  "VIM emulation mode."
  :lighter " VIM"
  :init-value nil
  :global nil

  (if vim-local-mode
      (progn
        (make-local-variable 'vim:emulation-mode-alist)
        ;; global keymaps
        (dolist (mode-keym vim:global-keymaps)
          (let ((mode (car mode-keym))
                (keym (cdr mode-keym)))
            (push (cons mode (symbol-value keym)) vim:emulation-mode-alist)))
        ;; local keymaps
        (dolist (mode-keym vim:local-keymaps)
          (let ((mode (car mode-keym))
                (keym (cdr mode-keym)))
            (make-local-variable keym)
            (set keym (copy-keymap (symbol-value keym)))
            (push (cons mode (symbol-value keym)) vim:emulation-mode-alist)))
        ;; The ESC keymap is used as the first emulation-map.
        (push (cons 'vim:intercept-ESC-mode vim:intercept-ESC-keymap) vim:emulation-mode-alist)
        (vim:initialize-keymaps t))
    (progn
      (vim:initialize-keymaps nil)
      (setq global-mode-string
            (delq 'vim:mode-string global-mode-string ))
      (vim:activate-mode nil))))
  
(define-globalized-minor-mode vim-mode vim-local-mode vim:initialize)

(defun vim:initialize ()
  (unless (vim:minibuffer-p)
    (when (or (and (null vim:whitelist)
                   (not (member major-mode vim:blacklist)))
              (and vim:whitelist
                   (member major-mode vim:whitelist)))
      (setq vim:active-mode nil)
      (vim-local-mode 1)
      (vim:intercept-ESC-mode 1)
      (vim:activate-normal-mode)
      (unless (memq 'vim:mode-string global-mode-string)
        (setq global-mode-string
              (append '("" vim:mode-string) (cdr global-mode-string)))))))


;;; vim.el ends here
