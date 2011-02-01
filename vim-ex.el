;;; vim-ex.el - Ex-mode.

;; Copyright (C) 2009, 2010 Frank Fischer

;; Author: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;;
;; This file is not part of GNU Emacs.

;;; Code:

(defvar vim:ex-commands nil
  "List of pairs (command . function).")

(vim:deflocalvar vim:ex-local-commands nil
  "List of pairs (command . function).")

(defvar vim:ex-minibuffer nil
  "The currenty active ex minibuffer.")

(defvar vim:ex-current-buffer nil
  "The buffer to which the currently active ex session belongs to.")

(defvar vim:ex-current-window nil
  "The window to which the currently active ex session belongs to.")

(defvar vim:ex-history nil
  "History of ex-commands.")

(defvar vim:ex-cmd nil
  "The currently parsed command.")
(defvar vim:ex-arg nil
  "The currently parse command.")
(defvar vim:ex-arg-handler nil
  "The currently active argument handler.")
(defvar vim:ex-region nil
  "The currently parsed region.")

(defvar vim:ex-keymap (make-sparse-keymap)
  "Keymap used in ex-mode.")

(define-key vim:ex-keymap "\t" 'minibuffer-complete)
(define-key vim:ex-keymap [return] 'vim:ex-mode-exit)
(define-key vim:ex-keymap (kbd "RET") 'vim:ex-mode-exit)
(define-key vim:ex-keymap " " 'vim:ex-expect-argument)
(define-key vim:ex-keymap (kbd "C-j") 'vim:ex-execute-command)
(define-key vim:ex-keymap (kbd "C-g") 'vim:ex-mode-abort)
(define-key vim:ex-keymap [up] 'previous-history-element)
(define-key vim:ex-keymap [down] 'next-history-element)
(define-key vim:ex-keymap "\d" 'vim:ex-delete-backward-char)
(define-key vim:ex-keymap (kbd "ESC ESC ESC") 'vim:ex-mode-keyboard-escape-quit)


(defun vim:ex-contents ()
  "Returns the contents of the ex buffer.
The content is the same as minibuffer-contents would return
except for the info message."
  (with-current-buffer vim:ex-minibuffer
    (buffer-substring-no-properties
     (minibuffer-prompt-end)
     (point-max))))

(defun vim:emap (keys command)
  "Maps an ex-command to some function."
  (unless (find-if #'(lambda (x) (string= (car x) keys)) vim:ex-commands)
    (add-to-list 'vim:ex-commands (cons keys command))))

(defun vim:local-emap (keys command)
  "Maps an ex-command to some function buffer-local."
  (unless (find-if #'(lambda (x) (string= (car x) keys)) vim:ex-local-commands)
    (add-to-list 'vim:ex-local-commands (cons keys command))))

(defun vim:ex-binding (cmd)
  "Returns the current binding of `cmd' or nil."
  (with-current-buffer vim:ex-current-buffer
    (while (and cmd (stringp cmd))
      (setq cmd (or (cdr-safe (assoc cmd vim:ex-local-commands))
		    (cdr-safe (assoc cmd vim:ex-commands)))))
    cmd))

(defun vim:ex-delete-backward-char (n)
  "Delete the previous `n' characters. If ex-buffer is empty,
cancel ex-mode."
  (interactive "p")
  (if (and (>= n 1)
           (zerop (length (minibuffer-contents))))
      (exit-minibuffer))
  (delete-backward-char n))



(defstruct (vim:arg-handler
            (:constructor vim:make-arg-handler))
  complete   ;; The completion function.
  activate   ;; Called when the argument is activated for the first time.
  deactivate ;; Called when the argument is deactivated.
  update     ;; Called whenever the argument has changed.
  )

(defvar vim:argument-handlers-alist
  `((text . ,(vim:make-arg-handler :complete #'vim:ex-complete-text-argument))
    (file . ,(vim:make-arg-handler :complete #'vim:ex-complete-file-argument))
    (buffer . ,(vim:make-arg-handler :complete #'vim:ex-complete-buffer-argument)))
  "An alist that contains for each argument type the appropriate handler."
  )

(defun* vim:define-arg-handler (arg-type &key
					 complete
					 activate
					 deactivate
					 update)
  "Defines a new argument handler `arg-type'."
  (let ((newah (vim:make-arg-handler :complete complete
					 :activate activate
					 :deactivate deactivate
					 :update update))
	(ah (assoc arg-type vim:argument-handlers-alist)))
    (if ah
	(setcdr ah newah)
      (push (cons arg-type newah) vim:argument-handlers-alist))))


(defun vim:ex-get-arg-handler (cmd)
  "Returns the argument handler of command `cmd'."
  (let ((cmd (vim:ex-binding cmd)))
    (if (not cmd)
	(ding)
      (let* ((arg-type (vim:cmd-arg cmd))
	     (arg-handler (assoc arg-type vim:argument-handlers-alist)))
	(if arg-handler (cdr arg-handler))))))

(defun vim:ex-setup ()
  "Initializes the minibuffer for an ex-like mode.
This function should be called as minibuffer-setup-hook when an
ex-mode starts."
  (remove-hook 'minibuffer-setup-hook #'vim:ex-setup) ; Just for the case.
  (setq vim:ex-cmd nil
	vim:ex-arg nil
	vim:ex-arg-handler nil
	vim:ex-range nil
	vim:ex-minibuffer (current-buffer)))

(defun vim:ex-teardown ()
  "Deinitializes the minibuffer for an ex-like mode.
This function should be called whenever the minibuffer is exited."
  (setq vim:ex-minibuffer nil))
  

(defun vim:ex-start-session ()
  "Initializes the minibuffer when ex-mode is started."
  (vim:ex-setup)
  (remove-hook 'minibuffer-setup-hook #'vim:ex-start-session)
  (add-hook 'after-change-functions #'vim:ex-change nil t))


(defun vim:ex-stop-session ()
  "Deinitializes the minibuffer when ex-mode is stopped."
  (vim:ex-teardown)
  (let ((arg-deactivate (and vim:ex-arg-handler (vim:arg-handler-deactivate vim:ex-arg-handler))))
    (when arg-deactivate (funcall arg-deactivate)))
  (remove-hook 'after-change-functions #'vim:ex-change t))
  

(defun vim:ex-mode-exit ()
  "Calls `exit-minibuffer' and cleanup."
  (interactive)
  (vim:ex-stop-session)
  (exit-minibuffer))


(defun vim:ex-mode-abort ()
  "Calls `abort-recursive-edit' and cleanup."
  (interactive)
  (vim:ex-stop-session)
  (abort-recursive-edit))


(defun vim:ex-mode-keyboard-escape-quit ()
  "Calls `keyboard-escape-quit' and cleanup."
  (interactive)
  (vim:ex-stop-session)
  (keyboard-escape-quit))


(defun vim:ex-change (beg end len)
  "Checkes if the command or argument changed and informs the
argument handler."
  (unless vim:ex-update-info
    (let ((cmdline (vim:ex-contents)))
      (multiple-value-bind (range cmd spaces arg beg end) (vim:ex-split-cmdline cmdline)
	(cond
	 ((not (string= vim:ex-cmd cmd))
	  ;; command changed, update argument handler ...
	  (setq vim:ex-cmd cmd
		vim:ex-arg arg
		vim:ex-range (cons beg end))
	  ;; ... deactivate old handler ...
	  (let ((arg-deactivate (and vim:ex-arg-handler
				     (vim:arg-handler-deactivate vim:ex-arg-handler))))
	    (when arg-deactivate (funcall arg-deactivate)))
	  ;; ... activate and store new handler ...
	  (let ((cmd (vim:ex-binding cmd)))
	    (setq vim:ex-arg-handler
		  (and cmd (vim:ex-get-arg-handler cmd)))
	    (let ((arg-activate (and vim:ex-arg-handler
				     (vim:arg-handler-activate vim:ex-arg-handler))))
	      (when arg-activate (funcall arg-activate)))))
       
	 ((or (not (string= vim:ex-arg arg))
	      (not (equal (cons beg end) vim:ex-range)))
	  ;; command remained the same, but argument or range changed
	  ;; so inform the argument handler
	  (setq vim:ex-arg arg)
	  (setq vim:ex-range (cons beg end))
	  (let ((arg-update (and vim:ex-arg-handler
				 (vim:arg-handler-update vim:ex-arg-handler))))
	    (when arg-update (funcall arg-update)))))))))
	

(defun vim:ex-split-cmdline (cmdline)
  "Splits the command line in range, command and argument part."
  (multiple-value-bind (cmd-region beg end) (vim:ex-parse cmdline)
    (if (null cmd-region)
        (values cmdline "" cmdline "" beg end)
      (let ((range (substring cmdline 0 (car cmd-region)))
            (cmd (substring cmdline (car cmd-region) (cdr cmd-region)))
            (spaces "")
            (arg (substring cmdline (cdr cmd-region))))
    
        ;; skip whitespaces
        (when (string-match "\\`\\s-*" arg)
          (setq spaces (match-string 0 arg)
                arg (substring arg (match-end 0))))
      
        (values range cmd spaces arg beg end)))))


(defun vim:ex-expect-argument (n)
  "Called if the space separating the command from the argument
has been pressed."
  (interactive "p")
  (let ((cmdline (vim:ex-contents)))
    (self-insert-command n)
    (multiple-value-bind (range cmd spaces arg beg end) (vim:ex-split-cmdline cmdline)

      (when (and (= (point) (point-max))
                 (zerop (length spaces))
                 (zerop (length arg)))
	(setq cmd (vim:ex-binding cmd))
        (if (null cmd) (ding)
          (let ((result (case (vim:cmd-arg cmd)
                          (file
                           (vim:ex-complete-file-argument nil nil nil))
                          (buffer
                           (vim:ex-complete-buffer-argument nil nil nil))
                          ((t)
                           (vim:ex-complete-text-argument nil nil nil)))))
            (when result (insert result))))))))
          

(defun vim:ex-complete (cmdline predicate flag)
  "Called to complete an object in the ex-buffer."
  (multiple-value-bind (range cmd spaces arg beg end) (vim:ex-split-cmdline cmdline)
    (setq vim:ex-cmd cmd)

    (cond
     ;; only complete at the end of the command
     ((< (point) (point-max)) nil)
       
     ;; if at the end of a command, complete the command
     ((and (zerop (length spaces)) (zerop (length arg)))
      (let ((result (vim:ex-complete-command cmd predicate flag)))
        (cond
         ((null result) nil)
         ((eq t result) t)
         ((stringp result)
          (if flag result (concat range result)))
         ((listp result) (if flag result (mapcar #'(lambda (x) (concat range x)) result)))
         (t (error "Completion returned unexpected value.")))))
              
     ;; otherwise complete the argument
     (t 
      (let ((result (vim:ex-complete-argument arg predicate flag)))
        (cond
         ((null result) nil)
         ((eq t result) t)
         ((stringp result) (if flag result (concat range cmd spaces result)))
         ((listp result) (if flag result (mapcar #'(lambda (x) (concat range cmd spaces x)) result)))
         (t (error "Completion returned unexpected value."))))))))

        
(defun vim:ex-complete-command (cmd predicate flag)
  "Called to complete the current command."
  (with-current-buffer vim:ex-current-buffer
    (cond
     ((null flag) (or (try-completion cmd vim:ex-local-commands predicate)
                      (try-completion cmd vim:ex-commands predicate)))
   
     ((eq t flag) (or (all-completions cmd vim:ex-local-commands predicate)
                      (all-completions cmd vim:ex-commands predicate)))
   
     ((eq 'lambda flag) (or (vim:test-completion cmd vim:ex-local-commands predicate)
                            (vim:test-completion cmd vim:ex-commands predicate))))))


(defun vim:ex-complete-argument (arg predicate flag)
  "Called to complete the current argument w.r.t. the current command."
  (let* ((cmd vim:ex-cmd)
	 (arg-handler (vim:ex-get-arg-handler cmd)))
    (funcall (or (vim:arg-handler-complete arg-handler)
		 #'vim:ex-complete-text-argument)
	     arg predicate flag)))


(defun vim:ex-complete-file-argument (arg predicate flag)
  "Called to complete a file argument."
  (if (null arg)
      default-directory
    (let ((dir (or (file-name-directory arg)
                   (with-current-buffer vim:ex-current-buffer default-directory)))
          (fname (file-name-nondirectory arg)))
      (cond
       ((null dir) (ding))
       ((null flag)
        (let ((result (file-name-completion fname dir)))
	  (case result
	    ((nil) nil)
	    ((t) t)
	    (t (concat dir result)))))
       
       ((eq t flag) 
        (file-name-all-completions fname dir))
       
       ((eq 'lambda flag)
        (eq (file-name-completion fname dir) t))))))
      

(defun vim:ex-complete-buffer-argument (arg predicate flag)
  "Called to complete a buffer name argument."
  (when arg
    (let ((buffers (mapcar #'(lambda (buffer) (cons (buffer-name buffer) nil)) (buffer-list t))))
      (cond
       ((null flag)
        (try-completion arg buffers predicate))
       ((eq t flag) 
        (all-completions arg buffers predicate))
       ((eq 'lambda flag)
        (vim:test-completion arg buffers predicate))))))


(defun vim:ex-complete-text-argument (arg predicate flag)
  "Called to complete standard argument, therefore does nothing."
  (when arg
    (case flag
      ((nil) t)
      ((t) (list arg))
      ('lambda t))))


(defun vim:ex-execute-command (cmdline)
  "Called to execute the current command."
  (interactive)
  (multiple-value-bind (range cmd spaces arg beg end) (vim:ex-split-cmdline cmdline)
    (setq vim:ex-cmd cmd)
    
    (let ((cmd vim:ex-cmd)
          (motion (cond
                   ((and beg end)
                    (vim:make-motion :begin (save-excursion
                                              (goto-line beg)
                                              (line-beginning-position))
                                     :end (save-excursion
                                            (goto-line end)
                                            (line-beginning-position))
                                     :has-begin t
                                     :type 'linewise))
                   (beg
                    (vim:make-motion :begin (save-excursion
                                              (goto-line beg)
                                              (line-beginning-position))
                                     :end (save-excursion
                                            (goto-line beg)
                                            (line-beginning-position))
                                     :has-begin t
                                     :type 'linewise))))
          (count (and (not end) beg)))
      
      (setq cmd (vim:ex-binding cmd))

      (when (zerop (length arg))
        (setq arg nil))

      (with-current-buffer vim:ex-current-buffer
        (cond
         (cmd (case (vim:cmd-type cmd)
                ('complex
                 (if (vim:cmd-arg-p cmd)
                     (funcall cmd :motion motion :argument arg)
                   (funcall cmd :motion motion)))
                ('simple
                (when end
                  (error "Command does not take a range: %s" vim:ex-cmd))
                (if (vim:cmd-arg-p cmd)
                    (if (vim:cmd-count-p cmd)
                        (funcall cmd :count beg :argument arg)
                      (funcall cmd :argument arg))
                  (if (vim:cmd-count-p cmd)
                      (funcall cmd :count (or count (and arg (string-to-number arg))))
                    (funcall cmd))))
                (t (error "Unexpected command-type bound to %s" vim:ex-cmd))))
         (beg (vim:motion-go-to-first-non-blank-beg :count (or end beg)))
         (t (ding)))))))
    

;; parser for ex-commands
(defun vim:ex-parse (text)
  "Extracts the range-information from `text'.
Returns a list of up to three elements: (cmd beg end)"
  (let (begin
        (begin-off 0)
        sep
        end
        (end-off 0)
        (pos 0)
        (cmd nil))
    
    (multiple-value-bind (beg npos) (vim:ex-parse-address text pos)
      (when npos
        (setq begin beg
              pos npos)))

    (multiple-value-bind (off npos) (vim:ex-parse-offset text pos)
      (when npos
        (unless begin (setq begin 'current-line))
        (setq begin-off off
              pos npos)))

    (when (and (< pos (length text))
               (or (= (aref text pos) ?\,)
                   (= (aref text pos) ?\;)))
      (setq sep (aref text pos))
      (incf pos)
      (multiple-value-bind (e npos) (vim:ex-parse-address text pos)
        (when npos
          (setq end e
          pos npos)))
      
      (multiple-value-bind (off npos) (vim:ex-parse-offset text pos)
        (when npos
          (unless end (setq end 'current-line))
          (setq end-off off
          pos npos))))

    ;; handle the special '%' range
    (when (or (eq begin 'all) (eq end 'all))
      (setq begin 'first-line
            begin-off 0
            end 'last-line
            end-off 0
            sep ?,))
    
    (when (= pos (or (string-match "[a-zA-Z0-9!]+" text pos) -1))
      (setq cmd (cons (match-beginning 0) (match-end 0))))
               
    (multiple-value-bind (start end) (vim:ex-get-range (and begin (cons begin begin-off)) sep (and end (cons end end-off)))
      (values cmd start end))))


(defun vim:ex-parse-address (text pos)
  "Parses `text' starting at `pos' for an address, returning a two values,
the range and the new position."
  (cond
   ((>= pos (length text)) nil)
   
   ((= pos (or (string-match "[0-9]+" text pos) -1))
    (values (cons 'abs (string-to-number (match-string 0 text)))
            (match-end 0)))

   ((= (aref text pos) ?$)
    (values (cons 'abs (line-number-at-pos (point-max))) (1+ pos)))

   ((= (aref text pos) ?\%)
    (values 'all (1+ pos)))
    
   ((= (aref text pos) ?.)
    (values 'current-line (1+ pos)))

   ((= (aref text pos) ?')
    (if (>= (1+ pos) (length text))
        nil
      (values `(mark ,(aref text (1+ pos))) (+ 2 pos))))

   ((= (aref text pos) ?/)
    (when (string-match "\\([^/]+\\|\\\\.\\)\\(?:/\\|$\\)"
                        text (1+ pos))
      (values (cons 're-fwd (match-string 1 text))
              (match-end 0))))
   
   ((= (aref text pos) ??)
    (when (string-match "\\([^?]+\\|\\\\.\\)\\(?:?\\|$\\)"
                        text (1+ pos))
      (values (cons 're-bwd (match-string 1 text))
              (match-end 0))))
   
   ((and (= (aref text pos) ?\\)
         (< pos (1- (length text))))
    (case (aref text (1+ pos))
      (?/ (values 'next-of-prev-search (1+ pos)))
      (?? (values 'prev-of-prev-search (1+ pos)))
      (?& (values 'next-of-prev-subst (1+ pos)))))

   (t nil)))


(defun vim:ex-parse-offset (text pos)
  "Parses `text' starting at `pos' for an offset, returning a two values,
the offset and the new position."
  (let ((off nil))
    (while (= pos (or (string-match "\\([-+]\\)\\([0-9]+\\)?" text pos) -1))
      (if (string= (match-string 1 text) "+")
          (setq off (+ (or off 0) (if (match-beginning 2)
                                      (string-to-number (match-string 2 text))
                                    1)))
                
        (setq off (- (or off 0) (if (match-beginning 2)
                                    (string-to-number (match-string 2 text))
                                  1))))
      (setq pos (match-end 0)))
    (and off (values off pos))))
     

(defun vim:ex-get-range (start sep end)
  (with-current-buffer vim:ex-current-buffer
    (when start
      (setq start (vim:ex-get-line start)))

    (when (and sep end)
      (save-excursion
        (when (= sep ?\;) (goto-line start))
        (setq end (vim:ex-get-line end))))
  
    (values start end)))


(defun vim:ex-get-line (address)
  (let ((base (car address))
        (offset (cdr address)))
    
    (cond
     ((null base) nil)
     ((consp offset)
      (let ((line (vim:ex-get-line (car address))))
        (when line
        (save-excursion
          (goto-line line)
          (vim:ex-get-line (cdr address))))))
     
     (t
      (+ offset
         (case (or (car-safe base) base)
         (abs (cdr base))
           
         ;; TODO: (1- ...) may be wrong if the match is the empty string
         (re-fwd (save-excursion
                   (beginning-of-line 2)
                   (and (re-search-forward (cdr base))
                        (line-number-at-pos (1- (match-end 0))))))
           
         (re-bwd (save-excursion
                   (beginning-of-line 0)
                   (and (re-search-backward (cdr base))
                        (line-number-at-pos (match-beginning 0)))))
           
         (current-line (line-number-at-pos (point)))
         (first-line (line-number-at-pos (point-min)))
         (last-line (line-number-at-pos (point-max)))
         (mark (line-number-at-pos (vim:get-local-mark (cadr base))))
         (next-of-prev-search (error "Next-of-prev-search not yet implemented."))
         (prev-of-prev-search (error "Prev-of-prev-search not yet implemented."))
         (next-of-prev-subst (error "Next-of-prev-subst not yet implemented."))
         (t (error "Invalid address: %s" address))))))))


(defun vim:ex-read-command (&optional initial-input)
  "Starts ex-mode."
  (interactive)
  (let ((vim:ex-current-buffer (current-buffer))
	(vim:ex-current-window (selected-window)))
    (let ((minibuffer-local-completion-map vim:ex-keymap))
      (add-hook 'minibuffer-setup-hook #'vim:ex-start-session)
      (let ((result (completing-read ":" 'vim:ex-complete nil nil initial-input  'vim:ex-history)))
        (when (and result
                   (not (zerop (length result))))
          (vim:ex-execute-command result))))))

(provide 'vim-ex)

;;; vim-ex.el ends here
