"""Main CLI entry point using Click."""

import click
from . import __version__
from .inspect import inspect_command
from .validate import validate_command
from .create import create_command
from .extract import extract_command


@click.group()
@click.version_option(version=__version__, prog_name="vox")
@click.help_option("-h", "--help")
def cli():
    """A command-line tool for working with .vox voice identity files.

    VOX is an open, vendor-neutral file format for voice identities used in
    text-to-speech synthesis. This tool provides commands to inspect, validate,
    create, and extract .vox archives.
    """
    pass


# Register subcommands
cli.add_command(inspect_command)
cli.add_command(validate_command)
cli.add_command(create_command)
cli.add_command(extract_command)


if __name__ == "__main__":
    cli()
