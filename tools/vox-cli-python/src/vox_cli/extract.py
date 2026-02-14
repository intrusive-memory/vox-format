"""Extract command implementation."""

import sys
import json
from pathlib import Path
import zipfile
import click
from voxformat.errors import VoxError


@click.command("extract", help="Extract the contents of a .vox archive.")
@click.argument("file", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option(
    "--output-dir",
    type=click.Path(file_okay=False, path_type=Path),
    default=None,
    help="Output directory for extracted files (defaults to FILE_extracted/).",
)
@click.help_option("-h", "--help")
def extract_command(file: Path, output_dir: Path | None):
    """Extract the contents of a .vox archive to a directory.

    Unzips all files (manifest.json, reference audio, embeddings) and displays
    the pretty-printed manifest.

    FILE: Path to the .vox file to extract

    \b
    Examples:
      vox extract narrator.vox
      vox extract examples/character/protagonist.vox --output-dir extracted/
    """
    try:
        # Determine output directory
        if output_dir is None:
            output_dir = Path(f"{file.stem}_extracted")

        # Create output directory
        output_dir.mkdir(parents=True, exist_ok=True)

        # Print header
        click.echo(f"📦 Extracting: {file.name}")
        click.echo(f"Destination: {output_dir}/")
        click.echo()

        # Extract ZIP archive
        file_count = 0
        with zipfile.ZipFile(file, "r") as archive:
            # List all files
            for member in archive.namelist():
                archive.extract(member, output_dir)
                click.echo(f"  ✓ {member}")
                file_count += 1

        click.echo()
        click.echo(f"Extracted {file_count} file(s)")
        click.echo()

        # Read and pretty-print manifest
        manifest_path = output_dir / "manifest.json"
        if manifest_path.exists():
            click.echo("━" * 60)
            click.echo("Manifest Contents")
            click.echo("━" * 60)
            click.echo()

            with open(manifest_path, "r") as f:
                manifest_data = json.load(f)

            # Pretty-print JSON
            pretty_json = json.dumps(manifest_data, indent=2, sort_keys=True)
            click.echo(pretty_json)
        else:
            click.echo("⚠️  Warning: manifest.json not found in archive", err=True)

    except zipfile.BadZipFile:
        click.echo(f"❌ Error: {file} is not a valid ZIP archive", err=True)
        sys.exit(1)

    except VoxError as e:
        click.echo(f"❌ Error extracting .vox file: {e}", err=True)
        sys.exit(1)

    except Exception as e:
        click.echo(f"❌ Unexpected error: {e}", err=True)
        sys.exit(1)
