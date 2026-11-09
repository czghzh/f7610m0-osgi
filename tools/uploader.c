/* uploader: 通过 TCP 把本地文件推送到远端（用于绕过极慢的 TFTP）
 * 编译: aarch64-linux-gnu-gcc -static -O2 -s -o uploader uploader.c
 * 用法: ./uploader <host> <port> <file>
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
        fprintf(stderr, "usage: %s <host> <port> <file>\n", argv[0]);
        return 1;
    }
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) { perror("socket"); return 1; }

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
    int f = open(argv[3], O_RDONLY);
    if (f < 0) { perror("open"); return 1; }

    static char buf[65536];
    ssize_t n;
    unsigned long long total = 0;
    while ((n = read(f, buf, sizeof(buf))) > 0) {
        char *p = buf;
        ssize_t left = n;
        while (left > 0) {
            ssize_t w = write(s, p, (size_t)left);
            if (w <= 0) { perror("write"); close(f); close(s); return 1; }
            p += w;
            left -= w;
        }
        total += (unsigned long long)n;
    }
    close(f);
    shutdown(s, SHUT_WR);
    close(s);
    fprintf(stderr, "sent %llu bytes\n", total);
    return 0;
}
