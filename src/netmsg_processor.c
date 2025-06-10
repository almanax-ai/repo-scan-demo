
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#define PORT 9090
#define MAX_MSG_LEN 256

typedef struct {
    uint16_t msg_len; 
} msg_header_t;

void handle_client(int fd) {
    uint32_t cnt_net;
    if (read(fd, &cnt_net, sizeof(cnt_net)) != sizeof(cnt_net))
        return;
    uint32_t count = ntohl(cnt_net);

    uint32_t alloc_size = count * (sizeof(msg_header_t) + MAX_MSG_LEN);
    printf("Allocating %u bytes for %u messages\n", alloc_size, count);

    char *batch = malloc(alloc_size ? alloc_size : 1);
    if (!batch) return;

    if (read(fd, batch, alloc_size) != alloc_size) {
        free(batch);
        return;
    }

    char local[MAX_MSG_LEN];
    char *ptr = batch;

    for (uint32_t i = 0; i < count; i++) {
        msg_header_t hdr;
        memcpy(&hdr, ptr, sizeof(hdr));
        ptr += sizeof(hdr);
        uint16_t len = ntohs(hdr.msg_len);

        printf("Handling message %u: len=%u\n", i, len);

        memcpy(local, ptr, len);
        local[(len < MAX_MSG_LEN) ? len : (MAX_MSG_LEN - 1)] = '\0';

        printf(" -> %s\n", local);
        ptr += len;
    }

    free(batch);
}

int main() {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(PORT);
    addr.sin_addr.s_addr = INADDR_ANY;

    bind(sock, (struct sockaddr*)&addr, sizeof(addr));
    listen(sock, 1);
    printf("Server listening on port %d...\n", PORT);

    while (1) {
        int client = accept(sock, NULL, NULL);
        if (client < 0) continue;
        handle_client(client);
        close(client);
    }

    close(sock);
    return 0;
}
