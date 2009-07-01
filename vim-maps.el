;; TODO:
;;   - better mapping to support stuff like
;;     (vim:def-map "c" "d{motion}a")
;;
;;   - mapping to "ESC" to leave insert-mode doesn't work because ESC
;;     is seen as meta-prefix, I think
;;
;;   - should we have a 'deep-mapping' function: for example, "x" is
;;     mapped to "dl" in the default keymap.  If someone decides to
;;     redefine "l" to some other command, "x" will change its
;;     behaviour, too.  A 'deep-mapping' should save the mapping on
;;     definition of "x", therefor let "x" behave as usual even after
;;     redefining "l"
(provide 'vim-maps)

(load "vim-motions")


;(vim:def-motion "0" 'vim:motion-beginning-of-line :type 'exclusive)
(vim:def-special "0" 'vim:feed-numeric-prefix-or-bol)
(vim:def-special "1" 'vim:feed-numeric-prefix)
(vim:def-special "2" 'vim:feed-numeric-prefix)
(vim:def-special "3" 'vim:feed-numeric-prefix)
(vim:def-special "4" 'vim:feed-numeric-prefix)
(vim:def-special "5" 'vim:feed-numeric-prefix)
(vim:def-special "6" 'vim:feed-numeric-prefix)
(vim:def-special "7" 'vim:feed-numeric-prefix)
(vim:def-special "8" 'vim:feed-numeric-prefix)
(vim:def-special "9" 'vim:feed-numeric-prefix)
;(vim:def-special "\"" 'vim:do-something-funny-with-registers)

(vim:def-motion "h" 'vim:motion-left :type 'exclusive)
(vim:def-motion "l" 'vim:motion-right :type 'exclusive)
(vim:def-motion "^" 'vim:motion-first-non-blank :type 'exclusive)
(vim:def-motion "$" 'vim:motion-end-of-line :type 'inclusive)
(vim:def-motion "g_" 'vim:motion-last-non-blank :type 'inclusive)

(vim:def-motion "k" 'vim:motion-up :type 'linewise :type 'inclusive)
(vim:def-motion "j" 'vim:motion-down :type 'linewise :type 'inclusive)
(vim:def-map "-" "k^")
(vim:def-map "+" "j^")
(vim:def-motion "G" 'vim:motion-go-to-first-non-blank-end :type 'linewise) 
(vim:def-motion "gg" 'vim:motion-go-to-first-non-blank-beg :type 'linewise) 

(vim:def-motion "w" 'vim:motion-fwd-word :type 'exclusive)
(vim:def-motion "W" 'vim:motion-fwd-WORD :type 'exclusive)
(vim:def-motion "e" 'vim:motion-fwd-word-end :type 'inclusive)
(vim:def-motion "E" 'vim:motion-fwd-WORD-end :type 'inclusive)
(vim:def-motion "b" 'vim:motion-bwd-word :type 'exclusive)
(vim:def-motion "B" 'vim:motion-bwd-WORD :type 'exclusive)
(vim:def-motion "ge" 'vim:motion-bwd-word-end :type 'inclusive)
(vim:def-motion "gE" 'vim:motion-bwd-WORD-end :type 'inclusive)

(vim:def-motion "(" 'vim:motion-bwd-sentence :type 'exclusive)
(vim:def-motion ")" 'vim:motion-fwd-sentence :type 'exclusive)
(vim:def-motion "{" 'vim:motion-bwd-paragraph :type 'exclusive)
(vim:def-motion "}" 'vim:motion-fwd-paragraph :type 'exclusive)
(vim:def-motion "]]" 'vim:motion-fwd-section :type 'exclusive)
(vim:def-motion "][" 'vim:motion-fwd-section :type 'exclusive)
(vim:def-motion "[[" 'vim:motion-bwd-section :type 'exclusive)
(vim:def-motion "[]" 'vim:motion-bwd-section :type 'exclusive)

(vim:def-motion "f" 'vim:motion-find :type 'inclusive :arg t)
(vim:def-motion "F" 'vim:motion-find-back :type 'exclusive :arg t)
(vim:def-motion "t" 'vim:motion-find-to :type 'inclusive :arg t)
(vim:def-motion "T" 'vim:motion-find-back-to :type 'exclusive :arg t)
(vim:def-motion ";" 'vim:motion-repeat-last-find)
(vim:def-motion "," 'vim:motion-repeat-last-find-opposite)

(vim:def-map "x" "dl")
(vim:def-map "D" "d$")
(vim:def-simple "dd" 'vim:cmd-delete-line)
(vim:def-complex "d" 'vim:cmd-delete)

(vim:def-map "C" "d$a")
(vim:def-map "cc" "0C")
(vim:def-complex "c" 'vim:cmd-change)
(vim:def-map "s" "xi")

(vim:def-simple "r" 'vim:cmd-replace-char :arg t)

(vim:def-simple "yy" 'vim:cmd-yank-line)
(vim:def-complex "y" 'vim:cmd-yank)
(vim:def-map "Y" "yy")
(vim:def-simple "p" 'vim:cmd-paste-behind)
(vim:def-simple "P" 'vim:cmd-paste-before)

(vim:def-simple "i" 'vim:normal-insert)
(vim:def-simple "a" 'vim:normal-append)
(vim:def-map "I" "^i")
(vim:def-map "A" "$a")
(vim:def-map "o" (kbd "A RET TAB"))
(vim:def-map "O" (kbd "0 i RET <up> TAB"))

(vim:def-simple "u" 'vim:cmd-undo)
(vim:def-simple (kbd "C-r") 'vim:cmd-redo)

(vim:def-simple [escape]
                #'(lambda (count motion)
                    (vim:insert-mode-exit))
                :mode vim:insert-mode)
