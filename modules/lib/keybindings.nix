{ lib }:

let
  inherit (lib)
    concatStringsSep
    mkOption
    optional
    types
    ;

  # ---------------------------------------------------------------------------
  # Types

  # Canonical modifier names. These map to modifier keys across all supported
  # application formats.
  modifierType = types.enum [
    "ctrl"
    "shift"
    "alt"
    "super"
    "altgr"
    "hyper"
  ];

  # A single key press: zero or more modifiers held while pressing a key.
  #
  # `key` is an XKB keysym name, e.g. "a", "Return", "F1", "space".
  # Set `key = null` for modifier-only bindings (e.g. bare Super in GNOME).
  #
  # `mods` is a list of canonical modifier names from `modifierType`.
  keyComboType = types.submodule {
    options = {
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          XKB keysym name for the pressed key, e.g. "a", "Return", "F1".
          Set to null for modifier-only bindings.
        '';
        example = "Return";
      };
      mods = mkOption {
        type = types.listOf modifierType;
        default = [ ];
        description = ''
          Modifiers held during this key press, using canonical names:
          "ctrl", "shift", "alt", "super", "altgr", "hyper".
        '';
        example = [
          "ctrl"
          "shift"
        ];
      };
    };
  };

  # A full keybinding: a single key combo or a sequence of combos.
  # Sequences (e.g. Emacs-style C-x C-s) are represented as a non-empty list.
  # Not all application formats support sequences; converters will throw for
  # those when given a list with more than one element.
  keybindingType = types.either keyComboType (types.nonEmptyListOf keyComboType);

  # ---------------------------------------------------------------------------
  # Helpers

  # Normalize any keybindingType value to a list of key combos.
  normalize = binding: if builtins.isList binding then binding else [ binding ];

  # Convenience constructor: mkBind ["ctrl" "shift"] "c"
  mkBind = mods: key: { inherit mods key; };

  # Assert a binding is a single combo (no sequence), for formats that don't
  # support sequences.
  assertSingle = formatName: binding:
    let combos = normalize binding;
    in
    if builtins.length combos > 1
    then builtins.throw "${formatName} does not support key sequences"
    else builtins.head combos;

  # Generic single-combo formatter: join mapped mods and optional key with sep.
  formatCombo = sep: modMap: combo:
    let
      parts = map (m: modMap.${m}) combo.mods
        ++ optional (combo.key != null) combo.key;
    in
    concatStringsSep sep parts;

  # ---------------------------------------------------------------------------
  # Format converters
  #
  # Each converter accepts a `keybindingType` value and returns a string in
  # the target application's native format.

  # i3 / sway: "Mod4+shift+Return"
  # https://i3wm.org/docs/userguide.html#keybindings
  toI3 = binding:
    let
      modMap = {
        ctrl = "ctrl";
        shift = "shift";
        alt = "Mod1";
        super = "Mod4";
        altgr = "Mod5";
        hyper = "Mod3";
      };
    in
    formatCombo "+" modMap (assertSingle "i3/sway" binding);

  toSway = toI3;

  # Hyprland: "SUPER SHIFT, Return"
  # The returned string is suitable as the MODS, KEY part of a bind statement:
  #   bind = ${toHyprland combo}, exec, foot
  # https://wiki.hyprland.org/Configuring/Binds/
  toHyprland = binding:
    let
      modMap = {
        ctrl = "CTRL";
        shift = "SHIFT";
        alt = "ALT";
        super = "SUPER";
        altgr = "MOD5";
        hyper = "MOD3";
      };
      combo = assertSingle "Hyprland" binding;
      modsStr = concatStringsSep " " (map (m: modMap.${m}) combo.mods);
      keyStr = if combo.key != null then combo.key else "";
    in
    if modsStr == "" then keyStr
    else if keyStr == "" then modsStr
    else "${modsStr}, ${keyStr}";

  # XKB: "<Super><Shift>Return"
  # https://xkbcommon.org/doc/current/keymap-text-format-v1-v2.html
  toXKB = binding:
    let
      modMap = {
        ctrl = "<Control>";
        shift = "<Shift>";
        alt = "<Alt>";
        super = "<Super>";
        altgr = "<AltGr>";
        hyper = "<Hyper>";
      };
      combo = assertSingle "XKB" binding;
      modsStr = concatStringsSep "" (map (m: modMap.${m}) combo.mods);
    in
    "${modsStr}${if combo.key != null then combo.key else ""}";

  # Electron Accelerator: "Ctrl+Shift+Return"
  # https://www.electronjs.org/docs/latest/api/accelerator
  toElectron = binding:
    let
      modMap = {
        ctrl = "Ctrl";
        shift = "Shift";
        alt = "Alt";
        super = "Super";
        altgr = "AltGr";
        hyper = "Hyper";
      };
    in
    formatCombo "+" modMap (assertSingle "Electron Accelerator" binding);

  # GDK: "<Primary><Shift>Return"
  # ctrl maps to Primary for cross-toolkit compatibility.
  # https://docs.gtk.org/gdk3/flags.ModifierType.html
  toGDK = binding:
    let
      modMap = {
        ctrl = "<Primary>";
        shift = "<Shift>";
        alt = "<Alt>";
        super = "<Super>";
        altgr = "<AltGr>";
        hyper = "<Hyper>";
      };
      combo = assertSingle "GDK" binding;
      modsStr = concatStringsSep "" (map (m: modMap.${m}) combo.mods);
    in
    "${modsStr}${if combo.key != null then combo.key else ""}";

  # Emacs: "C-c" or "C-x C-s" for sequences
  # https://www.gnu.org/software/emacs/manual/html_node/elisp/Other-Char-Bits.html
  toEmacs = binding:
    let
      modMap = {
        ctrl = "C";
        shift = "S";
        alt = "M";
        super = "s";
        altgr = "A";
        hyper = "H";
      };
      fmtCombo = combo:
        let
          modsStr = concatStringsSep "-" (map (m: modMap.${m}) combo.mods);
          keyPart = if combo.key != null then combo.key else "";
          sep = if modsStr != "" && keyPart != "" then "-" else "";
        in
        "${modsStr}${sep}${keyPart}";
    in
    concatStringsSep " " (map fmtCombo (normalize binding));

  # Kitty terminal: "ctrl+shift+r" or "ctrl+x ctrl+s" for sequences
  # https://sw.kovidgoyal.net/kitty/conf/#shortcut
  toKitty = binding:
    let
      modMap = {
        ctrl = "ctrl";
        shift = "shift";
        alt = "alt";
        super = "super";
        altgr = "mod5";
        hyper = "hyper";
      };
      fmtCombo = formatCombo "+" modMap;
    in
    concatStringsSep " " (map fmtCombo (normalize binding));

in
{
  inherit
    modifierType
    keyComboType
    keybindingType
    normalize
    mkBind
    toI3
    toSway
    toHyprland
    toXKB
    toElectron
    toGDK
    toEmacs
    toKitty
    ;
}
