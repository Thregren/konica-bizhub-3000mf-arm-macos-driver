// Brother ML13 (Konica Minolta bizhub 2600P/3000MF/3080MF) network scan
// protocol, reverse-engineered from community documentation and from the
// vendor's ICA scanner module.
//
// Transport: TCP port 54921. Requests are ESC-prefixed ASCII fields
// terminated with 0x80. Image data arrives as length-prefixed chunks.
//
// References:
//   https://github.com/jmesmon/brother2/blob/master/PROTO
//   https://github.com/corsmith/mfc-7820n
//   https://github.com/thebino/brother-to-paperless

#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace brscan {

enum class ColorMode {
  Gray64,   // 8-bit grayscale (verified on MFC-L2700DW, same engine)
  CGray,    // 24-bit color
  Text      // 1-bit black and white (encoding not implemented yet)
};

struct Offer {
  int dpiX = 0;
  int dpiY = 0;
  int adfStatus = 0;
  int planeWidthMm = 0;    // scan bed width in millimetres
  int widthPx = 0;         // device-reported width (usually pixels)
  int planeHeightMm = 0;   // scan bed height in millimetres
  int heightPx = 0;        // device-reported height (usually pixels)
};

struct ScanOptions {
  int dpiX = 300;
  int dpiY = 300;
  ColorMode mode = ColorMode::Gray64;
  std::string compression = "NONE";  // NONE (raw gray) or JPEG (color)
  int x = 0;                          // left offset, pixels at scan dpi
  int y = 0;                          // top offset, pixels at scan dpi
  int width = 0;                      // scan width in pixels (0 = full bed)
  int height = 0;                     // scan height in pixels (0 = full bed)
  bool feeder = false;                // use the document feeder
  bool duplex = false;                // duplex feeder (device support varies)
};

struct ScanPage {
  std::vector<uint8_t> data;
};

class Session {
 public:
  Session() = default;
  Session(const Session&) = delete;
  Session& operator=(const Session&) = delete;
  ~Session();

  bool connect(const std::string& host, uint16_t port = 54921,
               int timeoutSec = 15);
  bool lease(int dpi, ColorMode mode, Offer* offer);
  bool startScan(const ScanOptions& options, std::vector<ScanPage>* pages,
                 int idleTimeoutSec = 90);
  bool cancel();
  void close();

  bool connected() const { return fd_ >= 0; }
  const std::string& lastError() const { return error_; }
  void setDebug(bool enabled) { debug_ = enabled; }

  static const char* modeString(ColorMode mode);

 private:
  bool sendPacket(const std::string& packet);
  bool readExact(void* buffer, size_t size);
  bool parseOffer(const std::vector<uint8_t>& raw, Offer* offer);
  bool readPages(std::vector<ScanPage>* pages, int idleTimeoutSec);

  int fd_ = -1;
  std::string error_;
  bool debug_ = false;
};

}  // namespace brscan
