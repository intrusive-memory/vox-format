#!/usr/bin/env python3
"""
VOX Library Search Tool

Searches the library/index.json file for voices matching query terms.
Supports case-insensitive partial matching on name, description, and tags.

Usage:
    ./search.py <query>
    python3 search.py narrator
    python3 search.py young
"""

import json
import sys
from pathlib import Path


def search_library(query: str, index_path: Path) -> list:
    """
    Search the voice library index for matching entries.

    Args:
        query: Search query (case-insensitive)
        index_path: Path to index.json file

    Returns:
        List of matching voice entries
    """
    with open(index_path, 'r', encoding='utf-8') as f:
        voices = json.load(f)

    query_lower = query.lower()
    matches = []

    for voice in voices:
        # Search in name
        if query_lower in voice['name'].lower():
            matches.append(voice)
            continue

        # Search in description
        if query_lower in voice['description'].lower():
            matches.append(voice)
            continue

        # Search in tags
        if any(query_lower in tag.lower() for tag in voice['tags']):
            matches.append(voice)
            continue

    return matches


def format_voice_entry(voice: dict) -> str:
    """Format a voice entry for display."""
    lines = [
        f"\n{voice['name']}",
        f"  File: {voice['file']}",
        f"  Description: {voice['description']}",
        f"  Tags: {', '.join(voice['tags'])}",
        f"  Language: {voice['language']}"
    ]

    if 'age_range' in voice:
        lines.append(f"  Age Range: {voice['age_range'][0]}-{voice['age_range'][1]}")

    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: search.py <query>", file=sys.stderr)
        print("\nExample:", file=sys.stderr)
        print("  ./search.py narrator", file=sys.stderr)
        print("  ./search.py young", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    script_dir = Path(__file__).parent
    index_path = script_dir / 'index.json'

    if not index_path.exists():
        print(f"Error: index.json not found at {index_path}", file=sys.stderr)
        sys.exit(1)

    matches = search_library(query, index_path)

    if not matches:
        print(f"No voices found matching '{query}'")
        sys.exit(0)

    print(f"Found {len(matches)} voice(s) matching '{query}':")
    for voice in matches:
        print(format_voice_entry(voice))


if __name__ == '__main__':
    main()
