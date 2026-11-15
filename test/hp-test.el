;;; hp-test.el --- Tests for publish.el  -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(load (expand-file-name "../publish.el" (file-name-directory (or load-file-name buffer-file-name))))

(defconst hp-test-dir
  (expand-file-name "fixtures/" (file-name-directory (or load-file-name buffer-file-name))))

(defun hp-test-fixture (name)
  (expand-file-name name hp-test-dir))

(defun hp-test-week (weeks n)
  (cl-find n weeks :key (lambda (w) (plist-get w :week))))

(ert-deftest hp-collect-weeks-basic ()
  (let* ((weeks (hp-collect-weeks (hp-test-fixture "phase-sample.org")))
         (w2 (hp-test-week weeks 2)))
    (should (= (length weeks) 3))
    (should (equal (plist-get w2 :state) "TODO"))
    (should (equal (plist-get w2 :id) "week-02"))
    (should (= (plist-get w2 :build-done) 1))
    (should (= (plist-get w2 :build-total) 3))
    (should (equal (plist-get w2 :next-item) "Build and measure the divider"))
    (should (plist-get (hp-test-week weeks 3) :optional))))

(ert-deftest hp-collect-ignores-non-weeks ()
  (let ((weeks (hp-collect-weeks (hp-test-fixture "phase-sample.org"))))
    (should-not (cl-find "Phase review" weeks
                         :key (lambda (w) (plist-get w :title)) :test #'equal))))

(ert-deftest hp-phase-summary-excludes-skipped ()
  (let ((s (hp-phase-summary (hp-test-fixture "phase-sample.org"))))
    (should (equal (plist-get s :title) "Phase 9: Sample"))
    (should (= (plist-get s :done) 1))
    (should (= (plist-get s :total) 2))))

(ert-deftest hp-current-week-prefers-doing ()
  (should (= 3 (plist-get (hp-current-week
                           (list '(:week 1 :state "DONE")
                                 '(:week 2 :state "TODO")
                                 '(:week 3 :state "DOING")))
                          :week)))
  (should (= 2 (plist-get (hp-current-week
                           (list '(:week 1 :state "DONE")
                                 '(:week 2 :state "TODO")))
                          :week)))
  (should-not (hp-current-week (list '(:week 1 :state "DONE")
                                     '(:week 2 :state "SKIPPED")))))

(ert-deftest hp-next-action-all-ticked ()
  (should (equal (hp-next-action '(:state "TODO" :build-done 2 :build-total 2 :next-item nil))
                 "Mark this week DONE"))
  (let ((w2 (hp-test-week (hp-collect-weeks (hp-test-fixture "phase-sample.org")) 2)))
    (should (equal (hp-next-action w2) "Build and measure the divider"))))

(ert-deftest hp-check-good ()
  (should-not (hp-check-file (hp-test-fixture "phase-sample.org"))))

(ert-deftest hp-check-bad ()
  (let ((errors (string-join (hp-check-file (hp-test-fixture "phase-bad.org")) "\n")))
    (should (string-match-p "Parts" errors))
    (should (string-match-p "details" errors))))

;;; hp-test.el ends here
