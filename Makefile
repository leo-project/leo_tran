.PHONY: all compile xref eunit check_plt build_plt dialyzer doc callgraph graphviz clean distclean deps test ct shell

REBAR := rebar3
APPS = erts kernel stdlib sasl crypto compiler inets mnesia public_key runtime_tools snmp syntax_tools tools xmerl ssl
PLT_FILE = .leo_tran_dialyzer_plt
DOT_FILE = leo_tran.dot
CALL_GRAPH_FILE = leo_tran.png

all: deps compile xref eunit

deps:
	@$(REBAR) deps

compile:
	@$(REBAR) compile

xref:
	@$(REBAR) xref

eunit:
	@$(REBAR) eunit

test: eunit

ct:
	@$(REBAR) ct

check_plt:
	@$(REBAR) dialyzer --check-plt

build_plt:
	@$(REBAR) dialyzer --plt-build

dialyzer:
	@$(REBAR) dialyzer

doc:
	@$(REBAR) edoc

callgraph: graphviz
	dot -Tpng -o$(CALL_GRAPH_FILE) $(DOT_FILE)

graphviz:
	$(if $(shell which dot),,$(error "To make the depgraph, you need graphviz installed"))

shell:
	@$(REBAR) shell

clean:
	@$(REBAR) clean

distclean:
	@$(REBAR) clean -a
	@rm -rf _build
