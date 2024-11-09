with import <nixpkgs> {};
let

  allDeps = with pkgs; [];

  linuxDeps = with pkgs; [
    webkitgtk
    gtk3
    libappindicator-gtk3
    sqlite
  ];

  deps = if pkgs.stdenv.isLinux then linuxDeps ++ allDeps else allDeps;

  shellHook = if pkgs.stdenv.isLinux then ''
    export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" linuxDeps}:$PKG_CONFIG_PATH"
    export LIBRARY_PATH="${pkgs.lib.makeLibraryPath linuxDeps}:$LIBRARY_PATH"
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath linuxDeps}:$LD_LIBRARY_PATH"
    export C_INCLUDE_PATH="${pkgs.lib.makeSearchPathOutput "dev" "include" linuxDeps}:$C_INCLUDE_PATH"
    export LIBAPPINDICATOR_INCLUDE_PATH="${pkgs.libappindicator-gtk3}/include/libappindicator3-0.1"
    export LIBAPPINDICATOR_LIB_PATH="${pkgs.libappindicator-gtk3}/lib"
  '' else if pkgs.stdenv.isDarwin then ''
    export PATH="/usr/bin:/usr/local/bin:$PATH"
    export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
    export MACOSX_DEPLOYMENT_TARGET=$(xcrun --sdk macosx --show-sdk-platform-version)
    export CPPFLAGS="-I$SDKROOT/usr/include"
    export CFLAGS="-I$SDKROOT/usr/include"
    export LDFLAGS="-L$SDKROOT/usr/lib"
    export CC="clang"
    export CXX="clang++"
    unset NIX_CFLAGS_COMPILE
    unset NIX_LDFLAGS
  '' else '''';

in pkgs.mkShell {
  buildInputs = deps ++ [ pkgs.pkg-config ];
  inherit shellHook;
}
