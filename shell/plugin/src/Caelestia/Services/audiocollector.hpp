#pragma once

#include "service.hpp"
#include "util/ringbuffer.hpp"
#include <atomic>
#include <pipewire/pipewire.h>
#include <qmutex.h>
#include <qqmlintegration.h>
#include <spa/param/audio/format-utils.h>
#include <stop_token>
#include <thread>
#include <vector>

namespace caelestia::services {

namespace ac {

constexpr quint32 SAMPLE_RATE = 44100;
constexpr quint32 CHUNK_SIZE = 512;

// Lockable which never makes the RT writer wait, as it only try_locks. Readers spin, they only wait on a short copy.
class SpinLock {
public:
    void lock() {
        while (m_flag.test_and_set(std::memory_order_acquire)) {
            while (m_flag.test(std::memory_order_relaxed))
                std::this_thread::yield();
        }
    }

    bool try_lock() { // NOLINT(readability-identifier-naming): Lockable requirement
        return !m_flag.test_and_set(std::memory_order_acquire);
    }

    void unlock() { m_flag.clear(std::memory_order_release); }

private:
    std::atomic_flag m_flag;
};

} // namespace ac

class AudioCollector;

class PipeWireWorker {
public:
    explicit PipeWireWorker(std::stop_token token, AudioCollector* collector, bool micEnabled);

    void run();

private:
    pw_main_loop* m_loop;
    pw_stream* m_stream;
    pw_stream* m_micStream;
    spa_source* m_timer;
    bool m_idle;

    std::stop_token m_token;
    AudioCollector* m_collector;
    bool m_micEnabled;

    // Stream setup state must outlive the async PipeWire connect negotiation
    // (which runs after createStream returns), so it lives here rather than
    // on a helper stack frame.
    pw_stream_events m_eventsMonitor = {};
    pw_stream_events m_eventsMic = {};
    spa_pod_builder m_paramBuilder;
    std::array<uint8_t, ac::CHUNK_SIZE> m_paramBuffer;
    const spa_pod* m_params[1] = { nullptr };

    static void handleTimeout(void* data, uint64_t expirations);
    void streamStateChanged(pw_stream_state state);
    void processStream(pw_stream* stream, bool mic);

    pw_stream* createStream(const char* name, bool captureSink, pw_stream_events& events);
};

class AudioCollector : public Service {
    Q_OBJECT

public:
    AudioCollector(const AudioCollector&) = delete;
    AudioCollector& operator=(const AudioCollector&) = delete;

    static AudioCollector& instance();

    void clearBuffer();
    void loadChunk(const qint16* samples, quint32 count);
    void loadMicChunk(const qint16* samples, quint32 count);
    quint32 readChunk(float* out, quint32 count = 0);
    quint32 readChunk(double* out, quint32 count = 0);
    quint32 readMicChunk(double* out, quint32 count = 0);

private:
    explicit AudioCollector(QObject* parent = nullptr);
    ~AudioCollector();

    std::jthread m_thread;
    util::RingBuffer<float> m_samples;
    ac::SpinLock m_samplesLock;
    util::RingBuffer<float> m_pending; // Writer thread only, holds chunks which arrived while a reader had the lock
    std::atomic<bool> m_discardPending;
    std::vector<float> m_micBuffer1;
    std::vector<float> m_micBuffer2;
    std::atomic<std::vector<float>*> m_micReadBuffer;
    std::atomic<std::vector<float>*> m_micWriteBuffer;
    quint32 m_sampleCount;
    bool m_connected = false;

    template <typename T> quint32 readLatest(T* out, quint32 count);

    void reload();
    void start() override;
    void stop() override;
};

} // namespace caelestia::services
