#!/usr/bin/python3
import operator, os, re, sys
from dataclasses import dataclass, field
from bisect import bisect_left


def human_readable_bytes(num):
    for unit in ["B", "K", "M", "G"]:
        if num < 1024:
            return f"{num:6.1f}{unit}"
        num /= 1024
    return f"{num:6.1f}T"


class FragmentationTracker:
    def __init__(
        self,
        processed_bytes=0,
        sequential_blocks=0,
        fragmented_blocks=0,
        latency_ms=0.0,
    ):
        self.processed_bytes = processed_bytes
        self.sequential_blocks = sequential_blocks
        self.fragmented_blocks = fragmented_blocks
        self.latency_ms = latency_ms

        self.next_offset = None

    def step(self, offset, length):
        self.processed_bytes += length

        if self.next_offset is None:
            pass
        elif offset == self.next_offset:
            self.sequential_blocks += 1
        else:
            self.fragmented_blocks += 1
            self.latency_ms += FragmentationTracker._latency_ms(
                abs(offset - self.next_offset)
            )

        self.next_offset = offset + length

    def _latency_ms(gap_bytes):
        gap_bytes /= vdev_disks

        if gap_bytes < DISK_TRACK_BYTES / 2:
            return DISK_FULL_ROTATION_MS * (gap_bytes / DISK_TRACK_BYTES)
        else:
            return (
                DISK_FULL_STROKE_MS * (gap_bytes / DISK_BYTES) ** 0.5
                + DISK_FULL_ROTATION_MS / 2
            )

    def score(self, label):
        return FragmentationScore(
            self._score(), self._ratio(), self.processed_bytes, label
        )

    def _score(self):
        read_time_ms = (
            FragmentationTracker._latency_ms(DISK_BYTES / 2)
            + self.processed_bytes / vdev_disks / DISK_READ_BYTES_S * 1000
        )
        return self.latency_ms / read_time_ms

    def _ratio(self):
        if total_blocks := self.sequential_blocks + self.fragmented_blocks:
            return self.fragmented_blocks / total_blocks
        else:
            return 0.0

    def __add__(self, other):
        return FragmentationTracker(
            self.processed_bytes + other.processed_bytes,
            self.sequential_blocks + other.sequential_blocks,
            self.fragmented_blocks + other.fragmented_blocks,
            self.latency_ms + other.latency_ms,
        )

    def __radd__(self, other):
        if other == 0:
            return self
        return self.__add__(other)


def range_add(ranges, start, end):
    """
    Add [start, end) to a sorted list of non-overlapping ranges.
    >>> range_add([(0, 2), (8, 10)], 4, 6)
    [(0, 2), (4, 6), (8, 10)]
    >>> range_add([(0, 2), (4, 6), (8, 10)], 4, 6)
    [(0, 2), (4, 6), (8, 10)]
    >>> range_add([(0, 2), (4, 6), (8, 10)], 3, 7)
    [(0, 2), (3, 7), (8, 10)]
    >>> range_add([(0, 2), (4, 6), (8, 10)], 2, 8)
    [(0, 10)]
    >>> range_add([(0, 2), (4, 6), (8, 10)], 1, 9)
    [(0, 10)]
    """
    lo = bisect_left(ranges, start, key=operator.itemgetter(0))
    if lo > 0 and ranges[lo - 1][1] >= start:
        start = ranges[lo - 1][0]
        lo -= 1

    hi = lo
    while hi < len(ranges) and ranges[hi][0] <= end:
        if ranges[hi][1] > end:
            end = ranges[hi][1]
        hi += 1

    ranges[lo:hi] = [(start, end)]
    return ranges


def range_remove(ranges, start, end):
    """
    Remove [start, end) from a sorted list of non-overlapping ranges.
    >>> range_remove([(0, 2), (4, 6), (8, 10)], 4, 6)
    [(0, 2), (8, 10)]
    >>> range_remove([(0, 2), (4, 6), (8, 10)], 3, 7)
    [(0, 2), (8, 10)]
    >>> range_remove([(0, 2), (4, 6), (8, 10)], 2, 8)
    [(0, 2), (8, 10)]
    >>> range_remove([(0, 2), (4, 6), (8, 10)], 1, 9)
    [(0, 1), (9, 10)]
    """
    stubs = []

    lo = bisect_left(ranges, start, key=operator.itemgetter(0))
    if lo > 0 and ranges[lo - 1][1] > start:
        stubs.append((ranges[lo - 1][0], start))
        lo -= 1

    hi = lo
    while hi < len(ranges) and ranges[hi][0] < end:
        if ranges[hi][1] > end:
            stubs.append((end, ranges[hi][1]))
        hi += 1

    ranges[lo:hi] = stubs
    return ranges


@dataclass(order=True)
class FragmentationScore:
    score: float
    ratio: float = field(compare=False)
    size_bytes: int
    label: str

    def __str__(self):
        size_bytes = human_readable_bytes(self.size_bytes)
        return f"{self.score:.2f}\t{self.ratio:3.0%}\t{size_bytes}\t{self.label}"


# import doctest
# doctest.testmod()
# exit()


