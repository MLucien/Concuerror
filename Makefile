###-----------------------------------------------------------------------------
### Application info
###-----------------------------------------------------------------------------

NAME := concuerror
VERSION := 0.13

.PHONY: default dev
default dev: $(NAME)

###-----------------------------------------------------------------------------
### Files
###-----------------------------------------------------------------------------

DEPS = getopt/ebin/getopt
DEPS_BEAMS=$(DEPS:%=deps/%.beam)

SOURCES = $(wildcard src/*.erl)
MODULES = $(SOURCES:src/%.erl=%)
BEAMS = $(MODULES:%=ebin/%.beam)

VERSION_HRL=src/concuerror_version.hrl

###-----------------------------------------------------------------------------
### Compile
###-----------------------------------------------------------------------------

ERL_COMPILE_FLAGS := \
	+debug_info \
	+warn_export_vars \
	+warn_unused_import \
	+warn_missing_spec \
	+warn_untyped_record \
	+warnings_as_errors

dev: ERL_COMPILE_FLAGS += -DDEV=true
dev: VERSION := $(VERSION)-dev

$(NAME): $(DEPS_BEAMS) $(BEAMS)
	@$(RM) $@
	@echo " GEN  $@"
	@ln -s src/$(NAME) $@

###-----------------------------------------------------------------------------

-include $(MODULES:%=ebin/%.Pbeam)

ebin/%.beam: src/%.erl Makefile | ebin $(VERSION_HRL)
	@echo " DEPS $<"
	@erlc -o ebin -MD -MG $<
	@echo " ERLC $<"
	@erlc $(ERL_COMPILE_FLAGS) -o ebin $<

###-----------------------------------------------------------------------------

$(VERSION_HRL): version
	@echo " GEN  $@"
	@src/versions $(VERSION) > $@.tmp
	@cmp -s $@.tmp $@ > /dev/null || cp $@.tmp $@
	@rm $@.tmp

.PHONY: version
version:

###-----------------------------------------------------------------------------

ebin cover-data:
	@echo " MKDIR $@"
	@mkdir $@

###-----------------------------------------------------------------------------
### Dependencies
###-----------------------------------------------------------------------------

%/ebin/getopt.beam: %/.git
	$(MAKE) -C $(dir $<)
	$(RM) -r $(dir $<).rebar

deps/%/.git:
	git submodule update --init

###-----------------------------------------------------------------------------
### Dialyzer
###-----------------------------------------------------------------------------

PLT=.$(NAME)_plt

DIALYZER_APPS = erts kernel stdlib compiler crypto
DIALYZER_FLAGS = -Wunmatched_returns -Wunderspecs

.PHONY: dialyze
dialyze: default $(PLT) $(DEPS_BEAMS)
	dialyzer --add_to_plt --plt $(PLT) $(DEPS_BEAMS)
	dialyzer --plt $(PLT) $(DIALYZER_FLAGS) ebin/*.beam

$(PLT):
	dialyzer --build_plt --output_plt $@ --apps $(DIALYZER_APPS) $^

###-----------------------------------------------------------------------------
### Testing
###-----------------------------------------------------------------------------

SUITES = {advanced_tests,dpor_tests,basic_tests}

.PHONY: tests
tests:
	@$(RM) $@/thediff
	@(cd $@; bash -c "./runtests.py suites/$(SUITES)/src/*")

.PHONY: tests-long
tests-long: default
	@$(RM) $@/thediff
	$(MAKE) -C $@ \
		CONCUERROR=$(abspath concuerror) \
		DIFFER=$(abspath tests/differ) \
		DIFFPRINTER=$(abspath $@/thediff)

%/scenarios.beam: %/scenarios.erl
	erlc -o $(@D) $<

###-----------------------------------------------------------------------------
### Cover
###-----------------------------------------------------------------------------

.PHONY: cover
cover: cover-data
	export CONCUERROR_COVER=true; $(MAKE) tests tests-long
	tests/cover-report

###-----------------------------------------------------------------------------
### Travis
###-----------------------------------------------------------------------------

.PHONY: travis_has_latest_otp_version
travis_has_latest_otp_version:
	./travis/$@

###-----------------------------------------------------------------------------
### Clean
###-----------------------------------------------------------------------------

.PHONY: clean
clean:
	$(RM) $(NAME) $(VERSION_HRL) concuerror_report.txt
	$(RM) -r ebin cover-data

.PHONY: distclean
distclean: clean
	$(RM) $(PLT)
	$(RM) -r deps/*
	git checkout -- deps
