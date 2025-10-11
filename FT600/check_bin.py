import typer

app = typer.Typer()

@app.command()
def check_pattern(filename: str, block_size: int = 32768, async_size: int = 32):
    """
    Check that a binary file follows the pattern:
    - First block_size bytes have the same value
    - Next block_size bytes are one greater, etc.
    """
    try:
        with open(filename, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        typer.echo(f"File '{filename}' not found.")
        raise typer.Exit(code=1)

    total_blocks = (len(data) + block_size - 1) // block_size

    starting_data = data[0]
    
    for block_index in range(total_blocks):
        start = block_index * block_size
        end = min(start + block_size, len(data))
        block = data[start:end]

        expected_value = (block_index % async_size + starting_data) % 256  # wrap around at 255 -> 0
        if all(byte == expected_value for byte in block):
            continue
        else:
            # Find first mismatch
            for i, byte in enumerate(block):
                if byte != expected_value:
                    typer.echo(f"Mismatch at byte 0x{start + i:x}: expected 0x{expected_value:x}, got 0x{byte:x}")
                    raise typer.Exit(code=1)

    typer.echo("File matches the expected pattern!")

if __name__ == "__main__":
    app()
