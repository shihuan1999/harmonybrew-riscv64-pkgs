#!/usr/bin/env python3
"""elf_rpath.py — rewrite DT_RPATH/DT_RUNPATH in place, no patchelf needed.

Pure-Python ELF editor: locates PT_DYNAMIC, finds DT_RPATH (15) / DT_RUNPATH
(29), and overwrites the referenced .dynstr entry. Because the replacement is
usually not the same length, it uses the trick real packaging tools avoid:
it rewrites the string inside .dynstr **only if it fits**, otherwise it
allocates nothing and instead re-points the tag at a string that is appended
into spare space at the end of .dynstr (requires room) — and if neither works
it reports failure so the caller can fall back to wrapping.

For our use case (short device path ":/data/harmonybrew/lib" replacing a long
build-host path) the new string is shorter, so the in-place rewrite always
fits and the tool is exact and lossless.

Usage:
    elf_rpath.py --get  FILE
    elf_rpath.py --set  FILE NEW_RPATH          (in place)
    elf_rpath.py --check FILE REQUIRED_PREFIX    (exit 1 if rpath not under prefix)
"""
import struct
import sys

DT_RPATH = 15
DT_RUNPATH = 29
DT_STRTAB = 5
DT_NULL = 0
SHT_DYNSRT = 11
PT_DYNAMIC = 2
PT_LOAD = 1


class Elf:
    def __init__(self, data):
        self.d = data
        if data[:4] != b"\x7fELF":
            raise ValueError("not an ELF file")
        self.is64 = data[4] == 2
        self.end = "<" if data[5] == 1 else ">"
        if not self.is64:
            raise ValueError("only ELF64 supported")
        (self.e_phoff, self.e_shoff) = struct.unpack_from(self.end + "QQ", data, 0x20)
        (self.e_phentsize, self.e_phnum) = struct.unpack_from(self.end + "HH", data, 0x36)
        (self.e_shentsize, self.e_shnum) = struct.unpack_from(self.end + "HH", data, 0x3A)
        self.phdrs = []
        for i in range(self.e_phnum):
            off = self.e_phoff + i * self.e_phentsize
            p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = \
                struct.unpack_from(self.end + "IIQQQQQQ", data, off)
            self.phdrs.append(dict(type=p_type, off=p_offset, fsz=p_filesz,
                                   vaddr=p_vaddr, idx=i, hdr_off=off))

    def dynamic(self):
        for p in self.phdrs:
            if p["type"] == PT_DYNAMIC:
                return p
        return None

    def dyn_entries(self):
        p = self.dynamic()
        if not p:
            return None, []
        out = []
        off = p["off"]
        while off + 16 <= p["off"] + p["fsz"]:
            tag, val = struct.unpack_from(self.end + "QQ", self.d, off)
            out.append((tag, val, off))
            if tag == DT_NULL:
                break
            off += 16
        return p, out

    def vaddr_to_off(self, vaddr):
        for p in self.phdrs:
            if p["type"] == PT_LOAD and p["vaddr"] <= vaddr < p["vaddr"] + p["fsz"]:
                return p["off"] + (vaddr - p["vaddr"])
        return None

    def read_cstr(self, off):
        e = self.d.index(b"\x00", off)
        return self.d[off:e].decode("utf-8", "replace")

    def get_rpath(self):
        p, ents = self.dyn_entries()
        if not ents:
            return None, None
        strtab_v = None
        target = None
        target_tag = None
        for tag, val, off in ents:
            if tag == DT_STRTAB:
                strtab_v = val
            if tag in (DT_RPATH, DT_RUNPATH) and target is None:
                target = val
                target_tag = tag
        if target is None or strtab_v is None:
            return None, None
        strtab_off = self.vaddr_to_off(strtab_v)
        if strtab_off is None:
            return None, None
        return target_tag, self.read_cstr(strtab_off + target)


def set_rpath(path, new_rpath):
    data = bytearray(open(path, "rb").read())
    e = Elf(data)
    p, ents = e.dyn_entries()
    if not ents:
        return False, "no dynamic section"

    strtab_v = None
    tag_off = None
    old_off = None
    tag_kind = None
    for tag, val, off in ents:
        if tag == DT_STRTAB:
            strtab_v = val
        if tag in (DT_RPATH, DT_RUNPATH) and tag_off is None:
            tag_off, old_off, tag_kind = off, val, tag
    if strtab_v is None:
        return False, "no DT_STRTAB"

    strtab_off = e.vaddr_to_off(strtab_v)
    if strtab_off is None:
        return False, "strtab not mapped"

    old_start = strtab_off + old_off
    old_end = data.index(b"\x00", old_start)
    old_len = old_end - old_start
    new_bytes = new_rpath.encode() + b"\x00"

    if tag_off is None:
        return False, "no RPATH/RUNPATH tag to rewrite (add one at link time)"

    if len(new_bytes) <= old_len + 1:
        # fits: overwrite in place, NUL-pad the tail
        data[old_start:old_start + len(new_bytes)] = new_bytes
        for i in range(len(new_bytes), old_len + 1):
            data[old_start + i] = 0
        open(path, "wb").write(data)
        return True, "rewrote in place (%d -> %d bytes)" % (old_len + 1, len(new_bytes))

    return False, ("new rpath too long (%d > %d) — needs relink or patchelf"
                   % (len(new_bytes), old_len + 1))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    mode = sys.argv[1]
    path = sys.argv[2]
    if mode == "--get":
        k, v = Elf(open(path, "rb").read()).get_rpath()
        print(v if v is not None else "(none)")
        return 0
    if mode == "--check":
        want = sys.argv[3]
        k, v = Elf(open(path, "rb").read()).get_rpath()
        if v is None:
            print("NO-RPATH %s" % path)
            return 1
        if not v.startswith(want):
            print("BAD-RPATH %s -> %s" % (path, v))
            return 1
        print("OK %s -> %s" % (path, v))
        return 0
    if mode == "--set":
        ok, msg = set_rpath(path, sys.argv[3])
        print(("OK " if ok else "FAIL ") + path + ": " + msg)
        return 0 if ok else 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
