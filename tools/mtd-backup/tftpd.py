import socket, struct, os, sys, threading, time

ROOT = "/home/wen/zte-backup/mtd"
PORT = 6969
os.makedirs(ROOT, exist_ok=True)

def parse_opts(payload):
    parts = payload.split(b"\x00")
    opts = {}
    i = 2
    while i + 1 < len(parts):
        k = parts[i].decode(errors="replace").lower()
        v = parts[i+1].decode(errors="replace")
        if k:
            opts[k] = v
        i += 2
    return parts[0].decode(errors="replace"), parts[1].decode(errors="replace"), opts

def handle(data, addr, sock):
    op = struct.unpack("!H", data[:2])[0]
    if op != 2:
        return
    fname, mode, opts = parse_opts(data[2:])
    fname = os.path.basename(fname)
    path = os.path.join(ROOT, fname)
    bs = 512
    if "blksize" in opts:
        try:
            bs = max(8, min(65464, int(opts["blksize"])))
        except Exception:
            bs = 512
    tsock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tsock.bind(("0.0.0.0", 0))
    tsock.settimeout(5)
    t0 = time.time()
    try:
        if "blksize" in opts:
            ack = struct.pack("!H", 6) + b"blksize\x00" + str(bs).encode() + b"\x00"
            tsock.sendto(ack, addr)
        else:
            tsock.sendto(struct.pack("!HH", 4, 0), addr)
        expect = 1
        total = 0
        with open(path, "wb") as f:
            while True:
                try:
                    pkt, raddr = tsock.recvfrom(70000)
                except socket.timeout:
                    # retransmit last ack
                    if expect > 1:
                        tsock.sendto(struct.pack("!HH", 4, expect - 1), addr)
                        continue
                    raise
                if len(pkt) < 4:
                    continue
                opc, blk = struct.unpack("!HH", pkt[:4])
                if opc != 3:
                    continue
                if blk == expect:
                    f.write(pkt[4:])
                    total += len(pkt) - 4
                    tsock.sendto(struct.pack("!HH", 4, blk), raddr)
                    expect = (expect + 1) & 0xFFFF
                    if len(pkt) - 4 < bs:
                        break
                elif blk == (expect - 1) & 0xFFFF:
                    tsock.sendto(struct.pack("!HH", 4, blk), raddr)
        dt = time.time() - t0
        print(f"[OK] {fname} {total} bytes in {dt:.1f}s ({total/dt/1024:.0f} KB/s) blksize={bs}", flush=True)
    except Exception as e:
        print(f"[FAIL] {fname}: {e}", flush=True)
    finally:
        tsock.close()

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", PORT))
    print(f"TFTP receiving on 0.0.0.0:{PORT} -> {ROOT}", flush=True)
    while True:
        data, addr = s.recvfrom(4096)
        threading.Thread(target=handle, args=(data, addr, s), daemon=True).start()

main()
