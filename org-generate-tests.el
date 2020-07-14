;;; org-generate-tests.el --- Test definitions for org-generate  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; URL: https://github.com/conao3/org-generate.el

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Test definitions for `org-generate'.


;;; Code:

(require 'cort)
(require 'with-simulated-input)
(require 'org-generate)

(setq cort--dir
      (expand-file-name
       (format "org-generate-%04d" (random (round 1e4)))
       temporary-file-directory))

(defun cort--file-contents (path)
  "Get all contents of file located at PATH from `cort--dir'."
  (let ((path* (expand-file-name path cort--dir)))
    (unless (file-readable-p path*)
      (error "Missing file: %s" path*))
    (with-temp-buffer
      (insert-file-contents path*)
      (buffer-string))))

(defmacro with-cort--org-generate-buffer (contents &rest body)
  "Exec BODY in temp buffer that has CONTENTS."
  (declare (indent 1))
  `(let ((org-generate-root cort--dir)
         (org-generate--file-buffer (get-buffer-create "*temp*")))
     (with-current-buffer org-generate--file-buffer
       (insert ,contents)
       (goto-char (point-min))
       ,@body)))

(defmacro cort-deftest--org-generate (name testlst)
  "Define a test case with the NAME.
TESTLST is list of (GIVEN EXPECT)."
  (declare (indent 1))
  `(cort-deftest ,name
     (cort-generate-with-hook :equal
       (lambda () (mkdir cort--dir))
       (lambda () (ignore-errors (delete-directory cort--dir 'force)))
       ,testlst)))


;;; Test definition

(setq org-generate-show-save-message nil)

(cort-deftest org-generate/simple
  (cort-generate :equal
    '(((+ 2 3) 5))))

(cort-deftest--org-generate org-generate/onefile
  '(((with-cort--org-generate-buffer "\
* hugo
** page
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
"
       (buffer-string))
     "\
* hugo
** page
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
")

    ((with-cort--org-generate-buffer "\
* hugo
** page
*** page
#+begin_src markdown
  ---
  title: \"xxx\"
  date: xx/xx/xx
  draft: true
  ---

  ### 1. First
  xxxx

  ### 2. Second
  yyyy
#+end_src
"
       (org-generate "hugo/page")
       (cort--file-contents "page"))
     "\
---
title: \"xxx\"
date: xx/xx/xx
draft: true
---

### 1. First
xxxx

### 2. Second
yyyy
")))

(cort-deftest--org-generate org-genearte/heading-with-macro
  '(((with-cort--org-generate-buffer "\
#+OPTIONS: prop:t
#+MACRO: filename page.md
* hugo
** page
*** {{{filename}}}
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
"
       (org-generate "hugo/page")
       (cort--file-contents "page.md"))
     "\
---
title: \"xxx\"
---

### 1. First
xxxx
")))

(cort-deftest--org-generate org-genearte/heading-with-macro-using-user-input
  '(((with-cort--org-generate-buffer "\
#+OPTIONS: prop:t
#+MACRO: get-directory (eval (format \"%s/\" (read-string \"Filename: \")))
* hugo
** page
*** {{{get-directory}}}
**** page.md
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
"
       (with-simulated-input
           "awesome RET"
         (org-generate "hugo/page"))
       (cort--file-contents "awesome/page.md"))
     "\
---
title: \"xxx\"
---

### 1. First
xxxx
")))

(cort-deftest--org-generate org-genearte/set-variable-with-macro
  '(((with-cort--org-generate-buffer "\
#+OPTIONS: prop:t
#+NAME: hugo-root
#+MACRO: hugo-root (eval (concat \":org-generate-root: \" (org-sbe \"hugo-root\") $1))
* hugo
** page
:PROPERTIES:
{{{hugo-root(content/blog/)}}}
:END:
*** page.md
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
"
       (let ((org-generate-root nil))
         (with-simulated-input
             (format "%s RET" cort--dir)
           (org-generate "hugo/page")))
       (cort--file-contents "content/blog/page.md"))
     "\
---
title: \"xxx\"
---

### 1. First
xxxx
")))

(cort-deftest--org-generate org-genearte/set-variable-using-property
  '(((with-cort--org-generate-buffer (format "\
#+OPTIONS: prop:t
#+MACRO: hugo-root-path (eval (concat \":org-generate-root: \" (org-entry-get-with-inheritance \"root\") $1))
* hugo
:PROPERTIES:
:root: %s/
:END:
** page
:PROPERTIES:
{{{hugo-root-path(content/blog/)}}}
:END:
*** page.md
#+begin_src markdown
  ---
  title: \"xxx\"
  ---

  ### 1. First
  xxxx
#+end_src
" cort--dir)
       (mkdir (expand-file-name "content/blog" cort--dir) 'parents)
       (let ((org-generate-root nil))
         (org-generate "hugo/page"))
       (cort--file-contents "content/blog/page.md"))
     "\
---
title: \"xxx\"
---

### 1. First
xxxx
")

    ((with-cort--org-generate-buffer (format "\
#+OPTIONS: prop:t
#+NAME: root
#+BEGIN_SRC emacs-lisp :exports none :results raw :var path=\"\"
  (concat \":org-generate-root: \"
          (org-entry-get-with-inheritance \"root\")
          (format \"%%s\" path))
#+END_SRC
#+MACRO: hugo-root-path (eval (org-sbe \"root\" (path $$1)))
* hugo
:PROPERTIES:
:root: %s/
:END:
** page
:PROPERTIES:
{{{hugo-root-path(content/blog/)}}}
:END:
" cort--dir)
       (mkdir (expand-file-name "content/blog" cort--dir) 'parents)
       (let ((org-generate-root nil))
         (org-generate "hugo/page"))
       (cort--file-contents "content/blog/page.md"))
     "\
---
title: \"xxx\"
---

### 1. First
xxxx
")))

;; (provide 'org-generate-tests)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; org-generate-tests.el ends here
