import socket, time, sys, os, re, hashlib

HOST, PORT = "192.168.1.1", 23
USER, PWD = "root", "Zte521"
LHOST = "192.168.1.100"
LPORT = "6969"
OUT = "/home/wen/zte-backup/mtd"
CS = 0x1000000  # 16MB per chunk (device /tmp is 35MB tmpfs)

PARTS = {
    1: ("u-boot", 0x000e0000),
    2: ("others", 0x00080000),
    3: ("parameter_tags", 0x00100000),
    4: ("wlan", 0x00100000),
    5: ("usercfg", 0x00200000),
    6: ("middleware", 0x00100000),
    7: ("kernel1", 0x03000000),
    8: ("kernel2", 0x03000000),
    9: ("framework1", 0x01000000),
    10: ("framework2", 0x01000000),
    11: ("preplugin_data", 0x01800000),
    12: ("plugin_data", 0x06180000),
    13: ("bootrom", 0x00020000),
}


def recv_until(s, marker, hard=300):
    s.settimeout(1.0)
    buf = b""
    t0 = time.time()
    while time.time() - t0 < hard:
        try:
            d = s.recv(65536)
            if not d:
                break
            buf += d
            if marker.encode() in buf:
                # drain a bit
                time.sleep(0.3)
                s.settimeout(0.5)
                try:
                    while True:
                        d2 = s.recv(65536)
                        if not d2:
                            break
                        buf += d2
                except socket.timeout:
                    pass
                return buf, True
        except socket.timeout:
            if marker.encode() in buf:
                return buf, True
    return buf, False


def clean(b):
    out = bytearray()
    i = 0
    while i < len(b):
        c = b[i]
        if c == 255:
            if i + 1 < len(b) and b[i + 1] in (251, 252, 253, 254):
                i += 3
                continue
            if i + 1 < len(b) and b[i + 1] == 250:
                j = b.find(b"\xff\xf0", i)
                i = (j + 2) if j != -1 else len(b)
                continue
            i += 2
            continue
        out.append(c)
        i += 1
    return out.decode("utf-8", "replace")


s = socket.create_connection((HOST, PORT), timeout=5)
recv_until(s, "@@NOPE@@", 3)
s.sendall(USER.encode() + b"\r\n")
time.sleep(0.8)
recv_until(s, "@@NOPE@@", 2)
s.sendall(PWD.encode() + b"\r\n")
time.sleep(1.2)
recv_until(s, "@@NOPE@@", 3)

os.makedirs(OUT, exist_ok=True)
targets = [int(x) for x in sys.argv[1:]] if len(sys.argv) > 1 else sorted(PARTS)
summary = []

for idx in targets:
    name, size = PARTS[idx]
    base = "mtd%d_%s" % (idx, name)
    final = os.path.join(OUT, base + ".bin")
    dev = "/dev/mtd%d" % idx
    nchunks = (size + CS - 1) // CS
    t0 = time.time()
    pieces = []
    okall = True
    info = []
    for i in range(nchunks):
        off = i * CS
        n = min(CS, size - off)
        rem = "%s.b%03d" % (base, i)
        mk = "__END_%d_%d__" % (idx, i)
        mk_echo = '__END""_%d_%d__' % (idx, i)
        cmd = ("mtd_debug read %s 0x%x 0x%x /tmp/c.bin >/dev/null 2>&1; "
               "wc -c < /tmp/c.bin; md5sum /tmp/c.bin; "
               "tftp -p -l /tmp/c.bin -r %s %s %s; echo RET=$?; "
               "rm -f /tmp/c.bin; echo; echo %s; echo"
               % (dev, off, n, rem, LHOST, LPORT, mk_echo))
        s.sendall(cmd.encode() + b"\r\n")
        raw, got = recv_until(s, mk, 400)
        out = clean(raw)
        sm = re.search(r"(\d+)\s*\n", out)
        dm = re.findall(r"([0-9a-f]{32})", out)
        ret = re.search(r"RET=(\d+)", out)
        lpath = os.path.join(OUT, rem)
        lsz = os.path.getsize(lpath) if os.path.exists(lpath) else -1
        lmd5 = hashlib.md5(open(lpath, "rb").read()).hexdigest() if lsz > 0 else "?"
        dm5 = dm[0] if dm else "?"
        ok = got and lsz == n and lmd5 == dm5 and (ret and ret.group(1) == "0")
        info.append((i, n, lsz, dm5, lmd5, ok))
        if not ok:
            okall = False
            print("   chunk %d FAIL expect=%d got=%d dev=%s loc=%s ret=%s got_marker=%s"
                  % (i, n, lsz, dm5, lmd5, ret.group(1) if ret else "?", got), flush=True)
            print("   RAW: %r" % out[-400:], flush=True)
        pieces.append(lpath)
    if okall:
        with open(final, "wb") as f:
            for p in pieces:
                with open(p, "rb") as g:
                    while True:
                        b = g.read(1 << 20)
                        if not b:
                            break
                        f.write(b)
        fsz = os.path.getsize(final)
        fmd5 = hashlib.md5(open(final, "rb").read()).hexdigest()
        okall = (fsz == size)
        print("[%s] mtd%-2d %-16s %d chunks  %8d bytes  %5.1fs  md5=%s"
              % ("PASS" if okall else "FAIL", idx, name, nchunks, fsz, time.time() - t0, fmd5), flush=True)
        if okall:
            for p in pieces:
                os.remove(p)
    else:
        print("[FAIL] mtd%-2d %-16s incomplete, pieces kept" % (idx, name), flush=True)
    summary.append((idx, name, size, okall))

print("\n===== SUMMARY =====", flush=True)
for r in summary:
    print("mtd%-2d %-16s %10d  %s" % (r[0], r[1], r[2], "OK" if r[3] else "FAIL"), flush=True)
print("done %d/%d" % (sum(1 for r in summary if r[3]), len(summary)), flush=True)
s.close()
