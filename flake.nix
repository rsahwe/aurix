{
  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aurix-toolchain-src = {
      url = "github:piraterna/aurix-toolchain";
      flake = false;
    };
    aurix-gcc-src = {
      url = "file+https://ftp.gnu.org/gnu/gcc/gcc-15.2.0/gcc-15.2.0.tar.xz";
      flake = false;
    };
    aurix-binutils-src = {
      url = "file+https://ftp.gnu.org/gnu/binutils/binutils-2.46.0.tar.xz";
      flake = false;
    };
    aurix-mlibc-src = {
      url = "github:piraterna/aurix-mlibc";
      flake = false;
    };
    doom-src = {
      url = "github:piraterna/doomgeneric";
      flake = false;
    };
    toybox-src = {
      url = "github:landley/toybox?submodules=1";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    perSystem = { self', pkgs, lib, ... }: {
      packages.freestnd-c-hdrs = pkgs.stdenv.mkDerivation {
        pname = "freestnd-c-hdrs";
        version = "unstable-2026-05-03";

        src = pkgs.fetchFromGitHub {
          owner = "osdev0";
          repo = "freestnd-c-hdrs";
          rev = "d33711241b46ecb8f2ad33927fcefdcb3ac0162e";
          hash = "sha256-gi+ZNmZvzYicRc/NZONFC2P984EXcyp7nUtT6vXaJ68=";
        };

        buildPhase = ''
          sed -i "s|/usr/local|$out/|" GNUmakefile
        '';

        installPhase = ''
          make install
        '';
      };

      packages.freestnd-cxx-hdrs = pkgs.stdenv.mkDerivation {
        pname = "freestnd-cxx-hdrs";
        version = "unstable-2026-05-03";

        src = pkgs.fetchFromGitHub {
          owner = "osdev0";
          repo = "freestnd-cxx-hdrs";
          rev = "a6b351e0ab3e74e5789b01fa1447e4cd62373da7";
          hash = "sha256-sDXHMP/xTuL+DtaJgyxl322IWIXXcqRUbtJRMvYUmZY=";
        };

        buildPhase = ''
          sed -i "s|/usr/local|$out/|" GNUmakefile
        '';

        installPhase = ''
          make install
        '';
      };

      packages.frigg = pkgs.stdenv.mkDerivation {
        pname = "frigg";
        version = "unstable-2026-05-04";

        src = pkgs.fetchFromGitHub {
          owner = "managarm";
          repo = "frigg";
          rev = "58fb2ab734934cf4b245f833797ab5eeefeb60c0";
          hash = "sha256-1qfn4GpMosZzIE3zb9n2HED0jqrUJXmzyDSYa6bOtz8=";
        };

        nativeBuildInputs = with pkgs; [
          meson
          ninja
        ];

        mesonFlags = lib.mapAttrsToList lib.mesonOption {
          build_tests = "disabled";
        };
      };

      packages.libsmarter = pkgs.stdenv.mkDerivation {
        pname = "libsmarter";
        version = "unstable-2026-05-04";

        src = pkgs.fetchFromGitHub {
          owner = "managarm";
          repo = "libsmarter";
          rev = "338cce63b22c85557c9274ad8ecfc8423a14024d";
          hash = "sha256-0x8S9KEMdCu0iaQ+k7lOSz2H/qaoLzwCV6Tw3bZ+KGQ=";
        };

        nativeBuildInputs = with pkgs; [
          meson
          ninja
        ];
      };

      packages.bragi = pkgs.stdenv.mkDerivation {
        pname = "bragi";
        version = "unstable-2026-05-04";

        src = pkgs.fetchFromGitHub {
          owner = "managarm";
          repo = "bragi";
          rev = "523b86efac124b0d749eed201df0c7ea9f87ee17";
          hash = "sha256-uCSijxsgachNDJ6i9LhCp2nz0fS2nd4zDqD3EyNcdng=";
        };

        nativeBuildInputs = with pkgs; [
          meson
          ninja
        ];
      };

      packages.aurix-toolchain = pkgs.stdenv.mkDerivation {
        pname = "aurix-toolchain";
        version = "unstable-2026-05-03";

        dontConfigure = true;

        src = inputs.aurix-toolchain-src.outPath;

        nativeBuildInputs = with pkgs; [
          binutils
          flex
          gawk
          gettext
          gmp
          gnumake
          gnused
          gnutar
          gzip
          libmpc
          meson
          mpfr
          moreutils
          ninja
          perl
          pkg-config
          python3
          xz
          zstd
        ] ++ [
          self'.packages.bragi
          self'.packages.freestnd-c-hdrs
          self'.packages.freestnd-cxx-hdrs
          self'.packages.frigg
          self'.packages.libsmarter
        ];

        buildPhase = ''
          cp ${inputs.aurix-gcc-src.outPath} gcc-15.2.0.tar.xz
          cp ${inputs.aurix-binutils-src.outPath} binutils-2.46.0.tar.xz
          cp -r ${inputs.aurix-mlibc-src.outPath} mlibc
          tar -xf gcc-15.2.0.tar.xz
          tar -xf binutils-2.46.0.tar.xz

          printf "" > gcc-15.2.0/contrib/download_prerequisites

          chmod +w mlibc

          sed -i "s|--with-sysroot=\([^ ]*\)|--with-sysroot=$out/sysroot --with-build-sysroot=\1|" build.sh

          ARCH=x86_64 CXXFLAGS="-Wno-error=format-security" sh build.sh

          mkdir -p $out

          cp -r toolchain/usr/* $out/
          cp -r sysroot/ $out/sysroot/

          OLD_PATH=$PATH
          PATH=$OLD_PATH:$out/bin

          pushd mlibc >/dev/null

          CFLAGS="-O2 -ffunction-sections -fdata-sections" CXXFLAGS="-O2 -ffunction-sections -fdata-sections" LDFLAGS="-Wl,--gc-sections" meson setup --cross-file ../aurix-cross_x86_64.txt --prefix=/usr -Ddefault_library=both -Dno_headers=true build

          ninja -C build

          DESTDIR=$out/sysroot/ ninja -C build install

          popd >/dev/null

          PATH=$OLD_PATH
        '';

        dontInstall = true;
      };

      packages.aurix = pkgs.stdenv.mkDerivation {
        pname = "aurix";
        version = "unstable-2026-05-03";

        src = inputs.self;

        env.TOOLCHAIN_DIR = "${lib.getBin self'.packages.aurix-toolchain}/bin";

        nativeBuildInputs = with pkgs; [
          clang-tools
          cpio
          ffmpeg
          findutils
          gawk
          git
          gnumake
          gnutar
          gptfdisk
          jq
          llvm
          llvmPackages.bintools
          llvmPackages.clang-unwrapped
          mtools
          nasm
          python3
          qemu
          xorriso
          xxd
        ] ++ [
          self'.packages.aurix-toolchain
        ];

        patchPhase = ''
          mkdir -p src/doom/upstream
          cp -r ${inputs.doom-src.outPath}/* src/doom/upstream/
          chmod +w src/doom/upstream/*
          touch src/doom/upstream/.git

          mkdir -p src/toybox/upstream
          cp -r ${inputs.toybox-src.outPath}/* src/toybox/upstream/
          chmod +w src/toybox/upstream/*
          touch src/toybox/upstream/.git

          patchShebangs .
        '';

        buildPhase = ''
          make defconfig

          INITRD_DIR=$(realpath initrd) BUILD_DIR=$(realpath build) ARCH=x86_64 make -C src install

          mkdir -p initrd/usr/lib
          cp ${lib.getLib self'.packages.aurix-toolchain}/sysroot/usr/lib/* initrd/usr/lib/

          mkdir -p sysroot/System

          # cp $${./doom.wad} initrd/root/doom.wad

          pushd initrd >/dev/null

          cpio --format=newc -o < <(find .) > ../sysroot/System/initrd.cpio

          popd >/dev/null

          make livecd

          make nvram
        '';

        installPhase = ''
          mkdir -p $out/bin

          cp release/aurix-*-livecd_x86_64-generic-pc.iso $out/image.iso
          cp ovmf/ovmf_code-x86_64.fd $out/ovmf_code.fd
          cp ovmf/ovmf_vars-x86_64.fd $out/ovmf_vars.fd
          cp build/axkrnl $out/kernel_symbols
          cp -r kernel/ $out/kernel_source

          cat > $out/bin/run.sh <<EOF
          #!${lib.getExe pkgs.bash}

          if [[ ! -v 1 ]]; then
            echo "Missing uefi_nvram.json"
            exit 1
          fi

          ${lib.getBin pkgs.qemu}/bin/qemu-system-x86_64 \
            -m 2G \
            -smp 4 \
            -cpu host \
            -M q35 \
            -rtc base=localtime \
            -accel kvm \
            -drive if=pflash,format=raw,unit=0,file=$out/ovmf_code.fd,readonly=on \
            -drive if=pflash,format=raw,unit=1,file=$out/ovmf_vars.fd,readonly=on \
            -device uefi-vars-x64,jsonfile=\$1 \
            -cdrom $out/image.iso
          EOF

          cat > $out/bin/run_serial.sh <<EOF
          #!${lib.getExe pkgs.bash}

          if [[ ! -v 1 ]]; then
            echo "Missing uefi_nvram.json"
            exit 1
          fi

          ${lib.getBin pkgs.qemu}/bin/qemu-system-x86_64 \
            -m 2G \
            -smp 4 \
            -cpu host \
            -M q35 \
            -rtc base=localtime \
            -accel kvm \
            -drive if=pflash,format=raw,unit=0,file=$out/ovmf_code.fd,readonly=on \
            -drive if=pflash,format=raw,unit=1,file=$out/ovmf_vars.fd,readonly=on \
            -device uefi-vars-x64,jsonfile=\$1 \
            -cdrom $out/image.iso \
            -nographic
          EOF

          cat > $out/bin/debug.sh <<EOF
          #!${lib.getExe pkgs.bash}

          if [[ ! -v 1 ]]; then
            echo "Missing uefi_nvram.json"
            exit 1
          fi

          ${lib.getBin pkgs.qemu}/bin/qemu-system-x86_64 \
            -m 2G \
            -smp 4 \
            -cpu host \
            -M q35 \
            -rtc base=localtime \
            -accel kvm \
            -drive if=pflash,format=raw,unit=0,file=$out/ovmf_code.fd,readonly=on \
            -drive if=pflash,format=raw,unit=1,file=$out/ovmf_vars.fd,readonly=on \
            -device uefi-vars-x64,jsonfile=\$1 \
            -cdrom $out/image.iso \
            -s -S &

          gdb $out/kernel_symbols -ex "dir $out/kernel_source" -ex "target remote localhost:1234" -ex "layout src"
          EOF

          chmod +x $out/bin/run.sh
          chmod +x $out/bin/run_serial.sh
          chmod +x $out/bin/debug.sh
        '';
      };
    };
  };
}
