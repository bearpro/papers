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
