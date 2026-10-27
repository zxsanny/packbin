from __future__ import annotations

from pathlib import Path

import pytest

import frame_support as fs

# AZ-3294 AC-1: every row of `fixtures/frame/vectors.txt` through the public API.

ROWS = fs.load()


def test_ac1_every_row_of_the_frame_fixture_matches():
    # Act
    problems = fs.mismatches(ROWS)

    # Assert
    assert (len(ROWS), problems) == (157, [])
    assert {row.op for row in ROWS} == {"keys", "seal", "open", "mac", "replay"}


@pytest.mark.parametrize("case", ["E1.seal", "E2.seal", "E3.seal", "E3.seal16", "E4.mac", "E5.mac", "E4.keys"])
def test_ac1_the_worked_examples_are_in_the_file_and_match(case: str):
    # Arrange
    row = next(r for r in ROWS if r.case == case)

    # Act
    problems = fs.mismatches([row])

    # Assert
    assert problems == []


def test_ac1_the_largest_epoch_works_and_the_next_one_is_refused():
    # Arrange
    largest = [r for r in ROWS if r.op == "keys" and r["epoch"] == "16777215"]
    refused = next(r for r in ROWS if r.case == "refuse.seal.epoch1000000")

    # Act
    problems = fs.mismatches(largest)

    # Assert
    assert (len(largest), problems) == (3, [])
    assert (refused["result"], fs.run(refused)["result"]) == ("BadValue", "BadValue")


def _changed_copy(tmp_path: Path, op: str, field: str) -> tuple[Path, str]:
    """A copy of the fixture with the first hex digit of `field` changed on the first `op` row that has it, and its case."""
    lines = fs.FIXTURE.read_text().splitlines()
    for number, line in enumerate(lines):
        if not line.startswith(f"op={op} ") or f" {field}=" not in line:
            continue
        at = line.index(f" {field}=") + len(field) + 2
        lines[number] = line[:at] + ("1" if line[at] == "0" else "0") + line[at + 1 :]
        copy = tmp_path / "vectors.txt"
        copy.write_text("\n".join(lines) + "\n")
        return copy, line.split(" ")[1].removeprefix("case=")
    raise AssertionError(f"no {op} row with {field}")


@pytest.mark.parametrize("op, field", [("seal", "body"), ("open", "plain"), ("mac", "tag"), ("keys", "k_enc"), ("replay", "states")])
def test_ac1_a_copy_with_one_expected_digit_changed_fails_on_that_row_only(tmp_path: Path, op: str, field: str):
    # Arrange
    copy, case = _changed_copy(tmp_path, op, field)

    # Act
    problems = fs.mismatches(fs.load(copy))

    # Assert
    assert len(problems) == 1
    assert problems[0].startswith(f"{case} {field}")
