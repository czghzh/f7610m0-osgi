/* downloader: 通过 TCP 从远端拉取文件（带大 SO_RCVBUF，绕过设备默认小缓冲导致的低速）
 * 编译: aarch64-linux-gnu-gcc -static -O2 -s -o downloader downloader.c
 * 用法: ./downloader <host> <port> <outfile>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "usage: %s <host> <port> <outfile>\n", argv[0]);
        return 1;
    }
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) { perror("socket"); return 1; }

    int bufsize = 4 * 1024 * 1024;
    setsockopt(s, SOL_SOCKET, SO_RCVBUF, &bufsize, sizeof(bufsize));

    struct sockaddr_in a;
    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_port = htons((unsigned short)atoi(argv[2]));
    if (inet_pton(AF_INET, argv[1], &a.sin_addr) != 1) {
        fprintf(stderr, "bad address: %s\n", argv[1]);
        return 1;
    }
    if (connect(s, (struct sockaddr *)&a, sizeof(a)) < 0) {
        perror("connect");
        return 1;
    }
    int f = open(argv[3], O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (f < 0) { perror("open"); return 1; }

    static char buf[262144];
    ssize_t n;
    unsigned long long total = 0;
    unsigned long long mark = 0;
    while ((n = read(s, buf, sizeof(buf))) > 0) {
        char *p = buf;
        ssize_t left = n;
        while (left > 0) {
            ssize_t w = write(f, p, (size_t)left);
            if (w <= 0) { perror("write"); close(f); close(s); return 1; }
            p += w;
            left -= w;
        }
        total += (unsigned long long)n;
        if (total - mark >= (8ULL << 20)) {
            mark = total;
            fprintf(stderr, "recv %llu bytes\n", total);
        }
    }
    close(f);
    close(s);
    fprintf(stderr, "done %llu bytes\n", total);
    return 0;
}
