_out-dir:
	mkdir -p ./out

ddl-ltlf: _out-dir
	pandoc './papers/01-ddl-ltlf/papper.md' \
		--katex \
		--resource-path='./papers/01-ddl-ltlf/' \
		--citeproc \
		--reference-doc='./reference/it-standard-uncrappified.docx' \
		-o './out/Проказин, DDL-LTLf.docx'

nlp-linter: _out-dir
	pandoc './papers/02-nlp-linter/paper.md' \
		--katex \
		--resource-path='./papers/02-nlp-linter/' \
		--citeproc \
		--reference-doc='./reference/mk-623ri-reference.docx' \
		--lua-filter='./reference/mk-623ri.lua' \
		-M udk='004' \
		-o './out/Проказин, NLP Linter.docx'


mdl-design: _out-dir
	pandoc './papers/03-mdl-design/papper.md' \
		--katex \
		--resource-path='./papers/03-mdl-design/' \
		--citeproc \
		--filter pandoc-plantuml \
		--reference-doc='./reference/it-standard-uncrappified.docx' \
		-o './out/Проказин, Дизайн MDL.docx'

dissertation-full: _out-dir
	pandoc --defaults ./dissertation/full/main.yml \
		--katex \
		--filter pandoc-plantuml \
		--reference-doc='./reference/mk-623ri-reference.docx' \
		--lua-filter='./reference/mk-623ri.lua' \
		--resource-path='./dissertation/full/' \
		-o './out/Проказин, Автореферат к диссертации.docx'
