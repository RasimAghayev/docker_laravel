import { defineConfig } from "vite";
import laravel from "laravel-vite-plugin";

export default defineConfig({
    plugins: [
        laravel({
            input: ["resources/css/app.css", "resources/js/app.js"],
            refresh: true,
        }),
    ],
    server: {
        host: true,
        port: 5173,
        open: false,
        hmr: {
            clientPort: 5173,
            host: "localhost",
        },
        watch: {
            usePolling: true,
        },
        // https: false,
        // host: true,
        // host: "0.0.0.0",
        // host: "localhost",
        // strictPort: true,
        // port: 5173,
        // hmr: {
        // host: "0.0.0.0",
        // host: "localhost",
        // protocol: "ws",
        // },
        // watch: {
        //     usePolling: true,
        // },
    },
});
