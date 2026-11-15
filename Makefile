EMACS ?= emacs
BATCH = $(EMACS) -Q --batch -L .

.PHONY: test check site clean

test:
	$(BATCH) -l test/hp-test.el -f ert-run-tests-batch-and-exit

check:
	$(BATCH) -l publish.el -f hp-check-all

site:
	$(BATCH) -l publish.el -f hp-build-site

clean:
	rm -rf _site
