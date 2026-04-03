ddl-ltlf:
	pandoc './Статья ddl-ltlf/papper.md' \
		--katex \
		--resource-path='./Статья ddl-ltlf/' \
		--citeproc \
		-o './out/Проказин, DDL-LTLf.docx'
