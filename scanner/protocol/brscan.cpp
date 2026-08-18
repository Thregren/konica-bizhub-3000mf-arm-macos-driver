#include "brscan.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <cstdio>
#include <cstdlib>

namespace brscan {
namespace {

bool setInt32(const char* src, char delim, int* value) {
  if (src == nullptr || value == nullptr) {
    return false;
  }
  char* end = nullptr;
  errno = 0;
  long v = strtol(src, &end, 10);
  if (errno != 0 || end == src) {
    return false;
  }
  if (*end != '\0' && *end != delim && *end != ',') {
    return false;
  }
  *value = static_cast<int>(v);
  return true;
}

}  // namespace

Session::~Session() {
  close();
}

const char* Session::modeString(ColorMode mode) {
  switch (mode) {
    case ColorMode::Gray64:
      return "GRAY64";
    case ColorMode::CGray:
      return "CGRAY";
    case ColorMode::Text:
      return "TEXT";
  }
  return "GRAY64";
}

void Session::close() {
  if (fd_ >= 0) {
    ::close(fd_);
    fd_ = -1;
  }
}

bool Session::connect(const std::string& host, uint16_t port, int timeoutSec) {
  close();
  error_.clear();

  char portString[8];
  snprintf(portString, sizeof(portString), "%u", port);

  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;

  struct addrinfo* result = nullptr;
  int rc = getaddrinfo(host.c_str(), portString, &hints, &result);
  if (rc != 0) {
    error_ = "cannot resolve host: " + host;
    return false;
  }

  for (struct addrinfo* addr = result; addr != nullptr; addr = addr->ai_next) {
    fd_ = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
    if (fd_ < 0) {
      continue;
    }

    struct timeval tv;
    tv.tv_sec = timeoutSec < 1 ? 1 : timeoutSec;
    tv.tv_usec = 0;
    setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(fd_, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    if (::connect(fd_, addr->ai_addr, addr->ai_addrlen) == 0) {
      break;
    }
    close();
  }
  freeaddrinfo(result);

  if (fd_ < 0) {
    error_ = "cannot connect to " + host + ":" + portString;
    return false;
  }

  // The device greets us with "+OK 200" (or "-NG 401" when busy).
  char greeting[64];
  memset(greeting, 0, sizeof(greeting));
  ssize_t got = recv(fd_, greeting, sizeof(greeting) - 1, 0);
  if (got <= 0) {
    error_ = "no greeting from scanner";
    close();
    return false;
  }
  if (strstr(greeting, "+OK 200") == nullptr) {
    error_ = "scanner not ready: ";
    error_ += greeting;
    close();
    return false;
  }
  return true;
}

bool Session::sendPacket(const std::string& packet) {
  size_t sent = 0;
  while (sent < packet.size()) {
    ssize_t n = send(fd_, packet.data() + sent, packet.size() - sent, 0);
    if (n <= 0) {
      error_ = "send failed";
      return false;
    }
    sent += static_cast<size_t>(n);
  }
  return true;
}

bool Session::readExact(void* buffer, size_t size) {
  size_t got = 0;
  while (got < size) {
    ssize_t n = recv(fd_, static_cast<char*>(buffer) + got, size - got, 0);
    if (n <= 0) {
      error_ = "connection closed unexpectedly";
      return false;
    }
    got += static_cast<size_t>(n);
  }
  return true;
}

bool Session::parseOffer(const std::vector<uint8_t>& raw, Offer* offer) {
  if (offer == nullptr || raw.size() < 4) {
    error_ = "short capability offer";
    return false;
  }

  // ML13 devices prefix the CSV values with three bytes (00 1d 00).
  size_t start = 3;
  std::vector<char> text(raw.begin() + static_cast<long>(start), raw.end());
  text.push_back('\0');

  int values[7] = {0};
  const char* cursor = text.data();
  for (int i = 0; i < 7; ++i) {
    while (*cursor == ',' || *cursor == ' ') {
      ++cursor;
    }
    if (*cursor == '\0') {
      error_ = "capability offer has too few values";
      return false;
    }
    if (!setInt32(cursor, ',', &values[i])) {
      error_ = "capability offer contains garbage";
      return false;
    }
    while (*cursor != '\0' && *cursor != ',') {
      ++cursor;
    }
    if (*cursor == ',') {
      ++cursor;
    }
  }

  offer->dpiX = values[0];
  offer->dpiY = values[1];
  offer->adfStatus = values[2];
  offer->planeWidthMm = values[3];
  offer->widthPx = values[4];
  offer->planeHeightMm = values[5];
  offer->heightPx = values[6];
  return true;
}

bool Session::readPages(std::vector<ScanPage>* pages, int idleTimeoutSec) {
  constexpr uint8_t kEndScan = 0x80;
  constexpr uint8_t kEndPage = 0x82;
  constexpr size_t kHeaderLen = 12;  // type(1) + descriptor(9) + length(2)
  constexpr size_t kPageFooterLen = 9;

  if (idleTimeoutSec > 0) {
    struct timeval tv;
    tv.tv_sec = idleTimeoutSec;
    tv.tv_usec = 0;
    setsockopt(fd_, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  }

  std::vector<uint8_t> pending;
  ScanPage page;
  bool firstRead = true;
  FILE* debugDump = nullptr;
  if (debug_) {
    char dumpPath[128];
    snprintf(dumpPath, sizeof(dumpPath), "/tmp/brscan-raw-%d.bin", getpid());
    debugDump = fopen(dumpPath, "wb");
    if (debugDump) {
      fprintf(stderr, "DEBUG: dumping raw stream to %s\n", dumpPath);
    }
  }
  while (true) {
    // Consume complete frames from the pending buffer.
    bool progressed = true;
    while (progressed && !pending.empty()) {
      progressed = false;
      uint8_t b = pending[0];

      if (b == kEndScan) {
        if (!page.data.empty()) {
          pages->push_back(std::move(page));
        }
        return !pages->empty();
      }

      if (b == kEndPage) {
        constexpr size_t kPageMarkerTotal = 1 + kPageFooterLen;
        if (pending.size() < kPageMarkerTotal) {
          break;  // wait for the remaining footer bytes
        }
        if (!page.data.empty()) {
          pages->push_back(std::move(page));
          page = ScanPage();
        }
        pending.erase(pending.begin(),
                      pending.begin() + kPageMarkerTotal);
        progressed = true;
        continue;
      }

      if (pending.size() < kHeaderLen) {
        break;  // wait for a complete chunk header
      }
      size_t payloadLen =
          static_cast<size_t>(pending[kHeaderLen - 2]) |
          (static_cast<size_t>(pending[kHeaderLen - 1]) << 8);
      size_t frameTotal = kHeaderLen + payloadLen;
      if (pending.size() < frameTotal) {
        break;  // wait for the rest of the payload
      }
      page.data.insert(page.data.end(), pending.begin() + kHeaderLen,
                       pending.begin() + frameTotal);
      pending.erase(pending.begin(), pending.begin() + frameTotal);
      progressed = true;
    }

    if (pending.size() > 64u * 1024u * 1024u) {
      error_ = "scan stream exceeded the 64 MB buffer limit";
      return false;
    }

    uint8_t chunk[65536];
    ssize_t n = recv(fd_, chunk, sizeof(chunk), 0);
    if (n > 0) {
      if (debugDump) {
        fwrite(chunk, 1, (size_t)n, debugDump);
      }
      if (debug_ && firstRead) {
        firstRead = false;
        fprintf(stderr, "DEBUG: first %zu bytes from scanner:\n",
                n < 32 ? (size_t)n : (size_t)32);
        for (ssize_t i = 0; i < n && i < 32; ++i) {
          fprintf(stderr, "%02x ", chunk[i]);
          if ((i + 1) % 16 == 0) {
            fprintf(stderr, "\n");
          }
        }
        fprintf(stderr, "\n");
      }
      pending.insert(pending.end(), chunk, chunk + n);
      continue;
    }
    if (debugDump) {
      fclose(debugDump);
      debugDump = nullptr;
    }
    if (n == 0) {
      break;  // peer closed
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      if (!page.data.empty()) {
        pages->push_back(std::move(page));
        return true;
      }
      error_ = "timeout waiting for scanner data";
      return false;
    }
    error_ = "recv failed: " + std::string(strerror(errno));
    return false;
  }

  if (!page.data.empty()) {
    pages->push_back(std::move(page));
  }
  if (debugDump) {
    fclose(debugDump);
  }
  return !pages->empty();
}

bool Session::lease(int dpi, ColorMode mode, Offer* offer) {
  char packet[128];
  snprintf(packet, sizeof(packet), "\x1bI\nR=%d,%d\nM=%s\n\x80", dpi, dpi,
           modeString(mode));
  if (!sendPacket(packet)) {
    return false;
  }

  // The offer is small; read it in one go with the receive timeout.
  std::vector<uint8_t> raw(256);
  ssize_t n = recv(fd_, raw.data(), raw.size(), 0);
  if (n <= 0) {
    error_ = "no capability offer received";
    return false;
  }
  raw.resize(static_cast<size_t>(n));
  return parseOffer(raw, offer);
}

bool Session::startScan(const ScanOptions& options,
                        std::vector<ScanPage>* pages, int idleTimeoutSec) {
  if (pages == nullptr) {
    error_ = "null pages output";
    return false;
  }
  pages->clear();

  char packet[512];
  int width = options.width;
  int height = options.height;
  if (width <= 0 || height <= 0) {
    error_ = "scan width/height must be positive";
    return false;
  }

  int written = snprintf(packet, sizeof(packet),
                         "\x1bX\nR=%d,%d\nM=%s\nC=%s\nJ=MID\nB=50\nN=50\n"
                         "A=%d,%d,%d,%d\n",
                         options.dpiX, options.dpiY, modeString(options.mode),
                         options.compression.c_str(), options.x, options.y,
                         width, height);
  if (written <= 0 || written >= static_cast<int>(sizeof(packet))) {
    error_ = "scan request too long";
    return false;
  }
  std::string request(packet);
  if (options.feeder) {
    request += "U=ON\n";
  }
  if (options.duplex) {
    request += "D=ON\n";
  }
  request += "\x80";
  if (!sendPacket(request)) {
    return false;
  }

  if (!readPages(pages, idleTimeoutSec)) {
    if (error_.empty()) {
      error_ = "no image data received";
    }
    return false;
  }
  return true;
}

bool Session::cancel() {
  return sendPacket("\x1bR\n\x80");
}

}  // namespace brscan
