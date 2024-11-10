# Z-Touch

Z-Touch is a cross-platform project organization tool that enables efficient tagging and searching of local projects and links.

## Features
- Tag and organize projects from the local filesystem or via a web link
- Advanced search and filtering capabilities
- Cross-platform support (Windows, Mac, and Linux)
- Lightweight and fast

## Tech Stack
Z-Touch is a GUI application built with [Zig](https://github.com/ziglang/zig) and [WebView](https://github.com/thechampagne/webview-zig).
The frontend is built with [Solid](https://www.solidjs.com/) and [Tailwind](https://tailwindcss.com/).

## Installation
### Pre-built binaries
Z-Touch can be downloaded from the [releases](https://github.com/max-legrand/z-touch/releases) page.

### Build from source
To build Z-Touch from source, you will need to install the [Zig](https://ziglang.org/) programming language and the [Bun](https://bun.sh/) package manager.

Once you have installed Zig and Bun, you can clone the repository and run the following commands:

```bash
git clone https://github.com/max-legrand/z-touch.git
```

You will then need to update the git submodules and pull their contents:

```bash
cd z-touch
git submodule update --init --recursive
```

Now you can build the application by running the following command:

```bash
zig build
```

Optionally, you can build in release mode with one of three options:

```bash
zig build --release=fast   # Optimized for speed
zig build --release=safe   # Optimized for memory safety
zig build --release=small  # Optimized for size
```

The builds in the [releases](https://github.com/max-legrand/z-touch/releases) page are built with the `release-fast` option.

To build the project as a bundled application, you can run the following command:

Windows:
```bash
zig build --release=fast -Dbundle=true
```

Mac:
```bash
zig build --release=fast
zig build bundle-mac
```

## Roadmap
This project in it's current form is a Minimum Viable Product (MVP). There are still several features that I would like to add in the future:
- Add the tags to the SQLite database
- Clean up the UI, I'm not a designer...
- Since the database is a SQLite database, I would like to add the ability to automatically backup the database either using Git or a cloud sync service.
- Better support for Linux

## Contributing
If you would like to contribute to Z-Touch, please feel free to submit a pull request or open an issue on the [GitHub repository](https://github.com/max-legrand/z-touch).

## Acknowledgements
Icons courtesy of
- https://www.flaticon.com


