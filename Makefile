-include config.mk

PKG = epkg

ELS   = $(PKG).el
ELS  += $(PKG)-desc.el
ELS  += $(PKG)-list.el
ELCS  = $(ELS:.el=.elc)

DEPS  = closql
DEPS += dash
DEPS += emacsql
DEPS += finalize

EMACS  ?= emacs
EFLAGS ?=
DFLAGS ?= $(addprefix -L ../,$(DEPS))
OFLAGS ?= -L ../dash -L ../org/lisp -L ../ox-texinfo+

INSTALL_INFO     ?= $(shell command -v ginstall-info || printf install-info)
MAKEINFO         ?= makeinfo
MANUAL_HTML_ARGS ?= --css-ref /the.css

VERSION := $(shell test -e .git && \
	git tag | cut -c2- | sort --version-sort | tail -1)

all: lisp info
doc: info html html-dir pdf

help:
	$(info make all          - generate lisp and manual)
	$(info make doc          - generate most manual formats)
	$(info make lisp         - generate byte-code and autoloads)
	$(info make texi         - generate texi manual)
	$(info make info         - generate info manual)
	$(info make html         - generate html manual file)
	$(info make html-dir     - generate html manual directory)
	$(info make pdf          - generate pdf manual)
	$(info make publish      - publish html manual)
	$(info make clean        - remove most generated files)
	$(info make clean-texi   - remove (tracked) texi manual)
	$(info make clean-all    - remove all generated files)
	@printf "\n"

lisp: $(ELCS) loaddefs

loaddefs: $(PKG)-autoloads.el

$(PKG).elc:
$(PKG)-desc.elc: $(PKG).elc
$(PKG)-list.elc: $(PKG).elc

%.elc: %.el
	@printf "Compiling $<\n"
	@$(EMACS) -Q --batch $(EFLAGS) -L . $(DFLAGS) -f batch-byte-compile $<

texi: $(PKG).texi
info: $(PKG).info dir
html: $(PKG).html
pdf:  $(PKG).pdf

%.texi: %.org
	@printf "Generating $@\n"
	@$(EMACS) -Q --batch $(OFLAGS) \
	-l ox-texinfo+.el $< -f org-texinfo+export-to-texinfo
	@printf "\n" >> $@
	@sed -i -e '/^@title /a@subtitle for version $(VERSION)' $@
	@rm -f $@~

%.info: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --no-split $< -o $@

dir: $(PKG).info
	@printf "Generating $@\n"
	@printf "%s" $^ | xargs -n 1 $(INSTALL_INFO) --dir=$@

%.html: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --html --no-split $(MAKEINFO_HMTL_ARGS) $<

html-dir: $(PKG).texi
	@printf "Generating $(PKG)/*.html\n"
	@$(MAKEINFO) --html $(MAKEINFO_HTML_ARGS) $<

%.pdf: %.texi
	@printf "Generating $@\n"
	@texi2pdf --clean $< > /dev/null

publish: html html-dir
	@aws s3 cp $(PKG).html "s3://emacsmirror.net/manual/"
	@aws s3 cp $(PKG).pdf "s3://emacsmirror.net/manual/"
	@aws s3 sync $(PKG) "s3://emacsmirror.net/manual/$(PKG)/"

CLEAN = $(ELCS) $(PKG)-autoloads.el $(PKG).info dir

clean:
	@printf "Cleaning...\n"
	@rm -f $(CLEAN)

clean-texi:
	@printf "Cleaning...\n"
	@rm -f $(PKG).texi

clean-all:
	@printf "Cleaning...\n"
	@rm -f $(CLEAN) $(PKG).texi

define LOADDEFS_TMPL
;;; $(PKG)-autoloads.el --- automatically extracted autoloads
;;
;;; Code:
(add-to-list 'load-path (directory-file-name \
(or (file-name-directory #$$) (car load-path))))

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; End:
;;; $(PKG)-autoloads.el ends here
endef
export LOADDEFS_TMPL
#'

$(PKG)-autoloads.el: $(ELS)
	@printf "Generating $@\n"
	@printf "%s" "$$LOADDEFS_TMPL" > $@
	@$(EMACS) -Q --batch --eval "(progn\
	(setq make-backup-files nil)\
	(setq vc-handled-backends nil)\
	(setq default-directory (file-truename default-directory))\
	(setq generated-autoload-file (expand-file-name \"$@\"))\
	(setq find-file-visit-truename t)\
	(update-directory-autoloads default-directory)))"
