{
  lib,
  buildPythonPackage,
  fetchPypi,
  poetry-core,
  babel,
  lxml,
  python-docx,
}:

buildPythonPackage rec {
  pname = "docxcompose";
  version = "2.2.0";

  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-4saXA6L++tRHGq2ChhocXXs/SmaVEN5QS7NvQfZvbT4=";
  };

  build-system = [
    poetry-core
  ];

  dependencies = [
    babel
    lxml
    python-docx
  ];

  pythonImportsCheck = [
    "docxcompose"
    "docxcompose.composer"
  ];

  # У пакета тесты требуют дополнительные fixture-файлы/окружение,
  # для dev shell проще отключить.
  doCheck = false;

  meta = {
    description = "Library for composing Word .docx files";
    homepage = "https://pypi.org/project/docxcompose/";
    license = lib.licenses.mit;
  };
}