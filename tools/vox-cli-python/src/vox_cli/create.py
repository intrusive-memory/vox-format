"""Create command implementation."""

import sys
from pathlib import Path
import uuid
from datetime import datetime, timezone
import click
from voxformat import VoxWriter, VoxFile, VoxManifest, Voice, VoxValidator
from voxformat.errors import VoxError


@click.command("create", help="Create a new .vox file with specified metadata.")
@click.option(
    "--name",
    required=True,
    help="Display name for the voice (required).",
)
@click.option(
    "--description",
    required=True,
    help="Natural language description of the voice (required, minimum 10 characters).",
)
@click.option(
    "--output",
    required=True,
    type=click.Path(dir_okay=False, path_type=Path),
    help="Output file path for the .vox file (required).",
)
@click.option(
    "--language",
    help="Primary language in BCP 47 format (e.g., en-US, en-GB, fr-FR).",
)
@click.option(
    "--gender",
    type=click.Choice(["male", "female", "nonbinary", "neutral"], case_sensitive=False),
    help="Gender presentation of the voice.",
)
@click.help_option("-h", "--help")
def create_command(
    name: str,
    description: str,
    output: Path,
    language: str | None,
    gender: str | None,
):
    """Create a new .vox file with specified metadata.

    Required fields (UUID, timestamp) are auto-generated. Supports optional
    voice attributes like language and gender.

    \b
    Examples:
      vox create --name "Narrator" --description "A warm narrator voice" --output narrator.vox

      vox create --name "Doc Narrator" \\
        --description "Documentary narrator with British accent" \\
        --language "en-GB" --gender "male" --output documentary.vox

      vox create --name "Character" \\
        --description "Young protagonist, energetic and optimistic" \\
        --language "en-US" --gender "neutral" --output protagonist.vox
    """
    try:
        # Generate UUID and timestamp
        voice_id = str(uuid.uuid4())
        created = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        # Create voice object
        voice = Voice(
            name=name,
            description=description,
            language=language,
            gender=gender.lower() if gender else None,
        )

        # Create manifest
        manifest = VoxManifest(
            vox_version="0.1.0",
            id=voice_id,
            created=created,
            voice=voice,
        )

        # Create VOX file
        vox_file = VoxFile(manifest=manifest)

        # Write to disk
        writer = VoxWriter()
        writer.write(vox_file, output)

        # Success message
        click.echo(f"✅ Created: {output}")
        click.echo()
        click.echo(f"Voice: {name}")
        click.echo(f"ID: {voice_id}")
        click.echo(f"Created: {created}")
        click.echo()
        click.echo(f"Output: {output}")
        click.echo()

        # Validate created file
        click.echo("Validating created file...")
        validator = VoxValidator()
        validator.validate(manifest)
        click.echo("✅ Validation passed")

    except VoxError as e:
        click.echo(f"❌ Error creating .vox file: {e}", err=True)
        sys.exit(1)

    except Exception as e:
        click.echo(f"❌ Unexpected error: {e}", err=True)
        sys.exit(1)
