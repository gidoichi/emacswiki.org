;;; insert-translated-name.el --- Insert translated string as variable or function name  -*- lexical-binding: t; -*-

;; Filename: insert-translated-name.el
;; Description: Insert translated string as variable or function name
;; Author: Andy Stewart <lazycat.manatee@gmail.com>
;; Maintainer: Andy Stewart <lazycat.manatee@gmail.com>
;; Copyright (C) 2018, Andy Stewart, all rights reserved.
;; Created: 2018-09-22 10:54:16
;; Version: 0.3
;; Last-Updated: 2018-09-23 07:59:52
;;           By: Andy Stewart
;; URL: http://www.emacswiki.org/emacs/download/insert-translated-name.el
;; Keywords:
;; Compatibility: GNU Emacs 27.0.50
;;
;; Features that might be required by this library:
;;
;;
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Insert translated string as variable or function name
;;

;;; Installation:
;;
;; Put insert-translated-name.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'insert-translated-name)
;;
;; No need more.

;;; Customize:
;;
;; `insert-translated-name-line-style-mode-list'
;; `insert-translated-name-underline-style-mode-list'
;; `insert-translated-name-camel-style-mode-list'
;; `insert-translated-name-font-lock-mark-word'
;;

;;; Change log:
;;
;; 2018/09/23
;;      * Store placeholder in buffer local's hash instead insert placeholder uuid in buffer.
;;
;; 2018/09/22
;;      * First released.
;;      * Change query translation asynchronous, don't insert buffer if query duration more than 2 seconds.
;;      * Use overlay as input way, and add `insert-translated-name-replace-*' functions.
;;

;;; Acknowledgements:
;;
;;
;;

;;; TODO
;;
;;
;;

;;; Require

;;; Code:

;;;;;;;;;;;;;;;;;;;;; Customize options ;;;;;;;;;;;;;;;;;;;;;
(defgroup insert-translated-name nil
  "Search and refacotry code base on ripgrep."
  :group 'insert-translated-name)

(defface insert-translated-name-font-lock-mark-word
  '((t (:foreground "White" :background "SystemBlueColor" :bold t)))
  "Face for keyword match."
  :group 'insert-translated-name)

(defconst insert-translated-name-api-url
  "http://fanyi.youdao.com/openapi.do?keyfrom=YouDaoCV&key=659600698&type=data&doctype=json&version=1.1&q=%s"
  "Youdao dictionary API template, URL `http://dict.youdao.com/'.")