USAGE = """Analyze fragmentation of a single vdev RAIDZ pool.
USAGE: zf.py <(sudo zdb -ddddd $pool | tee zd) <(sudo zdb -mmm $pool | tee zm) >zf"""

REQUIRED_ENV = [
    "ZF_DISK_TRACK_BYTES",
    "ZF_DISK_BYTES",
    "ZF_DISK_RPM",
    "ZF_DISK_FULL_STROKE_MS",
]
missing_env = [e for e in REQUIRED_ENV if e not in os.environ]

if missing_env:
    print(
        f"{USAGE}\n\nMissing required environment variables:\n{'\n'.join(missing_env)}",
        file=sys.stderr,
    )
    exit(1)
elif len(sys.argv) < 2:
    print(USAGE)
    exit()


DISK_TRACK_BYTES = int(os.environ.get("ZF_DISK_TRACK_BYTES"))
DISK_BYTES = int(os.environ.get("ZF_DISK_BYTES"))
DISK_RPM = int(os.environ.get("ZF_DISK_RPM"))

DISK_READ_BYTES_S = int(
    os.environ.get("ZF_DISK_READ_BYTES_S", DISK_TRACK_BYTES * DISK_RPM / 60 * 0.9)
)
DISK_FULL_ROTATION_MS = 60 / DISK_RPM * 1000
DISK_FULL_STROKE_MS = float(os.environ.get("ZF_DISK_FULL_STROKE_MS"))


vdev_disks = 0
vdev_parity = None
vdev_bytes = None

total = FragmentationTracker()
files = {}

stage = 0
mountpoint = None
path = None
blocks = []

re_asize = re.compile(r"\s*asize: ([0-9]*)")
re_nparity = re.compile(r"\s*nparity: ([1-3])")

re_dataset = re.compile("Dataset ([^ ]*)")
re_path = re.compile(r"\s*path\t(.*)")
re_l0 = re.compile(r"\s*[0-9a-f]*\s*L0 [^:]*:([^:]*):([^ ]*)")

for line in open(sys.argv[1], errors="replace"):
    if "type: 'disk'" in line:
        vdev_disks += 1

    elif vdev_bytes is None and "asize" in line and (match := re_asize.match(line)):
        vdev_bytes = int(match.group(1))

    elif (
        vdev_parity is None and "nparity" in line and (match := re_nparity.match(line))
    ):
        vdev_parity = int(match.group(1))

    elif "Dataset" in line and (match := re_dataset.match(line)):
        dataset = match.group(1)
        if "/" in dataset:
            dataset = dataset.partition("/")[-1]
        mountpoint = f"/mnt/{dataset}"

    elif "Object" in line:
        if stage == 2 and len(blocks) > 0:
            layout_hash = hash(tuple(blocks))

            if layout_hash in files:
                prefix = mountpoint.partition("@")[0]
                assert files[layout_hash].label.startswith(prefix)

                new_is_snapshot = mountpoint.removeprefix(prefix).startswith("@")
                old_is_snapshot = (
                    files[layout_hash].label.removeprefix(prefix).startswith("@")
                )

                if new_is_snapshot == old_is_snapshot:
                    new_label_len = len(path)
                    old_label_len = len(files[layout_hash].label)
                    assert new_label_len != old_label_len

                    if new_label_len < old_label_len:
                        files[layout_hash].label = path
                elif not new_is_snapshot and old_is_snapshot:
                    files[layout_hash].label = path
            else:
                file = FragmentationTracker()
                for offset, length in blocks:
                    file.step(offset, length)

                files[layout_hash] = file.score(path)
                total += file

            blocks.clear()
        stage = 0

    elif stage == 0 and "ZFS plain file" in line:
        stage = 1

    elif stage == 1 and "path" in line and (match := re_path.match(line)):
        stage = 2
        path = f"{mountpoint}{match.group(1)}"

    elif stage == 2 and "L0" in line and (match := re_l0.match(line)):
        offset = int(match.group(1), 16)
        length = int(match.group(2), 16)
        if length > 0:
            blocks.append((offset, length))

for score in sorted(files.values()):
    print(score)
print()

print(total.score("files"))


if len(sys.argv) < 3:
    exit()

free_ranges = [(0, vdev_bytes)]
re_range = re.compile(r"\s*\[\s*[0-9]*\] ([AF]) range: ([^-]*)-([^ ]*)")
for line in open(sys.argv[2]):
    if match := re_range.match(line):
        operation = match.group(1)
        start = int(match.group(2), 16)
        end = int(match.group(3), 16) + 1

        match operation:
            case "A":
                range_remove(free_ranges, start, end)
            case "F":
                range_add(free_ranges, start, end)

alloc_ranges = [(0, vdev_bytes)]
for start, end in free_ranges:
    range_remove(alloc_ranges, start, end)

alloc = FragmentationTracker()
for start, end in alloc_ranges:
    length = end - start
    alloc.step(start, length)
print(alloc.score("alloc"))

free = FragmentationTracker()
for start, end in free_ranges:
    length = end - start
    free.step(start, length)
print(free.score("free"))
