;;; publish.el --- Build the Hardware Path site  -*- lexical-binding: t; -*-

;; The Org files in `hp-plan-dir' are the only source of truth.  This file
;; reads progress from them (week TODO states and Build checkboxes), checks
;; their structure, and publishes them as HTML with a dashboard.

(require 'org)
(require 'org-element)
(require 'cl-lib)
(require 'subr-x)

(defvar hp-plan-dir "plan/"
  "Directory holding the plan's Org files.")

(defvar hp-site-dir "_site/"
  "Directory the site is published into.")

(defconst hp-week-sections '("Learn" "Build" "Parts" "Checkpoint" "Notes")
  "Required subheadings of every week, in order.")

(defconst hp-note-sections '("Expected" "Measured" "Different and why" "Next")
  "Required subheadings of every week's Notes.")

(defconst hp-todo-line "TODO DOING | DONE SKIPPED"
  "The #+TODO keywords every phase file must declare.")

;;; Parsing

(defun hp--parse (file)
  "Return the Org element tree of FILE, honoring its #+TODO line."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((org-inhibit-startup t))
      (org-mode))
    (org-element-parse-buffer)))

(defun hp--title (tree)
  "Return the #+TITLE value in TREE, or nil."
  (org-element-map tree 'keyword
    (lambda (k)
      (when (equal (org-element-property :key k) "TITLE")
        (org-element-property :value k)))
    nil t))

(defun hp--heading-name (headline)
  "Return HEADLINE's title without a statistics cookie."
  (string-trim
   (replace-regexp-in-string "\\[[0-9]*%?/?[0-9]*%?\\]" ""
                             (org-element-property :raw-value headline))))

(defun hp--children (headline)
  "Return the direct child headlines of HEADLINE."
  (cl-remove-if-not (lambda (e) (eq (org-element-type e) 'headline))
                    (org-element-contents headline)))

(defun hp--child (headline name)
  "Return HEADLINE's direct child headline called NAME, or nil."
  (cl-find name (hp--children headline) :key #'hp--heading-name :test #'equal))

(defun hp--week-p (headline)
  "Non-nil when HEADLINE is a top-level week heading."
  (and (= (org-element-property :level headline) 1)
       (org-element-property :WEEK headline)))

(defun hp--weeks (tree)
  "Return the week headlines of TREE in document order."
  (org-element-map tree 'headline
    (lambda (h) (when (hp--week-p h) h))
    nil nil 'headline))

(defun hp--item-text (item)
  "Return ITEM's text as plain one-line text, with Org links reduced."
  (let ((text (string-trim (org-element-interpret-data (org-element-contents item)))))
    (setq text (replace-regexp-in-string "\\[\\[[^]]*\\]\\[\\([^]]*\\)\\]\\]" "\\1" text))
    (setq text (replace-regexp-in-string "\\[\\[\\([^]]*\\)\\]\\]" "\\1" text))
    (replace-regexp-in-string "[ \t\n]+" " " text)))

(defun hp--checkboxes (headline)
  "Return the checkbox items under HEADLINE as (TEXT . TICKED) pairs."
  (when headline
    (org-element-map (org-element-contents headline) 'item
      (lambda (i)
        (when-let* ((box (org-element-property :checkbox i)))
          (cons (hp--item-text i) (eq box 'on))))
      nil nil 'headline)))

;;; Progress

(defun hp-collect-weeks (file)
  "Return a plist for each week in FILE.
Keys: :file :title :week :id :state :optional :build-done :build-total
:next-item."
  (mapcar
   (lambda (h)
     (let ((boxes (hp--checkboxes (hp--child h "Build"))))
       (list :file file
             :title (hp--heading-name h)
             :week (string-to-number (org-element-property :WEEK h))
             :id (org-element-property :CUSTOM_ID h)
             :state (org-element-property :todo-keyword h)
             :optional (equal (org-element-property :OPTIONAL h) "t")
             :build-done (cl-count-if #'cdr boxes)
             :build-total (length boxes)
             :next-item (car (cl-find-if-not #'cdr boxes)))))
   (hp--weeks (hp--parse file))))

(defun hp-phase-summary (file)
  "Return a plist summarizing FILE: :file :title :done :total :weeks.
Skipped weeks are left out of :total."
  (let ((weeks (hp-collect-weeks file)))
    (list :file file
          :title (or (hp--title (hp--parse file)) (file-name-base file))
          :done (cl-count "DONE" weeks :key (lambda (w) (plist-get w :state)) :test #'equal)
          :total (cl-count-if-not (lambda (w) (equal (plist-get w :state) "SKIPPED")) weeks)
          :weeks weeks)))

(defun hp-current-week (weeks)
  "Return the first DOING week in WEEKS, else the first TODO week, else nil."
  (let ((state (lambda (w) (plist-get w :state))))
    (or (cl-find "DOING" weeks :key state :test #'equal)
        (cl-find "TODO" weeks :key state :test #'equal))))

(defun hp-next-action (week)
  "Return the next thing to do in WEEK."
  (or (plist-get week :next-item) "Mark this week DONE"))

(defun hp-phase-files ()
  "Return the phase files in `hp-plan-dir', sorted."
  (directory-files hp-plan-dir t "\\`0[1-8]-.*\\.org\\'"))

