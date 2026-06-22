{
	description = "centipede";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
		utils.url = "github:numtide/flake-utils";

		zig-overlay = {
			url = "github:silversquirl/zig-flake";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = { nixpkgs, utils, zig-overlay, ... }:
	utils.lib.eachDefaultSystem(system:
		let
			pkgs = import nixpkgs {
				inherit system;
			};

			zig = zig-overlay.packages.${system}.zig_0_16_0;
			zls = zig.zls;
		in {
			devShells.default = pkgs.mkShell {
				buildInputs = [
					zig
					zls
				
					pkgs.libGL
					pkgs.wayland-scanner
					pkgs.wayland
					pkgs.libxkbcommon
				];

				LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
					pkgs.alsa-lib
				];
			};
		}
	);
}
