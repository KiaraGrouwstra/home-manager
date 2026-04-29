{ pkgs, ... }:
{
  imports = [ ../../../modules/testing/hardcoded-secret.nix ];

  testing.hardcoded-secret.fileSecrets.demo_token = {
    request.mode = "0600";
    content = "s3cret";
  };
  contracts.fileSecrets.defaultProviderName = "hardcoded-secret";

  home.services.demo = {
    process.argv = [ "${pkgs.coreutils}/bin/true" ];
    contracts.fileSecrets.want.token.request.mode = "0600";
  };

  nmt.script = ''
    assertFileExists home-files/.config/systemd/user/demo.service
    assertFileRegex activate \
      'install -m 0600 .* .*/hardcoded-secrets/demo_token'
  '';
}
