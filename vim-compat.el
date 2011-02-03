;;; vim-compat.el - Layer for interfacing different Emacsen

;; Copyright (C) 2009, 2010 Frank Fischer

;; Author: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;;
;; This file is not part of GNU Emacs.

;;; Code:

;; Check emacs and xemacs

(require 'vim-macs)

(defconst vim:xemacs-p (string-match "XEmacs" emacs-version))
(defconst vim:emacs23-p (>= emacs-major-version 23))
(defconst vim:emacs-p (not vim:xemacs-p))

(defconst vim:default-region-face (if vim:xemacs-p 'zmacs-region 'region))
(defconst vim:deactivate-region-hook (if vim:xemacs-p
					 'zmacs-deactivate-region-hook
				       'deactivate-mark-hook))

(defmacro vim:emacsen (&rest impls)
  "Defines some body depending in emacs version."
  (while (and impls (not (eval (caar impls))))
    (pop impls))
  (if impls `(progn ,@(cdar impls))
    (error "Not implemented for this Emacs version")))

(defun vim:set-cursor (cursor)
  "Changes the cursor to type `cursor'."
  (vim:emacsen
   (vim:emacs-p (setq cursor-type cursor))
   (vim:xemacs-p 
    (case cursor
      (bar 
       (setq bar-cursor 2))
      (t
       (setq bar-cursor nil))))))


(defun vim:set-keymap-default-binding (keymap command)
  "Sets the default binding of a keymap."
  (vim:emacsen
   (vim:emacs-p
    (define-key keymap [t] command))
   
   (vim:xemacs-p
    (set-keymap-default-binding keymap command))))

(defconst vim:ESC-event (if vim:xemacs-p (make-event 'key-press '(key vim:escape))
                          'escape))
  

(defun vim:intercept-ESC ()
  "Waits a short time for further keys, otherwise sending [escape]."
  (interactive)
  (vim:emacsen
   (vim:emacs-p
    (if (sit-for vim:intercept-ESC-timeout t)
        (push vim:ESC-event unread-command-events)
      (add-hook 'pre-command-hook 'vim:enable-intercept-ESC)
      (vim:intercept-ESC-mode -1)
      (push last-command-event unread-command-events)))
   
   (vim:xemacs-p
    (if (sit-for vim:intercept-ESC-timeout t)
        (push vim:ESC-event unread-command-events)
      (add-hook 'pre-command-hook 'vim:enable-intercept-ESC)
      (vim:intercept-ESC-mode -1)
      (push (copy-event last-command-event) unread-command-events)))))

(defmacro vim:called-interactively-p ()
  "Returns t iff the containing function has been called interactively."
  (vim:emacsen
   (vim:emacs-p
    ;; TODO: perhaps (interactive-p) is enough?
    (if (not (fboundp 'called-interactively-p))
        '(interactive-p)
      ;; Else, it is defined, but perhaps too old?
      (case (car-safe (subr-arity (symbol-function 'called-interactively-p)))
        (0 '(called-interactively-p))
        (1 '(called-interactively-p 'interactive)))))
   (vim:xemacs-p '(let (executing-macro) (interactive-p)))))

(vim:emacsen
 (vim:emacs-p (defalias 'vim:minibuffer-p 'minibufferp))
 (vim:xemacs-p (defalias 'vim:minibuffer-p 'active-minibuffer-window)))

(vim:emacsen
 (vim:emacs-p (defalias 'vim:this-command-keys 'this-command-keys-vector))
 (vim:xemacs-p 
  (defun vim:this-command-keys ()
    ;; this is a really dirty hack: for some reason
    ;; (this-command-keys) in XEmacs does not return events that have
    ;; been generated by the use of `unread-command-events' (but an
    ;; empty vector). That's why we simulate the expected behaviour
    ;; this way.
    (let ((keys (this-command-keys)))
      (if (zerop (length keys))
          (vector (copy-event last-command-event))
        keys)))))
    

(vim:emacsen
 (vim:emacs-p (defalias 'vim:deactivate-mark 'deactivate-mark))
 (vim:xemacs-p (defalias 'vim:deactivate-mark 'zmacs-deactivate-region)))

(vim:emacsen
 (vim:emacs-p (defsubst vim:do-deactivate-mark() deactivate-mark))
 (vim:xemacs-p (defsubst vim:do-deactivate-mark() nil)))

(vim:emacsen
 (vim:emacs-p (defalias 'vim:x-set-selection 'x-set-selection))
 (vim:xemacs-p (defsubst  vim:x-set-selection (type data) (own-selection data type))))

(vim:emacsen
 (vim:emacs-p
  (defconst vim:down-mouse-1 'down-mouse-1)
  (defconst vim:down-mouse-1 'down-mouse-1)
  (defsubst vim:mouse-event-window (ev) (posn-window (event-start ev)))
  (defsubst vim:mouse-event-point (ev) (posn-point (event-start ev)))
  (defalias 'vim:mouse-movement-p 'mouse-movement-p)
  (defsubst vim:mouse-event-p (ev)
    (and (symbolp (event-basic-type ev))
         (string-match "mouse" (symbol-name (event-basic-type ev)))))
  (defmacro vim:track-mouse (&rest body)
    `(track-mouse ,@body))
  (vim:deflocalvar vim:mouse-click-count 0)
  (vim:deflocalvar vim:mouse-click-last-time nil)
  (defun vim:mouse-click-count (event)
    (let ((time (posn-timestamp event)))
      (setq vim:mouse-click-count
            (cond
             ((or (memq 'double (event-modifiers event))
		  (memq 'triple (event-modifiers event)))
              (event-click-count event))
             ((and vim:mouse-click-last-time
                   (< (- time vim:mouse-click-last-time) double-click-time))
              (1+ vim:mouse-click-count))
             (t 1)))
      (setq vim:mouse-click-last-time time)
      vim:mouse-click-count))
  )
  
 (vim:xemacs-p
  (defconst vim:down-mouse-1 'button1)
  (defconst vim:down-mouse-1 'button1)
  (defalias 'vim:mouse-event-window 'event-window)
  (defalias 'vim:mouse-event-point 'event-closest-point)
  (defalias 'vim:mouse-movement-p 'motion-event-p)
  (defalias 'vim:mouse-event-p 'mouse-event-p)
  (defmacro vim:track-mouse (&rest body)
    `(progn ,@body))
  (vim:deflocalvar vim:mouse-click-count 0)
  (vim:deflocalvar vim:mouse-click-last-time nil)
  (defcustom vim:visual-double-click-time 500
    "Number of milliseconds for a repeating click.")
  (defun vim:mouse-click-count (event)
    (let ((time (event-timestamp event)))
      (message "TIME: %s %s" time vim:mouse-click-last-time)
      (setq vim:mouse-click-count
            (if (and vim:mouse-click-last-time
                     (< (- time vim:mouse-click-last-time) vim:visual-double-click-time))
                (1+ vim:mouse-click-count)
              1))
      (setq vim:mouse-click-last-time time)
      (message "CLICK: %s" vim:mouse-click-count)
      vim:mouse-click-count))
  ))

(font-lock-add-keywords 'emacs-lisp-mode '("vim:track-mouse"))

(vim:emacsen
 (vim:emacs-p
  (defalias 'vim:read-event 'read-event))
 (vim:xemacs-p
  (defun vim:read-event ()
    (let (event)
      (while (progn
               (setq event (next-event))
               (not (or (key-press-event-p event)
                        (button-press-event-p event)
                        (button-release-event-p event)
                        (motion-event-p event)
                        (menu-event-p event))))
           (dispatch-event event))
      event))))





(vim:emacsen
 (vim:emacs-p (defalias 'vim:char-p 'integerp))
 (vim:xemacs-p (defalias 'vim:char-p 'characterp)))

(vim:emacsen
 (vim:emacs-p (defalias 'vim:perform-replace 'perform-replace))
 (vim:xemacs-p 
  (defun vim:perform-replace (from-string replacements query-flag regexp-flag delimited-flag
                              &optional repeat-count map beg end)
    (if (or beg end)
        (progn
          (push-mark (or beg (point-min)))
          (goto-char (or end (point-max)))
          (zmacs-activate-region)
          (let ((result
                 (perform-replace from-string replacements query-flag regexp-flag delimited-flag
                                  repeat-count map)))
            (pop-mark)
            result))
      (perform-replace from-string replacements query-flag regexp-flag delimited-flag
                       repeat-count map)))))

(vim:emacsen
 (vim:emacs-p (defalias 'vim:minibuffer-contents 'minibuffer-contents))
 (vim:xemacs-p (defsubst vim:minibuffer-contents ()
                 "Returns the editable content of the currently active minibuffer."
                 (when (vim:minibuffer-p)
                   (buffer-substring (point-min) (point-max))))))

(defun vim:test-completion (string collection &optional predicate)
  "Returns non-nil if `string' is a valid completion."
  (vim:emacsen
   (vim:emacs-p (test-completion string collection predicate))
   (vim:xemacs-p (eq (try-completion string collection predicate) t))))


(if (fboundp 'match-substitute-replacement)
    (defalias 'vim:match-substitute-replacement 'match-substitute-replacement)
  ;; A simple definition I found somewhere in the web.
  (defun vim:match-substitute-replacement (replacement
					   &optional fixedcase literal string subexp)
    "Return REPLACEMENT as it will be inserted by `replace-match'.
In other words, all back-references in the form `\\&' and `\\N'
are substituted with actual strings matched by the last search.
Optional FIXEDCASE, LITERAL, STRING and SUBEXP have the same
meaning as for `replace-match'."
    (let ((match (match-string 0 string)))
      (save-match-data
	(set-match-data (mapcar (lambda (x)
				  (if (numberp x)
				      (- x (match-beginning 0))
				    x))
				(match-data t)))
	(replace-match replacement fixedcase literal match subexp)))))


(defun vim:looking-back (regexp &optional limit greedy)
  "Return non-nil if text before point matches regular expression REGEXP.
Like `looking-at' except matches before point, and is slower.
LIMIT if non-nil speeds up the search by specifying a minimum
starting position, to avoid checking matches that would start
before LIMIT.
If GREEDY is non-nil, extend the match backwards as far as possible,
stopping when a single additional previous character cannot be part
of a match for REGEXP."
  (vim:emacsen
   (vim:emacs-p (looking-back regexp limit greedy))
   
   (vim:xemacs-p 
    (let ((start (point))
	  (pos
	   (save-excursion
	     (and (re-search-backward (concat "\\(?:" regexp "\\)\\=") limit t)
		  (point)))))
      (if (and greedy pos)
	  (save-restriction
	    (narrow-to-region (point-min) start)
	    (while (and (> pos (point-min))
			(save-excursion
			  (goto-char pos)
			  (backward-char 1)
			  (looking-at (concat "\\(?:"  regexp "\\)\\'"))))
	      (setq pos (1- pos)))
	    (save-excursion
	      (goto-char pos)
	      (looking-at (concat "\\(?:"  regexp "\\)\\'")))))
      (not (null pos))))))
  

(defun vim:initialize-keymaps (enable)
  "Initialize keymaps when vim-mode is enabled."
  (vim:emacsen
   (vim:emacs-p
    (if enable
        (add-to-list 'emulation-mode-map-alists 'vim:emulation-mode-alist)
      (setq emulation-mode-map-alists
            (delq 'vim:emulation-mode-alist emulation-mode-map-alists))))
   
   (vim:xemacs-p
    (if enable
	(vim:normalize-minor-mode-map-alist)
      (setq minor-mode-map-alist
	    (remq nil
		  (mapcar #'(lambda (x)
			      (unless (assq (car x) vim:emulation-mode-alist) x))
			  minor-mode-map-alist)))))))


(when vim:xemacs-p
  (unless (fboundp 'line-number-at-pos)
    (defun line-number-at-pos (&optional pos)
      (line-number pos)))
  
  (defun vim:normalize-minor-mode-map-alist ()
    (make-local-variable 'minor-mode-map-alist)
    (setq minor-mode-map-alist
	  (apply #'append
		 vim:emulation-mode-alist
		 (mapcar #'(lambda (x)
			     (unless (assq (car x) vim:emulation-mode-alist)
			       (list x)))
			 minor-mode-map-alist))))
  
  (defadvice add-minor-mode (after vim:add-minor-mode 
                             (toggle name &optional keymap after toggle-fun)
                             activate)
    "Run vim:normalize-minor-mode-map-alist after adding a minor mode."
    (vim:normalize-minor-mode-map-alist))

  (defun insert-for-yank (text)
    (let* ((yank-handler (and text
                              (get-text-property 0 'yank-handler text))))
      (if (or (null yank-handler) (null (car yank-handler)))
          (insert text)
        (funcall (car yank-handler)
                 (or (nth 1 yank-handler) text)))))
  
  (defadvice kill-new (before vim:kill-new (string &optional replace yank-handler) activate)
    "Set the yank-handler property at the given string."
    (when yank-handler
      (put-text-property 0 (length string) 'yank-handler yank-handler string)))
  
  (defadvice yank (around vim:yank (&optional arg) activate)
    "Like `yank' but respects the yank-handler property."
    (let* ((text (nth (if (numberp arg) arg 0) kill-ring-yank-pointer))
           (yank-handler (and text
                              (get-text-property 0 'yank-handler text))))
      (if (or (null yank-handler) (null (car yank-handler)))
          ad-do-it
        (funcall (car yank-handler)
                 (or (nth 1 yank-handler) text)))))
  
          

  (defmacro define-globalized-minor-mode (global-mode mode turn-on &rest keys)
    "Make a global mode GLOBAL-MODE corresponding to buffer-local minor MODE.
TURN-ON is a function that will be called with no args in every buffer
  and that should try to turn MODE on if applicable for that buffer.
KEYS is a list of CL-style keyword arguments.  As the minor mode
  defined by this function is always global, any :global keyword is
  ignored.  Other keywords have the same meaning as in `define-minor-mode',
  which see.  In particular, :group specifies the custom group.
  The most useful keywords are those that are passed on to the
  `defcustom'.  It normally makes no sense to pass the :lighter
  or :keymap keywords to `define-globalized-minor-mode', since these
  are usually passed to the buffer-local version of the minor mode.

If MODE's set-up depends on the major mode in effect when it was
enabled, then disabling and reenabling MODE should make MODE work
correctly with the current major mode.  This is important to
prevent problems with derived modes, that is, major modes that
call another major mode in their body."

    (let* ((global-mode-name (symbol-name global-mode))
	   (pretty-name (easy-mmode-pretty-mode-name mode))
	   (pretty-global-name (easy-mmode-pretty-mode-name global-mode))
	   (group nil)
	   (extra-keywords nil)
	   (MODE-buffers (intern (concat global-mode-name "-buffers")))
	   (MODE-enable-in-buffers
	    (intern (concat global-mode-name "-enable-in-buffers")))
	   (MODE-check-buffers
	    (intern (concat global-mode-name "-check-buffers")))
	   (MODE-cmhh (intern (concat global-mode-name "-cmhh")))
	   (MODE-major-mode (intern (concat (symbol-name mode) "-major-mode")))
	   keyw)

      ;; Check keys.
      (while (keywordp (setq keyw (car keys)))
	(setq keys (cdr keys))
	(case keyw
	  (:group (setq group (nconc group (list :group (pop keys)))))
	  (:global (setq keys (cdr keys)))
	  (t (push keyw extra-keywords) (push (pop keys) extra-keywords))))

      (unless group
	;; We might as well provide a best-guess default group.
	(setq group
	      `(:group ',(intern (replace-regexp-in-string
				  "-mode\\'" "" (symbol-name mode))))))

      `(progn
         (defvar ,MODE-major-mode nil)
         (make-variable-buffer-local ',MODE-major-mode)
         ;; The actual global minor-mode
         (define-minor-mode ,global-mode
           ,(format "Toggle %s in every possible buffer.
With prefix ARG, turn %s on if and only if ARG is positive.
%s is enabled in all buffers where `%s' would do it.
See `%s' for more information on %s."
                    pretty-name pretty-global-name pretty-name turn-on
                    mode pretty-name)
           :global t ,@group ,@(nreverse extra-keywords)

           ;; Setup hook to handle future mode changes and new buffers.
           (if ,global-mode
               (progn
                 (add-hook 'after-change-major-mode-hook
                           ',MODE-enable-in-buffers)
                 (add-hook 'find-file-hook ',MODE-check-buffers)
                 (add-hook 'change-major-mode-hook ',MODE-cmhh))
             (remove-hook 'after-change-major-mode-hook ',MODE-enable-in-buffers)
             (remove-hook 'find-file-hook ',MODE-check-buffers)
             (remove-hook 'change-major-mode-hook ',MODE-cmhh))

           ;; Go through existing buffers.
           (dolist (buf (buffer-list))
             (with-current-buffer buf
               (if ,global-mode (,turn-on) (when ,mode (,mode -1))))))

         ;; Autoloading define-globalized-minor-mode autoloads everything
         ;; up-to-here.
         :autoload-end

         ;; List of buffers left to process.
         (defvar ,MODE-buffers nil)

         ;; The function that calls TURN-ON in each buffer.
         (defun ,MODE-enable-in-buffers ()
           (dolist (buf ,MODE-buffers)
             (when (buffer-live-p buf)
               (with-current-buffer buf
                 (if ,mode
                     (unless (eq ,MODE-major-mode major-mode)
                       (,mode -1)
                       (,turn-on)
                       (setq ,MODE-major-mode major-mode))
                   (,turn-on)
                   (setq ,MODE-major-mode major-mode))))))
         (put ',MODE-enable-in-buffers 'definition-name ',global-mode)

         (defun ,MODE-check-buffers ()
           (,MODE-enable-in-buffers)
           (setq ,MODE-buffers nil)
           (remove-hook 'post-command-hook ',MODE-check-buffers))
         (put ',MODE-check-buffers 'definition-name ',global-mode)

         ;; The function that catches kill-all-local-variables.
         (defun ,MODE-cmhh ()
           (add-to-list ',MODE-buffers (current-buffer))
           (add-hook 'post-command-hook ',MODE-check-buffers))
         (put ',MODE-cmhh 'definition-name ',global-mode))))

  ;; This is a hack written by Hovav Shacham, author of the windmove package, so that 
  ;; windmove will work in xemacs
  ;;--- begin hack ---
 
  ;; simulate `window-edges' using `window-pixel-edges'; from
  ;; Nix , based on tapestry.el.
  (defun window-edges (&optional window)
    (let ((edges (window-pixel-edges window))
	  tmp)
      (setq tmp edges)
      (setcar tmp (/ (car tmp) (face-width 'default)))
      (setq tmp (cdr tmp))
      (setcar tmp (/ (car tmp) (face-height 'default)))
      (setq tmp (cdr tmp))
      (setcar tmp (/ (car tmp) (face-width 'default)))
      (setq tmp (cdr tmp))
      (setcar tmp (/ (car tmp) (face-height 'default)))
      edges))
  
  ;; simulate `window-at' with `walk-windows'
  (defun window-at (x y &optional frame)
    (let ((f (if (null frame)
		 (selected-frame)
	       frame)))
      (let ((guess-wind nil))
	(walk-windows (function (lambda (w)
				  (let ((w-edges (window-edges w)))
				    (when (and (eq f (window-frame w))
					       (<= (nth 0 w-edges) x)
					       (>= (nth 2 w-edges) x)
					       (<= (nth 1 w-edges) y)
					       (>= (nth 3 w-edges) y))
				      (setq guess-wind w)))))
		      t ; walk minibuffers
		      t) ; walk all frames
	guess-wind)))
  
  ;; redo `windmove-coordinates-of-position' without compute-motion
  (defun walk-screen-lines (lines goal)
    (cond
     ((< (window-point) goal) (1- lines))
     ((= (window-point) goal) lines)
     (t (vertical-motion 1)
	(walk-screen-lines (1+ lines) goal))))
  
  (defun windmove-coordinates-of-position (pos &optional window)
    (let* ((w (if (null window)
		  (selected-window)
		window))
	   (b (window-buffer w)))
      (save-selected-window
	(select-window w)
	(save-excursion
	  (let* ((y (progn (goto-char (window-start))
			   (walk-screen-lines 0 pos)))
		 (x (- (progn (goto-char pos)
			      (current-column))
		       (progn (goto-char (window-start))
			      (vertical-motion y)
			      (current-column)))))
	    (cons x y))))))            
  
  ;; for some reason, XEmacs is more conservative in reporting `frame-width'
  ;; and `frame-height'; we apparently need to get rid of the 1- in each.
  (defun windmove-frame-edges (window)
    (let ((frame (if window
		     (window-frame window)
		   (selected-frame))))
      (let ((x-min 0)
	    (y-min 0)
	    (x-max (frame-width frame))
	    (y-max (frame-height frame)))
	(list x-min y-min x-max y-max))))
  
  ;; --- end hack ---

  (defun window-tree (&optional frame)
    "Return the window tree for frame `frame'."
    (let ((root (frame-root-window frame))
	  (mini (minibuffer-window frame)))
      (labels
	  ((subwindows (win)
	     (cond
	      ((window-first-hchild win)
	       (let (w-list
		     (child (window-first-vchild win)))
		 (while child
		   (push child w-list)
		   (setq child (window-next-child child)))
		 (cons t
		       (cons (window-edges win)
			     (mapcar #'subwindows (reverse w-list))))))
	      ((window-first-vchild win)
	       (let (w-list
		     (child (window-first-vchild win)))
		 (while child
		   (push child w-list)
		   (setq child (window-next-child child)))
		 (cons nil
		       (cons (window-edges win)
			     (mapcar #'subwindows (reverse w-list))))))
	      (t win))))
	(list (subwindows root) mini))))
  )

(provide 'vim-compat)

;;; vim-compat.el ends here
