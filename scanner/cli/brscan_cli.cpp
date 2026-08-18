// Command-line front end for the Brother ML13 network scan protocol.
//
// Useful for bringing up a device and capturing protocol behaviour before
// the ICA module is complete:
//
//   brscan_cli --ip 192.168.1.5 --dpi 300 --mode gray --out scan
//
// Grayscale output is written as PGM (P5); color mode saves the raw JPEG
// stream returned by the device.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "brscan.h"

namespace {

void usage(const char* argv0) {
  fprintf(stderr,
          "usage: %s --ip ADDR [options]\n"
          "  --ip ADDR       scanner IP address (required)\n"
          "  --port N        TCP port (default 54921)\n"
          "  --dpi N         scan resolution (default 300)\n"
          "  --mode M        gray | color | text (default gray)\n"
          "  --source S      flatbed | adf (default flatbed)\n"
          "  --duplex        duplex feeder scan\n"
          "  --x N --y N     selection offset in pixels at scan dpi\n"
          "  --width N       selection width (default: full bed)\n"
          "  --height N      selection height (default: full bed)\n"
          "  --out PREFIX    output file prefix (default: scan)\n"
          "  --timeout N     idle timeout in seconds (default 90)\n"
          "  --debug         print protocol trace to stderr\n",
          argv0);
}

bool hasNext(int argc, char** /*argv*/, int* i) {
  return *i + 1 < argc;
}

std::string next(int /*argc*/, char** argv, int* i) {
  ++(*i);
  return argv[*i];
}

void writePgm(const char* path, int width, int height,
              const std::vector<uint8_t>& data) {
  FILE* f = fopen(path, "wb");
  if (!f) {
    perror(path);
    exit(1);
  }
  fprintf(f, "P5\n%d %d\n255\n", width, height);
  fwrite(data.data(), 1, data.size(), f);
  fclose(f);
}

void padPageToSize(std::vector<uint8_t>* data, int width, int height) {
  size_t expected = (size_t)width * height;
  if (data->size() >= expected || width <= 0 || data->empty()) {
    return;
  }
  size_t rowBytes = (size_t)width;
  std::vector<uint8_t> lastRow(data->end() - rowBytes, data->end());
  while (data->size() < expected) {
    size_t remaining = expected - data->size();
    size_t count = remaining < rowBytes ? remaining : rowBytes;
    data->insert(data->end(), lastRow.begin(), lastRow.begin() + count);
  }
}

}  // namespace

