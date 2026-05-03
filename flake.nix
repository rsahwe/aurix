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
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } rec {
    systems = [ "x86_64-linux" ];
    perSystem = { self', pkgs, lib, ... }: {
      packages.aurix-toolchain = pkgs.stdenv.mkDerivation {
        name = "aurix-toolchain";
        version = "unstable-2026-05-03";

        dontConfigure = true;

        src = inputs.aurix-toolchain-src.outPath;
        
        buildInputs = with pkgs; [
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
          python3
          xz
          zstd
        ];

        buildPhase = ''
          cp ${inputs.aurix-gcc-src.outPath} gcc-15.2.0.tar.xz
          cp ${inputs.aurix-binutils-src.outPath} binutils-2.46.0.tar.xz
          cp -r ${inputs.aurix-mlibc-src.outPath} mlibc
          tar -xf gcc-15.2.0.tar.xz
          tar -xf binutils-2.46.0.tar.xz

          printf "" > gcc-15.2.0/contrib/download_prerequisites

          chmod +w mlibc

          sed -iE "s|--with-sysroot=\([^ ]*\)|--with-sysroot=$out/sysroot --with-build-sysroot=\1|" build.sh

          ARCH=x86_64 CXXFLAGS="-Wno-error=format-security" sh build.sh
        '';

        installPhase = ''
          mkdir -p $out

          cp -r toolchain/usr/* $out/
          cp -r sysroot/ $out/sysroot/
        '';
      };

      packages.aurix = pkgs.stdenv.mkDerivation {
        name = "aurix";
        version = "unstable-2026-05-03";

        src = ./.;

        buildInputs = with pkgs; [
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

        # dontStrip = true;
        # keepDebugSymbols = true;

        patchPhase = ''
          patchShebangs utils
        '';

        buildPhase = ''
          make defconfig

          mkdir -p sysroot/System

          cpio --format=newc -o < <(find initrd/) > sysroot/System/initrd.cpio

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
            -device uefi-vars-x64,jsonfile=$1 \
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
            -device uefi-vars-x64,jsonfile=$1 \
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
            -device uefi-vars-x64,jsonfile=$1 \
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
