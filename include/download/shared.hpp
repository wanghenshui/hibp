#pragma once

#include <condition_variable>
#include <cstddef>
#include <curl/curl.h>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

// shared types

struct download {
  explicit download(std::string prefix_) : prefix(std::move(prefix_)) {
    buffer.reserve(1U << 16U); // 64kB should be enough for any file for a while
  }

  static constexpr int max_retries = 5;

  CURL*             easy = nullptr;
  std::string       prefix;
  std::vector<char> buffer;
  int               retries_left = max_retries;
  bool              complete     = false;
};

using enq_msg_t = std::vector<std::unique_ptr<download>>;
void enqueue_downloads_for_writing(enq_msg_t&& msg);

void finished_downloads();

struct cli_config_t {
  std::string output_db_filename;
  bool        debug        = false;
  bool        progress     = true;
  bool        resume       = false;
  bool        text_out     = false;
  bool        force        = false;
  std::size_t prefix_limit = 0x100000;
  std::size_t parallel_max = 300;
};

// vars shared across threads

extern struct event_base* base;              // NOLINT non-const-global
extern CURLM*             curl_multi_handle; // NOLINT non-const-global

extern std::mutex cerr_mutex; // NOLINT non-const-global

extern std::unordered_map<std::thread::id, std::string> thrnames; // NOLINT non-const-global

extern cli_config_t cli; // NOLINT non-const-global

// simple logging

struct thread_logger {
  void log(const std::string& msg) const {
    if (debug) {
      std::lock_guard lk(cerr_mutex);
      std::cerr << std::format("thread: {:>9}: {}\n", thrnames[std::this_thread::get_id()], msg);
    }
  }
  bool debug = false;
};

extern thread_logger logger; // NOLINT non-const-global
