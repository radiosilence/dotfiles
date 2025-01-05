#!/usr/bin/env python3

import shutil
import subprocess
import sys
from argparse import ArgumentParser, RawDescriptionHelpFormatter
from dataclasses import dataclass
from functools import partial
from pathlib import Path
from textwrap import dedent
from typing import List


@dataclass
class DirInfo:
    path: Path
    size: int


print_err = partial(print, file=sys.stderr)


def get_terminal_width():
    """Get terminal width, fallback to 80 if not available"""
    return shutil.get_terminal_size().columns


def format_bytes(size_kb: int):
    """Format bytes with automatic unit selection"""
    return shutil.get_terminal_size().columns


def scan_directories(min_size: int) -> list[DirInfo]:
    """Scan directories and return those below min_size"""
    cmd = ["find", ".", "-type", "d", "-exec", "du", "-sk", "{}", "+"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)

    dirs: List[DirInfo] = []
    for line in result.stdout.splitlines():
        size, path = line.split("\t")
        path = Path(path)
        if (
            int(size) < min_size
            and path != Path(".")
            and not any(
                p.startswith(".") and ("git" in p or "stfolder" in p)
                for p in path.parts
            )
        ):
            dirs.append(DirInfo(path=path, size=int(size)))

    return sorted(dirs, key=lambda x: x.size)  # Sort by size ascending


def main():
    parser = ArgumentParser(
        description=dedent(
            """
            Find and delete directories below a specified size.
            Safely ignores git and Syncthing directories.
        """
        ),
        formatter_class=RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-m",
        "--min-size",
        type=int,
        default=3096,
        help="minimum size in KB (default: %(default)s)",
    )
    parser.add_argument(
        "-y", "--yes", action="store_true", help="skip confirmation prompt"
    )
    args = parser.parse_args()

    try:
        to_delete = scan_directories(args.min_size)
        if not to_delete:
            print_err(f"No directories below {args.min_size:,} KB")
            return 1

        # Calculate column widths for pretty printing
        # max_path_len = max(len(str(d.path)) for d in to_delete)
        width = get_terminal_width()

        # Pretty header
        print(f"\n{'Small Directories':^{width}}")
        print(f"{'-' * width}")
        print(f"Found {len(to_delete)} directories below {args.min_size:,} KB\n")

        # Directory listing with size-based coloring
        for dir_info in to_delete:
            size_str = f"{dir_info.size:,} KB"
            print(f"{size_str:>10} │ {dir_info.path}")

        if args.yes or input("\nDelete these directories? [y/N] ").lower() == "y":
            print("\nDeleting directories...")
            for dir_info in to_delete:
                try:
                    shutil.rmtree(dir_info.path)
                    print(f"✓ {dir_info.path}")
                except Exception as e:
                    print_err(f"✗ Failed to delete {dir_info.path}: {e}")
            print("\nOperation completed.")
        else:
            print("\nOperation canceled.")

    except KeyboardInterrupt:
        print_err("\nOperation interrupted by user.")
        return 130
    except subprocess.CalledProcessError as e:
        print_err(f"Error running find command: {e}")
        return 1
    except Exception as e:
        print_err(f"Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
