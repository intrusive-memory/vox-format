"""Validate command implementation."""

import sys
from pathlib import Path
import click
from voxformat import VoxReader, VoxValidator
from voxformat.errors import VoxError, MultipleValidationErrors


@click.command("validate", help="Validate a .vox file against the VOX format specification.")
@click.argument("file", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option(
    "--strict",
    is_flag=True,
    help="Use strict validation mode (rejects unknown fields).",
)
@click.help_option("-h", "--help")
def validate_command(file: Path, strict: bool):
    """Validate a .vox file against the VOX format specification.

    By default, uses permissive validation (forward-compatible, ignores unknown
    fields). Use --strict for development/testing to enforce exact schema compliance.

    FILE: Path to the .vox file to validate

    \b
    Examples:
      vox validate narrator.vox
      vox validate --strict examples/character/protagonist.vox
    """
    try:
        reader = VoxReader()
        vox_file = reader.read(file)

        validator = VoxValidator()
        validator.validate(vox_file.manifest, strict=strict)

        # Validation passed
        click.echo(f"✅ PASS: {file.name}")
        click.echo()
        mode = "strict" if strict else "permissive (default)"
        click.echo(f"Validation mode: {mode}")
        click.echo(f"Voice: {vox_file.manifest.voice.name}")
        click.echo(f"Version: {vox_file.manifest.vox_version}")
        sys.exit(0)

    except MultipleValidationErrors as e:
        click.echo(f"❌ FAIL: {file.name}", err=True)
        click.echo()
        click.echo(f"Found {len(e.errors)} validation error(s):", err=True)
        for error in e.errors:
            click.echo(f"  - {error.field}: {error.message}", err=True)
        sys.exit(1)

    except VoxError as e:
        click.echo(f"❌ Error reading .vox file: {e}", err=True)
        sys.exit(1)

    except Exception as e:
        click.echo(f"❌ Unexpected error: {e}", err=True)
        sys.exit(1)