;;; Structure check

(defun hp--check-week (h)
  "Return structure errors for week headline H."
  (let* ((n (org-element-property :WEEK h))
         (label (format "Week %s" n))
         (children (hp--children h))
         (names (mapcar #'hp--heading-name children))
         errors)
    (cl-flet ((err (fmt &rest args)
                (push (concat label ": " (apply #'format fmt args)) errors)))
      (unless (org-element-property :todo-keyword h)
        (err "heading has no TODO state"))
      (unless (equal (org-element-property :CUSTOM_ID h)
                     (format "week-%02d" (string-to-number n)))
        (err "CUSTOM_ID must be week-%02d" (string-to-number n)))
      (unless (equal names hp-week-sections)
        (err "subheadings must be %s; found %s"
             (string-join hp-week-sections ", ") (string-join names ", ")))
      (dolist (c children)
        (when (org-element-property :todo-keyword c)
          (err "subheading %s must not have a TODO state" (hp--heading-name c))))
      (when-let* ((build (hp--child h "Build")))
        (unless (string-match-p "\\[[0-9]*/[0-9]*\\]" (org-element-property :raw-value build))
          (err "Build heading needs a [/] cookie"))
        (unless (hp--checkboxes build)
          (err "Build has no checkbox items")))
      (when-let* ((cp (hp--child h "Checkpoint")))
        (unless (org-element-map (org-element-contents cp) 'special-block
                  (lambda (b)
                    (and (equal (downcase (org-element-property :type b)) "details")
                         (string-match-p "Check your answer"
                                         (org-element-interpret-data b))))
                  nil t)
          (err "Checkpoint has no details block with \"Check your answer\"")))
      (when-let* ((notes (hp--child h "Notes")))
        (unless (equal (mapcar #'hp--heading-name (hp--children notes)) hp-note-sections)
          (err "Notes subheadings must be %s" (string-join hp-note-sections ", ")))))
    (nreverse errors)))

(defun hp-check-file (file)
  "Return a list of structure errors in FILE; nil when it is valid."
  (let* ((tree (hp--parse file))
         (raw (with-temp-buffer (insert-file-contents file) (buffer-string)))
         (tops (org-element-map tree 'headline
                 (lambda (h) (when (= (org-element-property :level h) 1) h))))
         (last-top (car (last tops)))
         errors)
    (unless (hp--title tree)
      (push "missing #+TITLE" errors))
    (unless (string-match-p (concat "^#\\+TODO: " (regexp-quote hp-todo-line) "[ \t]*$") raw)
      (push (concat "missing \"#+TODO: " hp-todo-line "\"") errors))
    (unless (hp--weeks tree)
      (push "no week headings" errors))
    (unless (and last-top
                 (equal (hp--heading-name last-top) "Phase review")
                 (not (org-element-property :todo-keyword last-top)))
      (push "last top-level heading must be \"Phase review\" with no TODO state" errors))
    (append (nreverse errors)
            (mapcan #'hp--check-week (hp--weeks tree)))))

(defun hp-check-all ()
  "Check every phase file; exit non-zero on any error."
  (let ((files (hp-phase-files))
        (failed nil))
    (unless files
      (message "No phase files in %s" hp-plan-dir)
      (kill-emacs 1))
    (dolist (f files)
      (dolist (e (hp-check-file f))
        (setq failed t)
        (message "%s: %s" (file-name-nondirectory f) e)))
    (if failed
        (kill-emacs 1)
      (message "OK: %d phase files" (length files)))))

;;; publish.el ends here
