-include config.mk

PKG = epkg

ELS   = $(PKG).el
ELS  += $(PKG)-desc.el
ELS  += $(PKG)-list.el
ELS  += $(PKG)-gelpa.el
ELS  += $(PKG)-melpa.el
ELS  += $(PKG)-schemata.el
ELS  += $(PKG)-util.el
ELCS  = $(ELS:.el=.elc)

DEPS  = closql
DEPS += dash
DEPS += emacsql
DEPS += finalize

EMACS  ?= emacs
EFLAGS ?=
DFLAGS ?= $(addprefix -L ../,$(DEPS))
OFLAGS ?= -L ../dash -L ../org/lisp -L ../ox-texinfo+ -L ../magit/lisp -L ../with-editor

INSTALL_INFO     ?= $(shell command -v ginstall-info || printf install-info)
MAKEINFO         ?= makeinfo
MANUAL_HTML_ARGS ?= --css-ref /assets/the.css

ifdef VERSION
GITDESC := v$(VERSION)
else
VERSION := $(shell test -e .git && git tag | cut -c2- | sort --version-sort | tail -1)
GITDESC := $(shell test -e .git && git describe --tags)"+1"
endif

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
	$(info make bump-version - bump version strings)
	$(info make preview      - preview html and pdf manuals)
	$(info make publish      - publish html and pdf manuals)
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

set-version:
	@sed -i \
	-e "s/\(#+SUBTITLE: for version \).*/\1$(VERSION) ($(GITDESC))/" \
	-e "s/\(This manual is for $(shell echo $(PKG) | \
        sed 's/.*/\u&/') version \).*/\1$(VERSION) ($(GITDESC))./" \
	$(PKG).org

texi: set-version $(PKG).texi
info: $(PKG).info dir
html: $(PKG).html
pdf:  $(PKG).pdf

%.texi: %.org
	@printf "Generating $@\n"
	@$(EMACS) -Q --batch $(OFLAGS) \
	-l ox-extra.el -l ox-texinfo+.el $< -f org-texinfo-export-to-texinfo
	@printf "\n" >> $@
	@rm -f $@~

%.info: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --no-split $< -o $@

dir: $(PKG).info
	@printf "Generating $@\n"
	@printf "%s" $^ | xargs -n 1 $(INSTALL_INFO) --dir=$@

%.html: %.texi
	@printf "Generating $@\n"
	@$(MAKEINFO) --html --no-split $(MANUAL_HTML_ARGS) $<

html-dir: $(PKG).texi
	@printf "Generating $(PKG)/*.html\n"
	@$(MAKEINFO) --html $(MANUAL_HTML_ARGS) $<

%.pdf: %.texi
	@printf "Generating $@\n"
	@texi2pdf --clean $< > /dev/null

DOMAIN         ?= emacsmirror.net
CFRONT_DIST    ?= E1IXJGPIOM4EUW
PUBLISH_BUCKET ?= s3://$(DOMAIN)
PREVIEW_BUCKET ?= s3://preview.$(DOMAIN)
PUBLISH_TARGET ?= $(PUBLISH_BUCKET)/manual/
PREVIEW_TARGET ?= $(PREVIEW_BUCKET)/manual/

preview: html html-dir pdf
	@aws s3 cp $(PKG).html $(PREVIEW_TARGET)
	@aws s3 cp $(PKG).pdf $(PREVIEW_TARGET)
	@aws s3 sync $(PKG) $(PREVIEW_TARGET)$(PKG)/

publish: html html-dir pdf
	@aws s3 cp $(PKG).html $(PUBLISH_TARGET)
	@aws s3 cp $(PKG).pdf $(PUBLISH_TARGET)
	@aws s3 sync $(PKG) $(PUBLISH_TARGET)$(PKG)/
	@aws cloudfront create-invalidation \
	--distribution-id $(CFRONT_DIST) \
	--paths "/manual/$(PKG).html,/manual/$(PKG).pdf,/manual/$(PKG)/*"

CLEAN  = $(ELCS) $(PKG)-autoloads.el $(PKG).info dir
CLEAN += $(PKG) $(PKG).html $(PKG).pdf

clean:
	@printf "Cleaning...\n"
	@rm -rf $(CLEAN)

clean-texi:
	@printf "Cleaning...\n"
	@rm -f $(PKG).texi

clean-all:
	@printf "Cleaning...\n"
	@rm -rf $(CLEAN) $(PKG).texi

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
	(update-directory-autoloads default-directory))"
