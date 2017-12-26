;;; org-kanban.el --- Org-mode kanban utility  -*- lexical-binding: t; -*-

;; Unlicense

;; Author: Hagmonk <hagmonk@icloud.com>
;; URL: http://github.com/hagmonk/org-kanban
;; Keywords: outlines kanban org
;; Package-Requires: ((emacs "25") (org "9"))
;; Version: 0.1

;;; Commentary:

;; org-kanban implements a simple kanban management technique

;;; Code:

(defgroup org-kanban nil
  "Org-mode kanban helper"
  :prefix "org-kanban-"
  :group 'org)


(defun org-kanban--get-states ()
  "REturn the list of headlines we should consider to be the
'states' of the Kanban board."
  (save-excursion
    (goto-char (point-min))
    (unless (org-at-heading-p)
      (outline-next-heading))

    (message "Starting with parent %s" (org-entry-get 'nil "ITEM"))
    (org-map-entries (lambda ()
                       (org-entry-get 'nil "ITEM"))
                     "LEVEL=2"
                     'tree)))

(defun org-kanban-refresh ()
  "Urgh - this needs refactoring!"
  (when-let ((local-kanban kanban-heading)
             (local-buffer (current-buffer))
             (base-buffer (buffer-base-buffer)))
    (pop-to-buffer-same-window base-buffer)
    (kill-buffer local-buffer)
    (goto-char (point-min))
    (goto-char (org-find-exact-headline-in-buffer local-kanban))
    (let ((current-prefix-arg '(4)))
      (call-interactively 'org-tree-to-indirect-buffer))
    (setq-local kanban-heading local-kanban)
    (let ((current-prefix-arg '(1)))
      (org-cycle)
      (org-cycle))))

(defun org-kanban--around-org-refile (orig-fun &rest args)
  "Overrides for refile"
  (apply orig-fun args)
  (when
      ;;(equal "kanban.org" (buffer-name (buffer-base-buffer)))
      (local-variable-p 'kanban-heading)

    (cl-loop for w in (window-list) do
             (select-window w)
             (org-kanban-refresh))))

(defun org-kanban--init-window (states)
  "Sets up window splits based on the states provided. Sets
org-refile-targets to a locally useful value."

  ;; ensure trees are visible
  (org-set-startup-visibility)

  ;; TODO: set this specifically to the provided states
  (setq-local org-refile-targets '((nil :level . 2)))

  (advice-add 'org-refile :around #'org-kanban--around-org-refile)

  (setq org-indirect-buffer-display 'current-window)

  (goto-char (point-min))

  ;; split the window enough times
  (cl-loop repeat
           (- (length states) 1)
           do
           (split-window-right))

  ;; for each state, narrow to an indirect buffer
  (cl-loop for s in states
           do
           (goto-char (point-min))
           (goto-char (org-find-exact-headline-in-buffer s))
           (let ((current-prefix-arg '(4)))
             (call-interactively 'org-tree-to-indirect-buffer))

           (setq-local kanban-heading s)
           (let ((current-prefix-arg '(1)))
             (org-cycle)
             (org-cycle))
           (other-window 1)))

(defun org-kanban ()
  (interactive)
  (org-kanban--init-window (org-kanban--get-states)))
