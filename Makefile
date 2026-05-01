ddl-ltlf:
	pandoc './Статья ddl-ltlf/papper.md' \
		--katex \
		--resource-path='./Статья ddl-ltlf/' \
		--citeproc \
		--reference-doc='./reference/it-standard-uncrappified.docx' \
		-o './out/Проказин, DDL-LTLf.docx'

mdl-design:
	pandoc './Статья mdl design/papper.md' \
		--katex \
		--resource-path='./Статья mdl design/' \
		--citeproc \
		--filter pandoc-plantuml \
		--reference-doc='./reference/it-standard-uncrappified.docx' \
		-o './out/Проказин, Дизайн MDL.docx'

nlp-linter:
	pandoc './Статья nlp linter/paper.md' \
		--katex \
		--resource-path='./Статья nlp linter/' \
		--citeproc \
		--reference-doc='./reference/mk-623ri-reference.docx' \
		--lua-filter='./reference/mk-623ri.lua' \
		-M udk='004' \
		-o './out/Проказин, NLP Linter.docx'