(defvar insert-translated-name-line-style-mode-list
  '(web-mode emacs-lisp-mode))

(defvar insert-translated-name-camel-style-mode-list
  '(js-mode))

(defvar insert-translated-name-underline-style-mode-list
  '(ruby-mode))

;;;;;;;;;;;;;;;;;;;;; Interactive functions ;;;;;;;;;;;;;;;;;;;;;
(defun insert-translated-name-insert ()
  (interactive)
  (insert-translated-name-active
   (cond ((insert-translated-name-match-modes insert-translated-name-line-style-mode-list)
          "line")
         ((insert-translated-name-match-modes insert-translated-name-camel-style-mode-list)
          "camel")
         ((insert-translated-name-match-modes insert-translated-name-underline-style-mode-list)
          "underline")
         (t
          "underline"))))

(defun insert-translated-name-insert-with-line ()
  (interactive)
  (insert-translated-name-active "line"))

(defun insert-translated-name-insert-with-underline ()
  (interactive)
  (insert-translated-name-active "underline"))

(defun insert-translated-name-insert-with-camel ()
  (interactive)
  (insert-translated-name-active "camel"))

(defun insert-translated-name-replace ()
  (interactive)
  (insert-translated-name-query-symbol
   (cond ((insert-translated-name-match-modes insert-translated-name-line-style-mode-list)
          "line")
         ((insert-translated-name-match-modes insert-translated-name-camel-style-mode-list)
          "camel")
         ((insert-translated-name-match-modes insert-translated-name-underline-style-mode-list)
          "underline")
         (t
          "underline"))))

(defun insert-translated-name-replace-with-line ()
  (interactive)
  (insert-translated-name-query-symbol "line"))

(defun insert-translated-name-replace-with-underline ()
  (interactive)
  (insert-translated-name-query-symbol "underline"))

(defun insert-translated-name-replace-with-camel ()
  (interactive)
  (insert-translated-name-query-symbol "camel"))

;;;;;;;;;;;;;;;;;;;;; Helper functions ;;;;;;;;;;;;;;;;;;;;;
(defun insert-translated-name-query-symbol (style)
  (let ((word (thing-at-point 'symbol)))
    (thing-paste-symbol)
    (insert-translated-name-query-translation word style)))

(defun insert-translated-name-match-modes (mode-list)
  (cl-remove-if 'null (mapcar #'(lambda (mode) (derived-mode-p mode)) mode-list)))

(defun insert-translated-name-active (style)
  ;; Add monitor hook.
  (add-hook 'after-change-functions 'insert-translated-name-monitor-change nil t)

  ;; Make sure build hash to contain placeholder.
  (unless (boundp 'insert-translated-name-placeholder-hash)
    (set (make-local-variable 'insert-translated-name-placeholder-hash) (make-hash-table :test 'equal)))

  ;; Make sure clean active overlay first.
  (when (and (boundp 'insert-translated-name-active-overlay)
             insert-translated-name-active-overlay)
    (delete-overlay insert-translated-name-active-overlay))

  ;; Reset active local variables
  (set (make-local-variable 'insert-translated-name-active-point) (point))
  (set (make-local-variable 'insert-translated-name-active-style) style)
  (set (make-local-variable 'insert-translated-name-active-overlay) (make-overlay (point) (point)))

  ;; Active new overlay from current point.
  (overlay-put insert-translated-name-active-overlay 'face 'insert-translated-name-font-lock-mark-word)

  ;; Print play hint.
  (message "Type Chinese and press SPACE to translate"))

(defun insert-translated-name-inactive ()
  ;; Delete active overlay.
  (delete-overlay insert-translated-name-active-overlay)

  ;; Clean active local variables.
  (set (make-local-variable 'insert-translated-name-active-point) nil)
  (set (make-local-variable 'insert-translated-name-active-overlay) nil)
  )

(defun insert-translated-name-monitor-change (start end len)
  (when (and (boundp 'insert-translated-name-active-point)
             insert-translated-name-active-point)
    ;; Translate current Chinese words after press SPACE.
    (if (string-equal (buffer-substring-no-properties start end) " ")
        (let (
              (word (buffer-substring-no-properties insert-translated-name-active-point (- (point) 1))))
          ;; Delete Chinese words.
          (kill-region insert-translated-name-active-point (point))

          ;; Inactive.
          (insert-translated-name-inactive)

          ;; Query translation.
          (insert-translated-name-query-translation word)
          )
      ;; Update active overlay bound if user press any other non-SPACE character.
      (move-overlay insert-translated-name-active-overlay insert-translated-name-active-point (point)))
    ))

(defun insert-translated-name-query-translation (word &optional style)
  (prin1 word)
  (let ((placeholder (insert-translated-name--generate-uuid)))
    ;; Store placeholder in hash.
    (puthash placeholder (point) insert-translated-name-placeholder-hash)

    ;; Query translation.
    (url-retrieve
     (format insert-translated-name-api-url (url-hexify-string word))
     'insert-translated-name-retrieve-callback
     (list word (or style insert-translated-name-active-style) (current-buffer) placeholder))
    ))

(defun insert-translated-name-convert-translation (translation style)
  (let ((words (split-string translation " ")))
    (cond ((string-equal style "line")
           (string-join (mapcar 'downcase words) "-"))
          ((string-equal style "underline")
           (string-join (mapcar 'downcase words) "_"))
          ((string-equal style "camel")
           (concat (downcase (car words)) (string-join (mapcar 'capitalize (cdr words))))))))

(defun insert-translated-name-retrieve-callback (&optional redirect word style insert-buffer placeholder)
  (let (json word translation result)
    ;; Make sure buffer support multibyte.
    (set-buffer-multibyte t)

    ;; Init start of buffer.
    (goto-char (point-min))

    ;; Error if 200 response.
    (when (not (string-match "200 OK" (buffer-string)))
      (error "Problem connecting to the server"))

    ;; Get JSON data.
    (re-search-forward "^$" nil 'move)
    (setq json (json-read-from-string
                (buffer-substring-no-properties (point) (point-max))))
    (kill-buffer (current-buffer))

    ;; Pick up word, translation and result with code style.
    (setq word (assoc-default 'query json))
    (setq translation (elt (assoc-default 'translation json) 0))
    (setq result (insert-translated-name-convert-translation translation style))

    ;; Insert result with placeholder point.
    (with-current-buffer insert-buffer
      (let ((placeholder-point (gethash placeholder insert-translated-name-placeholder-hash)))
        (if placeholder-point
            (progn
              ;; Insert result at placeholder point .
              (goto-char placeholder-point)
              (insert result)

              ;; Remove placeholder from hash.
              (remhash placeholder insert-translated-name-placeholder-hash))
          (message (format "Something wrong that we can't found placeholder for %s: %s" word translation)))))))

(defun insert-translated-name--generate-uuid ()
  "Generate a 32 character UUID."
  (md5 (number-to-string (float-time))))

(provide 'insert-translated-name)

;;; insert-translated-name.el ends here
