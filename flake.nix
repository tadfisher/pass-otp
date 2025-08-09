{
  description = "A pass extension for managing one-time-password (OTP) tokens";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        defaultPackage = self.packages.${system}.pass-otp;

        packages = {
          pass-otp = pkgs.callPackage ./default.nix { };

          pass-with-otp = pkgs.pass.withExtensions (e: [ self.packages.${system}.pass-otp ]);
        };

        checks.pass-otp = self.defaultPackage.${system};
      }
    );
}
