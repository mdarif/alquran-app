"""Trace the approved raster logo into a compact SVG path.

This intentionally treats the approved PNG silhouette as the source of truth.
It extracts gold pixels, traces their boundaries, and simplifies only sub-pixel
noise. The result uses even-odd fill so counters remain transparent.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


Point = tuple[int, int]


def is_mark(pixel: tuple[int, int, int]) -> bool:
    red, green, blue = pixel
    return red > 120 and red - green > 18 and green - blue > 38


def rdp(points: list[Point], epsilon: float) -> list[Point]:
    if len(points) < 3:
        return points
    start, end = points[0], points[-1]
    dx, dy = end[0] - start[0], end[1] - start[1]
    denominator = (dx * dx + dy * dy) ** 0.5
    best_distance = 0.0
    best_index = 0
    for index, point in enumerate(points[1:-1], 1):
        if denominator == 0:
            distance = ((point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2) ** 0.5
        else:
            distance = abs(dy * point[0] - dx * point[1] + end[0] * start[1] - end[1] * start[0]) / denominator
        if distance > best_distance:
            best_distance = distance
            best_index = index
    if best_distance > epsilon:
        left = rdp(points[: best_index + 1], epsilon)
        right = rdp(points[best_index:], epsilon)
        return left[:-1] + right
    return [start, end]


def trace(mask: list[list[bool]]) -> list[list[Point]]:
    height, width = len(mask), len(mask[0])
    edges: dict[Point, list[Point]] = {}

    def add(start: Point, end: Point) -> None:
        edges.setdefault(start, []).append(end)

    for y in range(height):
        for x in range(width):
            if not mask[y][x]:
                continue
            if y == 0 or not mask[y - 1][x]:
                add((x, y), (x + 1, y))
            if x == width - 1 or not mask[y][x + 1]:
                add((x + 1, y), (x + 1, y + 1))
            if y == height - 1 or not mask[y + 1][x]:
                add((x + 1, y + 1), (x, y + 1))
            if x == 0 or not mask[y][x - 1]:
                add((x, y + 1), (x, y))

    loops: list[list[Point]] = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        current = start
        while True:
            candidates = edges[current]
            following = candidates.pop()
            if not candidates:
                del edges[current]
            current = following
            if current == start:
                break
            loop.append(current)
        if len(loop) > 8:
            loops.append(loop)
    return loops


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=512)
    parser.add_argument("--epsilon", type=float, default=1.15)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGB")
    image.thumbnail((args.size, args.size), Image.Resampling.LANCZOS)
    width, height = image.size
    pixels = image.load()
    mask = [[is_mark(pixels[x, y]) for x in range(width)] for y in range(height)]
    loops = trace(mask)

    commands: list[str] = []
    scale_x, scale_y = 1024 / width, 1024 / height
    for loop in loops:
        closed = loop + [loop[0]]
        simplified = rdp(closed, args.epsilon)
        x0, y0 = simplified[0]
        commands.append(f"M{x0 * scale_x:.2f},{y0 * scale_y:.2f}")
        commands.extend(f"L{x * scale_x:.2f},{y * scale_y:.2f}" for x, y in simplified[1:])
        commands.append("Z")
    args.output.write_text(" ".join(commands) + "\n")


if __name__ == "__main__":
    main()
