{ lib, pkgs, ... }:

let
  kb = lib.hm.keybindings;

  # Single combo: Ctrl+C
  ctrlC = kb.mkBind [ "ctrl" ] "c";

  # Single combo: Super+Shift+Return
  superShiftReturn = kb.mkBind [ "super" "shift" ] "Return";

  # Modifier-only: bare Super
  superOnly = kb.mkBind [ "super" ] null;

  # Sequence: Emacs C-x C-s
  emacsSeq = [
    (kb.mkBind [ "ctrl" ] "x")
    (kb.mkBind [ "ctrl" ] "s")
  ];

  results = ''
    i3-ctrl-c: ${kb.toI3 ctrlC}
    i3-super-shift-return: ${kb.toI3 superShiftReturn}
    i3-super-only: ${kb.toI3 superOnly}
    hyprland-ctrl-c: ${kb.toHyprland ctrlC}
    hyprland-super-shift-return: ${kb.toHyprland superShiftReturn}
    hyprland-super-only: ${kb.toHyprland superOnly}
    xkb-ctrl-c: ${kb.toXKB ctrlC}
    xkb-super-shift-return: ${kb.toXKB superShiftReturn}
    xkb-super-only: ${kb.toXKB superOnly}
    electron-ctrl-c: ${kb.toElectron ctrlC}
    electron-super-shift-return: ${kb.toElectron superShiftReturn}
    gdk-ctrl-c: ${kb.toGDK ctrlC}
    gdk-super-shift-return: ${kb.toGDK superShiftReturn}
    emacs-ctrl-c: ${kb.toEmacs ctrlC}
    emacs-super-shift-return: ${kb.toEmacs superShiftReturn}
    emacs-seq: ${kb.toEmacs emacsSeq}
    kitty-ctrl-c: ${kb.toKitty ctrlC}
    kitty-super-shift-return: ${kb.toKitty superShiftReturn}
    kitty-seq: ${kb.toKitty emacsSeq}
  '';

in
{
  home.file."keybindings-results.txt".text = results;

  nmt.script = ''
    assertFileContent \
      home-files/keybindings-results.txt \
      ${pkgs.writeText "expected-keybindings.txt" ''
        i3-ctrl-c: ctrl+c
        i3-super-shift-return: Mod4+shift+Return
        i3-super-only: Mod4
        hyprland-ctrl-c: CTRL, c
        hyprland-super-shift-return: SUPER SHIFT, Return
        hyprland-super-only: SUPER
        xkb-ctrl-c: <Control>c
        xkb-super-shift-return: <Super><Shift>Return
        xkb-super-only: <Super>
        electron-ctrl-c: Ctrl+c
        electron-super-shift-return: Super+Shift+Return
        gdk-ctrl-c: <Primary>c
        gdk-super-shift-return: <Super><Shift>Return
        emacs-ctrl-c: C-c
        emacs-super-shift-return: s-S-Return
        emacs-seq: C-x C-s
        kitty-ctrl-c: ctrl+c
        kitty-super-shift-return: super+shift+Return
        kitty-seq: ctrl+x ctrl+s
      ''}
  '';
}
