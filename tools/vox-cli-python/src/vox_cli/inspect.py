"""Inspect command implementation."""

import sys
from pathlib import Path
import click
from voxformat import VoxReader
from voxformat.errors import VoxError


@click.command("inspect", help="Display detailed information about a .vox file.")
@click.argument("file", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.help_option("-h", "--help")
def inspect_command(file: Path):
    """Display detailed information about a .vox file.

    Shows all metadata fields including voice identity, prosody preferences,
    character context, reference audio files, and extension namespaces.

    FILE: Path to the .vox file to inspect

    \b
    Examples:
      vox inspect narrator.vox
      vox inspect examples/minimal/narrator.vox
    """
    try:
        reader = VoxReader()
        vox_file = reader.read(file)
        manifest = vox_file.manifest

        # Print header
        click.echo("━" * 60)
        click.echo(f"VOX File: {file.name}")
        click.echo("━" * 60)
        click.echo()

        # Core metadata
        click.echo("📋 Core Metadata")
        click.echo(f"  VOX Version: {manifest.vox_version}")
        click.echo(f"  ID: {manifest.id}")
        click.echo(f"  Created: {manifest.created}")
        click.echo()

        # Voice identity
        click.echo("🎤 Voice Identity")
        click.echo(f"  Name: {manifest.voice.name}")
        click.echo(f"  Description: {manifest.voice.description}")
        if manifest.voice.language:
            click.echo(f"  Language: {manifest.voice.language}")
        if manifest.voice.gender:
            click.echo(f"  Gender: {manifest.voice.gender}")
        if manifest.voice.age_range:
            click.echo(f"  Age Range: {manifest.voice.age_range[0]}-{manifest.voice.age_range[1]}")
        if manifest.voice.tags:
            click.echo(f"  Tags: {', '.join(manifest.voice.tags)}")
        click.echo()

        # Prosody
        if manifest.prosody:
            click.echo("🎵 Prosody")
            prosody = manifest.prosody
            if prosody.pitch_base:
                click.echo(f"  Pitch Base: {prosody.pitch_base}")
            if prosody.pitch_range:
                click.echo(f"  Pitch Range: {prosody.pitch_range}")
            if prosody.rate:
                click.echo(f"  Rate: {prosody.rate}")
            if prosody.energy:
                click.echo(f"  Energy: {prosody.energy}")
            if prosody.emotion_default:
                click.echo(f"  Default Emotion: {prosody.emotion_default}")
            click.echo()

        # Reference audio
        if manifest.reference_audio:
            click.echo(f"🎙️  Reference Audio ({len(manifest.reference_audio)} file(s))")
            for idx, audio in enumerate(manifest.reference_audio, 1):
                click.echo(f"  [{idx}] {audio.file}")
                if audio.transcript:
                    transcript_preview = audio.transcript[:60] + "..." if len(audio.transcript) > 60 else audio.transcript
                    click.echo(f"      Transcript: {transcript_preview}")
                if audio.language:
                    click.echo(f"      Language: {audio.language}")
                if audio.duration_seconds is not None:
                    click.echo(f"      Duration: {audio.duration_seconds}s")
            click.echo()

        # Character context
        if manifest.character:
            click.echo("👤 Character Context")
            char = manifest.character
            if char.role:
                click.echo(f"  Role: {char.role}")
            if char.emotional_range:
                click.echo(f"  Emotional Range: {', '.join(char.emotional_range)}")
            if char.relationships:
                click.echo("  Relationships:")
                for name, relationship in char.relationships.items():
                    click.echo(f"    - {name}: {relationship}")
            if char.source:
                click.echo("  Source:")
                if char.source.work:
                    click.echo(f"    Work: {char.source.work}")
                if char.source.format:
                    click.echo(f"    Format: {char.source.format}")
                if char.source.file:
                    click.echo(f"    File: {char.source.file}")
            click.echo()

        # Provenance
        if manifest.provenance:
            click.echo("📜 Provenance")
            prov = manifest.provenance
            if prov.method:
                click.echo(f"  Method: {prov.method}")
            if prov.engine:
                click.echo(f"  Engine: {prov.engine}")
            if prov.consent is not None:
                click.echo(f"  Consent: {prov.consent}")
            if prov.license:
                click.echo(f"  License: {prov.license}")
            if prov.notes:
                click.echo(f"  Notes: {prov.notes}")
            click.echo()

        # Extensions
        if manifest.extensions:
            click.echo(f"🔌 Extensions ({len(manifest.extensions)} namespace(s))")
            for namespace in sorted(manifest.extensions.keys()):
                click.echo(f"  - {namespace}")
            click.echo()

    except VoxError as e:
        click.echo(f"❌ Error reading .vox file: {e}", err=True)
        sys.exit(1)
    except Exception as e:
        click.echo(f"❌ Unexpected error: {e}", err=True)
        sys.exit(1)