int main(int argc, char** argv) {
  std::string ip;
  int port = 54921;
  int dpi = 300;
  brscan::ColorMode mode = brscan::ColorMode::Gray64;
  bool feeder = false;
  bool duplex = false;
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  std::string outPrefix = "scan";
  int idleTimeout = 90;
  bool debug = false;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];
    if (arg == "--ip" && hasNext(argc, argv, &i)) {
      ip = next(argc, argv, &i);
    } else if (arg == "--port" && hasNext(argc, argv, &i)) {
      port = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--dpi" && hasNext(argc, argv, &i)) {
      dpi = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--mode" && hasNext(argc, argv, &i)) {
      std::string m = next(argc, argv, &i);
      if (m == "gray") {
        mode = brscan::ColorMode::Gray64;
      } else if (m == "color") {
        mode = brscan::ColorMode::CGray;
      } else if (m == "text") {
        mode = brscan::ColorMode::Text;
      } else {
        usage(argv[0]);
        return 2;
      }
    } else if (arg == "--source" && hasNext(argc, argv, &i)) {
      std::string s = next(argc, argv, &i);
      if (s == "adf") {
        feeder = true;
      } else if (s == "flatbed") {
        feeder = false;
      } else {
        usage(argv[0]);
        return 2;
      }
    } else if (arg == "--duplex") {
      duplex = true;
    } else if (arg == "--x" && hasNext(argc, argv, &i)) {
      x = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--y" && hasNext(argc, argv, &i)) {
      y = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--width" && hasNext(argc, argv, &i)) {
      width = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--height" && hasNext(argc, argv, &i)) {
      height = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--out" && hasNext(argc, argv, &i)) {
      outPrefix = next(argc, argv, &i);
    } else if (arg == "--timeout" && hasNext(argc, argv, &i)) {
      idleTimeout = atoi(next(argc, argv, &i).c_str());
    } else if (arg == "--debug") {
      debug = true;
    } else if (arg == "-h" || arg == "--help") {
      usage(argv[0]);
      return 0;
    } else {
      usage(argv[0]);
      return 2;
    }
  }

  if (ip.empty()) {
    usage(argv[0]);
    return 2;
  }

  brscan::Session session;
  session.setDebug(debug);
  if (debug) {
    fprintf(stderr, "connecting to %s:%d\n", ip.c_str(), port);
  }
  if (!session.connect(ip, static_cast<uint16_t>(port), 10)) {
    fprintf(stderr, "error: %s\n", session.lastError().c_str());
    return 1;
  }

  brscan::Offer offer;
  if (debug) {
    fprintf(stderr, "lease: dpi=%d mode=%s\n", dpi,
            brscan::Session::modeString(mode));
  }
  if (!session.lease(dpi, mode, &offer)) {
    fprintf(stderr, "error: %s\n", session.lastError().c_str());
    return 1;
  }
  fprintf(stderr,
          "offer: dpi=%dx%d adf=%d plane=%dmm x %dmm pixels=%dx%d\n",
          offer.dpiX, offer.dpiY, offer.adfStatus, offer.planeWidthMm,
          offer.planeHeightMm, offer.widthPx, offer.heightPx);

  if (width <= 0) {
    width = static_cast<int>(offer.planeWidthMm * offer.dpiX / 25.4);
  }
  if (height <= 0) {
    height = static_cast<int>(offer.planeHeightMm * offer.dpiY / 25.4);
  }
  if (height <= 0) {
    height = static_cast<int>(offer.dpiY * 10.76);  // approximate A4 height
  }

  brscan::ScanOptions options;
  options.dpiX = offer.dpiX;
  options.dpiY = offer.dpiY;
  options.mode = mode;
  options.compression = mode == brscan::ColorMode::CGray ? "JPEG" : "NONE";
  options.x = x;
  options.y = y;
  options.width = width;
  options.height = height;
  options.feeder = feeder;
  options.duplex = duplex;

  std::vector<brscan::ScanPage> pages;
  if (debug) {
    fprintf(stderr, "start: %dx%d @ %dx%d (%s), area=%d,%d %dx%d\n",
            width, height, options.dpiX, options.dpiY,
            brscan::Session::modeString(mode), x, y, width, height);
  }
  if (!session.startScan(options, &pages, idleTimeout)) {
    fprintf(stderr, "error: %s\n", session.lastError().c_str());
    return 1;
  }
  fprintf(stderr, "received %zu page(s)\n", pages.size());

  for (size_t i = 0; i < pages.size(); ++i) {
    char path[1024];
    if (pages.size() == 1) {
      snprintf(path, sizeof(path), "%s.%s", outPrefix.c_str(),
               mode == brscan::ColorMode::CGray ? "jpg" : "pgm");
    } else {
      snprintf(path, sizeof(path), "%s_%zu.%s", outPrefix.c_str(), i + 1,
               mode == brscan::ColorMode::CGray ? "jpg" : "pgm");
    }

    if (mode == brscan::ColorMode::CGray) {
      FILE* f = fopen(path, "wb");
      if (!f) {
        perror(path);
        return 1;
      }
      fwrite(pages[i].data.data(), 1, pages[i].data.size(), f);
      fclose(f);
    } else if (mode == brscan::ColorMode::Gray64) {
      padPageToSize(&pages[i].data, width, height);
      writePgm(path, width, height, pages[i].data);
    } else {
      fprintf(stderr, "text mode decode is not implemented yet\n");
      return 1;
    }
    fprintf(stderr, "wrote %s (%zu bytes)\n", path, pages[i].data.size());
  }

  return 0;
}
