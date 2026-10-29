/*
 * rootsh —— 最小 setuid-root 执行器（静态链接，aarch64）
 *
 * 背景：这台光猫的开机钩子 /usr/java/bin/java 由 osgid 以 osgi 用户(58327)执行，
 * 而改 /proc/sys 需要 root。系统里没有任何 setuid 程序、也没有 sudo。
 * 于是把本程序放在可写分区并置 4755，由钩子调用，获得一次 root 执行机会。
 *
 * 用法：
 *   rootsh                      -> 以 root 执行 /usr/plugin/boot.d/root.sh
 *   rootsh /bin/sh -c 'cmd'     -> 以 root 执行指定命令
 */
#include <stdio.h>
#include <unistd.h>
#include <grp.h>

int main(int argc, char **argv) {
    if (setgroups(0, NULL) != 0) { /* 忽略失败 */ }
    if (setgid(0) != 0 || setuid(0) != 0) {
        perror("rootsh: setuid");
        return 1;
    }
    if (argc > 1) {
        execv(argv[1], &argv[1]);
        perror("rootsh: execv");
        return 1;
    }
    execl("/bin/sh", "sh", "/usr/plugin/boot.d/root.sh", (char *)NULL);
    perror("rootsh: execl");
    return 1;
}
