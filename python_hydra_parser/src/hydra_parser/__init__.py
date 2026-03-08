#!/usr/bin/env python3

from __future__ import annotations
from collections import defaultdict
from dataclasses import dataclass

import os
import sys

SUPPORTED_SYSTEMS = tuple(
    f"{arch}-{sys}"
    for sys in ("linux", "darwin")
    for arch in ("x86_64", "aarch64")
    if not (sys == "darwin" and arch == "x86_64")
)


@dataclass
class Job:
    id: str
    status: str
    name: str
    system: str

    @staticmethod
    def __remove_system_suffix(jobname: str) -> str:
        jobname = jobname.replace("&quot;", "")
        return min(
            (jobname.removesuffix(f".{sys}") for sys in SUPPORTED_SYSTEMS),
            key=len
        )

    @classmethod
    def from_line(cls, line: str) -> Job:
        status, id_, name, *_, system = line.rstrip("\n").split(',')

        return cls(
            id=id_,
            status=status[0],
            name=cls.__remove_system_suffix(name),
            system=system
        )



def write_csv(name: str, header: str, lines):
    with open(f"results/{name}.csv", "w+") as f:
        f.write(header + "\n")
        for line in lines:
            f.write(','.join(line) + '\n')


def main():
    next(sys.stdin) # discard first line
    raw_data = [line for line in sys.stdin]

    os.makedirs("results", exist_ok=True)

    all_jobs = [
        job for job in (Job.from_line(line) for line in raw_data)
        if job.system in SUPPORTED_SYSTEMS
    ]

    failures = [job for job in all_jobs if job.status == 'F']
    packed = defaultdict(lambda: { k: '' for k in SUPPORTED_SYSTEMS })

    for job in failures:
        packed[job.name][job.system] = job.id

    write_csv("4-failures-packed", "id,name," + ','.join(SUPPORTED_SYSTEMS),
        ((pkg, *failures.values()) for pkg, failures in packed.items()))


if __name__ == "__main__":
    main()
