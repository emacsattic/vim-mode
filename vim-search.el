;;; vim-search.el

;; Copyright (C) 2009 Frank Fischer
;; 
;; Version: 0.2.0
;; Keywords: emulations
;; Human-Keywords: vim, emacs
;; Authors: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; Maintainer: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; License: GPLv2 or later, as described below under "License"

;; TODO:
;;
;;  - searching currently uses isearch.  Although this is quite powerful,
;;    it's only usuably as interactive search and difficult to use with
;;    semi-interactive stuff like the "*" command.  The current implementation
;;    using unread-command-events is quite ugly.
;;  - the substitute command should be more interactive and especially an operation
;;    without the 'g' option should highlight all future occurences

(provide 'vim-search)

(defconst vim:search-mode-keymap (list 'keymap '(t . vim:search-mode-exit)))

(vim:deflocalvar vim:search-last-direction nil
  "The last search direction, either 'forward or 'backward.")

(defun vim:search-mode-activate ()
  (setq cursor-type vim:normal-mode-cursor))

(defun vim:search-mode-deactivate ()
  (isearch-exit))

(vim:defcmd vim:search-mode-exit ()
  (vim:activate-normal-mode)
  (push last-command-event unread-command-events))

;; Search mode is a very special mode being activated during a search
;; command.  Its purpose is to disable highlighting of search results
;; if something else than a repeat-search event occurs.
(vim:define-mode search "VIM search mode"
                 :ident "S"
                 :keymap vim:search-mode-keymap
                 :command-function 'vim:search-mode-command
                 :activate 'vim:search-mode-activate
                 :deactivate 'vim:search-mode-deactivate)

(defun vim:search-mode-command (command)
  "Executes a simple-command in search-mode."
  (case (vim:cmd-type command)
    ('simple (vim:normal-execute-simple-command command))
    (t (error "Only simple commands allowed in search-mode."))))

(vim:defcmd vim:search-start (nonrepeatable)
  "Starts an incremental regexp search."
  (let ((search-nonincremental-instead nil))
    (ad-activate 'isearch-message-prefix)
    (isearch-forward-regexp)
    (ad-deactivate 'isearch-message-prefix)
    (setq vim:last-search-direction (if isearch-forward 'forward 'backward))))

(vim:defcmd vim:search-start-backward (nonrepeatable)
  "Starts an incremental regexp search."
  (let ((search-nonincremental-instead nil))
    (ad-activate 'isearch-message-prefix)
    (isearch-backward-regexp)
    (ad-deactivate 'isearch-message-prefix)
    (setq vim:last-search-direction (if isearch-forward 'forward 'backward))))

(vim:defcmd vim:search-repeat (nonrepeatable)
  "Repeats the last incremental search."
  (unless (vim:search-mode-p)
    (vim:activate-search-mode))
  (ad-activate 'isearch-message-prefix)
  (isearch-repeat vim:last-search-direction)
  (ad-deactivate 'isearch-message-prefix))

(vim:defcmd vim:search-repeat-opposite (nonrepeatable)
  "Starts an incremental regexp search."
  (unless (vim:search-mode-p)
    (vim:activate-search-mode))
  (ad-activate 'isearch-message-prefix)
  (isearch-repeat (if (eq vim:last-search-direction 'forward) 'backward 'forward))
  (ad-deactivate 'isearch-message-prefix))

(defadvice isearch-message-prefix (after vim:isearch-message-prefix (&optional c-q-hack ellipsis nonincremental))
  "This advice changes the minibuffer indicator to '/' or '?'"
  (setq ad-return-value (if isearch-forward "/" "?")))

(defun vim:start-word-search (unbounded direction)
 
  (condition-case nil
      (goto-char (vim:motion-bwd-word-end :count 1))
    (error nil))
 
  (save-excursion
    (re-search-forward (concat "\\<[" vim:word "]+\\>")))
 
  (when (eq direction 'backward)
    (goto-char (1+ (match-end 0))))
  (let ((events (reverse (append (if (eq direction 'forward)
				     "/"
				   "?")
				 (if unbounded
				     (regexp-quote (match-string 0))
				   (concat "\\<" 
					   (regexp-quote (match-string 0))
					   "\\>"))
				 [return]
				 "n"
				 nil))))
    (while events
      (push (car events) unread-command-events)
      (setq events (cdr events)))))


(vim:defcmd vim:search-word (nonrepeatable)
  "Searches the next occurence of word under the cursor."
  (vim:start-word-search nil 'forward))
   
   
(vim:defcmd vim:search-word-backward (nonrepeatable)
  "Searches the next occurence of word under the cursor."
  (vim:start-word-search nil 'backward))
   
   
(vim:defcmd vim:search-unbounded-word (nonrepeatable)
  "Searches the next occurence of word under the cursor."
  (vim:start-word-search t 'forward))
   
   
(vim:defcmd vim:search-unbounded-word-backward (nonrepeatable)
  "Searches the next occurence of word under the cursor."
  (vim:start-word-search t 'backward))


(vim:defcmd vim:cmd-substitute (motion argument nonrepeatable)
  "The VIM substitutde command: [range]s/pattern/replacement/flags"
  (multiple-value-bind (pattern replacement flags) (vim:parse-substitute argument)
    (lexical-let* ((pattern pattern)
                   (replacement replacement)
                   (first-line (if motion (vim:motion-first-line motion) (line-number-at-pos (point))))
                   (last-line (if motion (vim:motion-last-line motion) (line-number-at-pos (point))))
                   (whole-line (and flags (find ?g flags)))
                   (confirm (and flags (find ?c flags)))
                   (ignore-case (and flags (find ?i flags)))
                   (dont-ignore-case (and flags (find ?I flags)))
                   (case-fold-search (or (and case-fold-search
                                              (not dont-ignore-case))
                                         (and (not case-fold-search)
                                              ignore-case)))
                   (case-replace case-fold-search)
                   (last-point (point))
                   (overlay (make-overlay (point) (point)))
                   (next-line (line-number-at-pos (point)))
                   (nreplaced 0))
      
      (unwind-protect
          (if whole-line
              ;; this one is easy, just use the built in function
              (perform-replace pattern replacement confirm t nil nil nil 
                               (save-excursion
                                 (goto-line first-line)
                                 (line-beginning-position))
                               (save-excursion
                                 (goto-line last-line)
                                 (line-end-position)))
            (if confirm
                (progn
                  ;; this one is more difficult, we have to do the
                  ;; highlighting and questioning on our own
                  (overlay-put overlay 'face
                               (if (internal-find-face 'isearch nil)
                                   'isearch 'region))
                  (map-y-or-n-p #'(lambda (x)
                                    (set-match-data x)
                                    (move-overlay overlay (match-beginning 0) (match-end 0))
                                    (concat "Query replacing " 
                                            (match-string 0) 
                                            " with "
                                            (match-substitute-replacement replacement case-fold-search)
                                            ": "))
                                #'(lambda (x) 
                                    (set-match-data x) 
                                    (replace-match replacement case-fold-search) 
                                    (incf nreplaced)
                                    (setq last-point (point)))
                                #'(lambda ()
                                    (let ((end (save-excursion 
                                                 (goto-line last-line)
                                                 (line-end-position))))
                                      (goto-line next-line)
                                      (beginning-of-line)
                                      (when (and (> end (point))
                                                 (re-search-forward pattern end t nil))
                                        (setq last-point (point))
                                        (setq next-line (1+ (line-number-at-pos (point))))
                                        (match-data))))))
              
              ;; just replace the first occurences per line
              ;; without highlighting and asking
              (goto-line first-line)
              (beginning-of-line)
              (while (and (<= (line-number-at-pos (point)) last-line)
                          (re-search-forward pattern (save-excursion
                                                       (goto-line last-line)
                                                       (line-end-position))
                                             t nil))
                (incf nreplaced)
                (replace-match replacement)
                (setq last-point (point))
                (forward-line)
                (beginning-of-line)))

            (goto-char last-point)
            (if (= nreplaced 1)
                (message "Replaced 1 occurence")
              (message "Replaced %d occurences" nreplaced)))
           
        ;; clean-up the overlay
        (delete-overlay overlay)))))


(defun vim:parse-substitute (text)
  (when (string-match "\\`\\s-*/\\(\\(?:[^/]\\|\\\\.\\)+\\)/\\(\\(?:[^/]\\|\\\\.\\)*\\)\\(?:/\\([giIc]*\\)\\)?\\s-*\\'"
                      text)
    (values (match-string 1 text) (match-string 2 text) (match-string 3 text))))
