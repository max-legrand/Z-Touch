import { defineConfig } from "@rsbuild/core";
import { pluginBabel } from "@rsbuild/plugin-babel";
import { pluginSolid } from "@rsbuild/plugin-solid";

export default defineConfig({
	plugins: [
		pluginBabel({
			include: /\.(?:jsx|tsx)$/,
		}),
		pluginSolid(),
	],

	server: {
		port: 11110,
		open: false,
	},
	dev: {
		liveReload: true,
		hmr: true,
	},
	html: {
		template: "index.html",
	},
});
