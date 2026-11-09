import socket, time, sys

HOST, PORT = "192.168.1.1", 23
USER, PWD = "root", "Zte521"


def recv_all(s, quiet=0.7, hard=600):
    s.settimeout(1.0)
    buf = b""
    last = time.time()
    t0 = time.time()
    while True:
        try:
            d = s.recv(65536)
            if not d:
                break
            buf += d
            last = time.time()
        except socket.timeout:
            if time.time() - last > quiet:
                break
            if time.time() - t0 > hard:
                break
    return buf


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


def connect():
    s = socket.create_connection((HOST, PORT), timeout=5)
    recv_all(s, 1.0, 5)
    s.sendall(USER.encode() + b"\r\n")
    time.sleep(0.8)
    recv_all(s, 1.0, 3)
    s.sendall(PWD.encode() + b"\r\n")
    time.sleep(1.2)
    recv_all(s, 1.0, 4)
    return s


if __name__ == "__main__":
    s = connect()
    n = 0
    for line in sys.stdin.read().split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        n += 1
        mk = "__ZEND_%03d__" % n
        mke = '__ZEND""_%03d__' % n
        s.sendall((line + "; echo; echo " + mke + "; echo").encode() + b"\r\n")
        s.settimeout(1.0)
        buf = b""
        t0 = time.time()
        while time.time() - t0 < 900:
            try:
                d = s.recv(65536)
                if not d:
                    break
                buf += d
                if mk.encode() in buf:
                    break
            except socket.timeout:
                pass
        print("### %s\n%s" % (line, clean(buf)), flush=True)
    s.close()
