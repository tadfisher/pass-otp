{ lib
, stdenv
, oathToolkit
, bash
, expect
, git
, gnumake
, gnupg
, pass
, shellcheck
, which
}:

stdenv.mkDerivation {
  pname = "pass-otp";
  version = "unstable";
  src = ./.;

  buildInputs = [ oathToolkit ];

  checkInputs = [
    bash
    expect
    git
    gnumake
    gnupg
    pass
    shellcheck
    which
  ];

  dontBuild = true;
  doCheck = true;

  patchPhase = ''
    sed -i -e 's|OATH=\$(which oathtool)|OATH=${oathToolkit}/bin/oathtool|' otp.bash
  '';

  checkPhase = ''
    make check
  '';

  installFlags = [
    "PREFIX=$(out)"
    "BASHCOMPDIR=$(out)/share/bash-completions/completions"
  ];

  meta = with lib; {
    description = "A pass extension for managing one-time-password (OTP) tokens";
    homepage = "https://github.com/tadfisher/pass-otp";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ tadfisher ];
    platforms = platforms.unix;
  };
}
