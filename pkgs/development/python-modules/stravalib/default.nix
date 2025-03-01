{ lib
, arrow
, buildPythonPackage
, fetchFromGitHub
, pint
, pydantic_1 # use pydantic 2 on next release
, pythonOlder
, pytz
, requests
, responses
, setuptools
, setuptools-scm
}:

buildPythonPackage rec {
  pname = "stravalib";
  version = "1.5";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchFromGitHub {
    owner = "stravalib";
    repo = "stravalib";
    rev = "v${version}";
    hash = "sha256-EQcLDU9id/DpUZKMI9prCJC9zEK1CuhOtSB4FAWLg/g=";
  };

  postPatch = ''
    # Remove on next release
    sed -i 's/pydantic==1.10.9/pydantic/' pyproject.toml
  '';

  nativeBuildInputs = [
    setuptools
    setuptools-scm
  ];

  propagatedBuildInputs = [
    arrow
    pint
    pydantic_1
    pytz
    requests
    responses
  ];

  # Tests require network access, testing strava API
  doCheck = false;

  pythonImportsCheck = [
    "stravalib"
  ];

  meta = with lib; {
    description = "Python library for interacting with Strava v3 REST API";
    homepage = "https://github.com/stravalib/stravalib";
    changelog = "https://github.com/stravalib/stravalib/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ sikmir ];
  };
}
