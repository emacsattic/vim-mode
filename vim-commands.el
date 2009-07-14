;;; vim-commands.el

;; Copyright (C) 2009 Frank Fischer
;; 
;; Version: 0.0.1
;; Keywords: emulations
;; Human-Keywords: vim, emacs
;; Authors: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; Maintainer: Frank Fischer <frank.fischer@mathematik.tu-chemnitz.de>,
;; License: GPLv2 or later, as described below under "License"

;; Description:

;; In general there are two types of commands: those operating on a
;; motion and those not taking a motion.  Examples of the first one
;; are the vim-commands c, d, y, =, examples of the second one are dd,
;; D, p, x.
;;
;; A function implementing a motion should take two or three arguments:
;;
;;  - a count
;;  - a motion of type vim:motion
;;  - an (optional) argument character
;;
;; If the operation does not require a motion, the second parameter is
;; usually nil.  If the operation takes a motion, the count parameter
;; should usually be ignored since the count has already been regarded
;; by the motion itself (the motion function got (command-count *
;; motion-count) as count parameter.
;;
;; An operations based on motions should always respect the motion
;; type, i.e. if the motion is linewise or not.  Motions passed to
;; commands will always be inclusive (and never exlusive).  For
;; example, the command dG has a linewise motion argument and should
;; delete whole lines.
;;
;; Furthermore, each operation should place (point) at the correct
;; position after the operation.

(provide 'vim-commands)

(require 'redo)


(vim:define vim:cmd-insert (count)
            :type 'simple
  (vim:activate-mode vim:insert-mode))

(vim:define vim:cmd-append (count)
            :type 'simple
  (unless (eolp) (forward-char))
  (vim:activate-mode vim:insert-mode))

(vim:define vim:cmd-Insert (count)
            :type 'simple
  (goto-char (vim:motion-first-non-blank))
  (vim:cmd-insert count))

(vim:define vim:cmd-Append (count)
            :type 'simple
  (end-of-line)
  (vim:cmd-append count))



(vim:define vim:cmd-delete-line (count)
            :type 'simple
  "Deletes the next count lines."
  (vim:cmd-yank-line count)
  (let ((beg (line-beginning-position))
        (end (save-excursion
               (forward-line (1- (or count 1)))
               (line-end-position))))
    (if (= beg (point-min))
        (if (= end (point-max))
            (erase-buffer)
          (delete-region beg (save-excursion
                               (goto-char end)
                               (forward-line)
                               (line-beginning-position))))
      (delete-region (save-excursion
                       (goto-char beg)
                       (forward-line -1)
                       (line-end-position))
                     end))
    (goto-char beg)
    (goto-char (vim:motion-first-non-blank))))


(vim:define vim:cmd-delete (motion)
            :type 'complex
  "Deletes the characters defined by motion."
  (case (vim:motion-type motion)
    ('linewise
     (goto-char (vim:motion-begin motion))
     (vim:cmd-delete-line (vim:motion-line-count motion)))

    ('block
     (vim:cmd-yank motion)
     (let ((beg (save-excursion
                  (goto-line (car (vim:motion-begin motion)))
                  (move-to-column (cdr (vim:motion-begin motion)) t)
                  (point)))
           (end (save-excursion
                  (goto-line (car (vim:motion-end motion)))
                  (move-to-column (1+ (cdr (vim:motion-end motion))) t)
                  (point))))
       (delete-rectangle beg end)
       (goto-char beg)))

    (t
      (kill-region (vim:motion-begin motion) (min (point-max) (1+ (vim:motion-end motion))))
      (goto-char (vim:motion-begin motion)))))


(vim:define vim:cmd-change (motion)
            :type 'complex
  "Deletes the characters defined by motion and goes to insert mode."
  (case (vim:motion-type motion)
    ('linewise
     (goto-char (vim:motion-begin motion))
     (vim:cmd-change-line (vim:motion-line-count motion)))

    ('block
     (vim:cmd-delete motion)
     (vim:visual-insert motion))

    (t
     (vim:cmd-delete motion)
     (if (eolp)
         (vim:cmd-append 1)
       (vim:cmd-insert 1)))))


(vim:define vim:cmd-change-line (count)
            :type 'simple
  "Deletes count lines and goes to insert mode."
  (let ((pos (line-beginning-position)))
    (vim:cmd-delete-line count)
    (if (< (point) pos)
        (progn
          (end-of-line)
          (newline))
      (progn
        (beginning-of-line)
        (newline)
        (forward-line -1)))
    (indent-according-to-mode)
    (if (eolp)
        (vim:cmd-append 1)
      (vim:cmd-insert 1))))


(vim:define vim:cmd-replace-char (count arg)
            :type 'simple
            :argument t
  "Replaces the next count characters with arg."
  (unless (integerp arg)
    (error "Expected a character."))
  (when (< (- (line-end-position) (point))
           (or count 1))
    (error "Too few characters to end of line."))
  (delete-region (point) (+ (point) (or count 1)))
  (insert-char arg (or count 1))
  (backward-char))


(vim:define vim:cmd-replace (count)
            :type 'simple
  "Goes to replace-mode."
  (vim:activate-mode vim:replace-mode))


(vim:define vim:cmd-replace-region (motion arg)
            :type 'complex
            :argument t
   "Replace the complete region with `arg'"
   (case (vim:motion-type motion)
     ('block
      ;; replace in block
      (let ((begrow (car (vim:motion-begin motion)))
            (begcol (cdr (vim:motion-begin motion)))
            (endrow (car (vim:motion-end motion)))
            (endcol (1+ (cdr (vim:motion-end motion)))))
        (goto-line begrow)
        (dotimes (i (1+ (- endrow begrow)))
          ;; TODO does it work with \r\n at the end?
          (let ((maxcol (save-excursion
                          (end-of-line)
                          (current-column))))
            (when (> maxcol begcol)
              (delete-region (save-excursion
                               (move-to-column begcol t)
                               (point))
                             (save-excursion
                               (move-to-column (min endcol maxcol) t)
                               (point)))
              (move-to-column begcol t)
              (insert-char arg (- (min endcol maxcol) begcol))))
          (forward-line 1))
        (goto-line begrow)
        (move-to-column begcol)))
       
     (t ;; replace in linewise and normal
      (let ((begrow (vim:row-of-pos (vim:motion-begin motion)))
            (endrow (vim:row-of-pos (vim:motion-end motion))))
        (goto-line begrow)
        (do ((r begrow (1+ r)))
            ((> r endrow))
          (goto-line r)
          (let ((begcol
                 (if (and (= r begrow)
                          (not (eq (vim:motion-type motion) 'linewise)))
                     (save-excursion
                       (goto-char (vim:motion-begin motion))
                       (current-column))
                   0))
                (endcol
                 (if (and (= r endrow)
                          (not (eq (vim:motion-type motion) 'linewise)))
                     (save-excursion
                       (goto-char (vim:motion-end motion))
                       (1+ (current-column)))
                   ;; TODO does it work with \r\n at the end?
                   (save-excursion
                     (end-of-line)
                     (current-column)))))

              (delete-region (save-excursion
                               (move-to-column begcol t)
                               (point))
                             (save-excursion
                               (move-to-column endcol t)
                               (point)))
              (move-to-column begcol t)
              (insert-char arg (- endcol begcol)))))

        (goto-char (vim:motion-begin motion)))))


(vim:define vim:cmd-yank (motion)
            :type 'complex
            :repeatable nil
  "Saves the characters in motion into the kill-ring."
  (case (vim:motion-type motion)
    ('block (vim:cmd-yank-rectangle motion))
    (t
     (kill-new (buffer-substring
                (vim:motion-begin motion)
                (1+ (vim:motion-end motion)))))))
  

(vim:define vim:cmd-yank-line (count)
            :type 'simple
            :repeatable nil
  "Saves the next count lines into the kill-ring."
  (let ((beg (line-beginning-position))
        (end (save-excursion
               (forward-line (1- (or count 1)))
               (line-end-position))))
    (kill-new (concat (buffer-substring beg end) "\n") nil)))


(defun vim:cmd-yank-rectangle (motion)
  "Stores the rectangle defined by motion into the kill-ring."
  ;; TODO: yanking should not insert spaces or expand tabs.
  (let ((begrow (car (vim:motion-begin motion)))
        (begcol (cdr (vim:motion-begin motion)))
        (endrow (car (vim:motion-end motion)))
        (endcol (cdr (vim:motion-end motion)))
        (parts nil))
    (goto-line endrow)
    (dotimes (i (1+ (- endrow begrow)))
      (let ((beg (save-excursion (move-to-column begcol t) (point)))
            (end (save-excursion (move-to-column (1+ endcol) t) (point))))
        (setq parts (cons "\n" (cons (buffer-substring beg end) parts)))
        (forward-line -1)))
    (kill-new (apply #'concat (cdr parts)) nil (list 'vim:yank-block-handler))
    (goto-line begrow)
    (move-to-column begcol)))


(defun vim:yank-block-handler (text)
  "Inserts the current text as block."
  (let ((parts (split-string text "\n"))
        (col (current-column)))
    (dolist (part parts)
      (insert part)
      (forward-line 1)
      (move-to-column col t))))
                    

(vim:define vim:cmd-paste-before (count)
            :type 'simple
  "Pastes the latest yanked text before the cursor position."
  (unless kill-ring-yank-pointer
    (error "kill-ring empty"))
  
  (let* ((txt (car kill-ring-yank-pointer))
         (yhandler (get-text-property 0 'yank-handler txt)))
    (cond
     (yhandler ; block or other strange things
      (save-excursion (yank))) 
     
     ((= (elt txt (1- (length txt))) ?\n) ; linewise
      (beginning-of-line)
      (save-excursion
        (dotimes (i (or count 1))
          (yank))))

     (t ; normal
      (dotimes (i (or count 1))
        (yank))
      (backward-char)))))


(vim:define vim:cmd-paste-behind (count)
            :type 'simple
  "Pastes the latest yanked text behind point."
  (unless kill-ring-yank-pointer
    (error "kill-ring empty"))
  
  (let* ((txt (car kill-ring-yank-pointer))
         (yhandler (get-text-property 0 'yank-handler txt)))

    (cond
     (yhandler ; block or other string things
      (forward-char)
      (save-excursion (yank)))

     ((= (elt txt (1- (length txt))) ?\n) ; linewise
      (let ((last-line (= (line-end-position) (point-max))))
        (if last-line
            (progn
              (end-of-line)
              (newline))
          (forward-line))
        (beginning-of-line)
        (save-excursion
          (dotimes (i (or count 1))
            (yank))
          (when last-line
            ;; remove the last newline
            (let ((del-pos (point)))
              (forward-line -1)
              (end-of-line)
              (delete-region (point) del-pos))))))

     (t ; normal
      (forward-char)
      (dotimes (i (or count 1))
        (yank))
      (backward-char)))))


(vim:define vim:cmd-repeat ()
            :type 'simple
            :repeatable nil
            :count nil
  "Repeats the last command."
  (unless vim:repeat-events
    (error "Nothing to repeat"))
  (vim:reset-key-state)
  (dotimes (i (or count 1))
    (let ((repeat-events vim:repeat-events)
          (vim:repeat-events nil))
      (execute-kbd-macro repeat-events)))
  (vim:reset-key-state))


